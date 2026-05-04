//
//  CloudKitShareManager.swift
//  CrewLuve
//
//  Centralized CloudKit share acceptance service
//  Eliminates duplication and provides a single point of control for share operations
//

import CloudKit
import Foundation

/// Extracts a CKShare URL from either a `crewluv://accept-share?url=…` wrapper
/// or a direct `icloud.com/share` URL.
enum ShareURLResolver {
    /// Returns the inner CKShare URL if wrapped in `crewluv://accept-share`, otherwise returns the URL as-is.
    static func resolve(_ url: URL) -> URL {
        if url.scheme == "crewluv",
           url.host == "accept-share",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let encoded = components.queryItems?.first(where: { $0.name == "url" })?.value,
           let inner = URL(string: encoded) {
            debugLog("[ShareURLResolver] Unwrapped crewluv:// → \(inner)")
            return inner
        }
        return url
    }

    /// Returns true if the URL is a CKShare URL (either wrapped or direct).
    static func isShareURL(_ url: URL) -> Bool {
        if url.scheme == "crewluv" && url.host == "accept-share" { return true }
        return url.absoluteString.contains("icloud.com/share")
    }
}

/// Manages CloudKit share acceptance and zone owner persistence
@MainActor
@Observable
final class CloudKitShareManager {
    static let shared = CloudKitShareManager()

    // MARK: - Share State

    enum ShareState: Equatable {
        case idle
        case accepting
        case accepted
        case error(String)
    }

    var shareState: ShareState = .idle
    var isAcceptingShare: Bool { shareState == .accepting }

    private let container = CKContainer(identifier: "iCloud.com.toddanderson.duty")
    private let zoneOwnerKey = "SharedZoneOwner"

    private init() {}

    /// Accepts a CloudKit share from the given URL and stores the zone owner information
    /// - Parameter url: The CloudKit share URL
    /// - Throws: CloudKit errors or custom errors if metadata/share acceptance fails
    func acceptShare(from url: URL) async throws {
        let resolvedURL = ShareURLResolver.resolve(url)
        shareState = .accepting
        debugLog("[ShareManager] Starting share acceptance from URL: \(resolvedURL)")

        do {
            // Fetch share metadata
            let metadata = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKShare.Metadata, Error>) in
                container.fetchShareMetadata(with: resolvedURL) { metadata, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let metadata = metadata {
                        continuation.resume(returning: metadata)
                    } else {
                        continuation.resume(throwing: CloudKitShareError.noMetadata)
                    }
                }
            }

            debugLog("[ShareManager] Share metadata fetched: \(metadata.share.recordID)")

            try await acceptAndStore(metadata: metadata)
        } catch {
            // The share may already be accepted (e.g., .alreadyShared) — scan for the zone.
            // We rely on the Bool return rather than checking UserDefaults, because a stale
            // zoneOwnerKey from a previous session would incorrectly mask the real failure.
            debugLog("[ShareManager] Share acceptance failed, scanning for zone: \(error)")
            let zoneConfirmed = await checkForAcceptedShares()
            if zoneConfirmed {
                debugLog("[ShareManager] Fallback scan confirmed PartnerBeaconZone — treating as accepted")
                shareState = .accepted
                return
            }
            let message = userFriendlyError(error)
            shareState = .error(message)
            let nsError = error as NSError
            debugLog("[ShareManager] ❌ Share acceptance failed — code: \(nsError.code), domain: \(nsError.domain), userInfo: \(nsError.userInfo)")
            throw error
        }
    }

    /// Accepts a CloudKit share from system-provided metadata (called by AppDelegate)
    /// - Parameter metadata: The CKShare.Metadata delivered by iOS after the user accepted a share
    func acceptShare(with metadata: CKShare.Metadata) async {
        shareState = .accepting
        debugLog("[ShareManager] Starting share acceptance from metadata")

        do {
            try await acceptAndStore(metadata: metadata)
        } catch {
            debugLog("[ShareManager] accept(metadata) failed, scanning for zone: \(error)")
            let zoneConfirmed = await checkForAcceptedShares()
            if zoneConfirmed {
                debugLog("[ShareManager] Fallback scan confirmed PartnerBeaconZone — treating as accepted")
                shareState = .accepted
            } else {
                shareState = .error(userFriendlyError(error))
            }
        }
    }

    /// Accepts the share and stores zone owner info
    private func acceptAndStore(metadata: CKShare.Metadata) async throws {
        let acceptedShare = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKShare, Error>) in
            container.accept(metadata) { acceptedShare, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let acceptedShare = acceptedShare {
                    continuation.resume(returning: acceptedShare)
                } else {
                    continuation.resume(throwing: CloudKitShareError.noShare)
                }
            }
        }

        debugLog("[ShareManager] ✅ Share accepted: \(acceptedShare.recordID)")

        // Store the zone owner name for future access
        let ownerName = acceptedShare.recordID.zoneID.ownerName
        UserDefaults.standard.set(ownerName, forKey: zoneOwnerKey)
        // A real share is authoritative — break any prior .privateDB lock.
        UserDefaults.standard.set("shared", forKey: "PilotDataSource")
        debugLog("[ShareManager] Stored zone owner: \(ownerName)")

        // Update state to accepted
        shareState = .accepted

        // Notify the app to refresh the status
        NotificationCenter.default.post(name: .shareAccepted, object: nil)
        debugLog("[ShareManager] Posted share acceptance notification")
    }

    /// Checks for recently accepted shares in the shared CloudKit database.
    /// Useful for detecting shares accepted outside the app (e.g., from system share sheet).
    /// - Returns: `true` if PartnerBeaconZone was actively found and the owner stored,
    ///   `false` if no zone was confirmed (callers must not assume success based on stale UserDefaults).
    @discardableResult
    func checkForAcceptedShares() async -> Bool {
        debugLog("[ShareManager] Checking for accepted shares...")

        let sharedDatabase = container.sharedCloudDatabase

        // Try multiple times with delays to handle CloudKit sync timing
        for attempt in 1...3 {
            debugLog("[ShareManager] Attempt \(attempt) to find shared zones...")

            do {
                let allZones = try await sharedDatabase.allRecordZones()
                debugLog("[ShareManager] Found \(allZones.count) shared zones")

                // Look for PartnerBeaconZone
                for zone in allZones {
                    if zone.zoneID.zoneName == "PartnerBeaconZone" {
                        debugLog("[ShareManager] Found PartnerBeaconZone!")

                        // Store the zone owner name
                        let ownerName = zone.zoneID.ownerName
                        UserDefaults.standard.set(ownerName, forKey: zoneOwnerKey)
                        // A real share is authoritative — break any prior .privateDB lock.
                        UserDefaults.standard.set("shared", forKey: "PilotDataSource")
                        debugLog("[ShareManager] Stored zone owner: \(ownerName)")

                        // Notify the app to refresh
                        NotificationCenter.default.post(name: .shareAccepted, object: nil)
                        debugLog("[ShareManager] Posted share acceptance notification")
                        return true
                    }
                }

                debugLog("[ShareManager] No PartnerBeaconZone found in shared zones")
            } catch {
                debugLog("[ShareManager] Error checking for shares (attempt \(attempt)): \(error)")
            }

            // Wait before retrying (except on last attempt)
            if attempt < 3 {
                try? await Task.sleep(for: .seconds(2))
            }
        }

        debugLog("[ShareManager] No shared zones found after all attempts")
        return false
    }

    /// Clears stored zone owner information
    /// Useful for resetting the app to accept a new share
    func resetShareData() {
        UserDefaults.standard.removeObject(forKey: zoneOwnerKey)
        UserDefaults.standard.removeObject(forKey: "PilotDataSource")
        UserDefaults.standard.removeObject(forKey: "ResolvedPilotDisplayName")
        UserDefaults.standard.removeObject(forKey: "LastSeenPilotSnapshot")
        shareState = .idle
        debugLog("[ShareManager] Cleared stored zone owner, data source, display name, and pilot snapshot")

        NotificationCenter.default.post(name: .shareDataReset, object: nil)

        Task.detached {
            await CloudKitSubscriptionManager.shared.removeAllSubscriptions()
        }
    }

    /// Resets the share state to idle
    func resetShareState() {
        shareState = .idle
    }

    /// Converts CloudKit errors to user-friendly messages
    private func userFriendlyError(_ error: Error) -> String {
        let nsError = error as NSError

        if nsError.domain == CKErrorDomain {
            switch CKError.Code(rawValue: nsError.code) {
            case .networkUnavailable, .networkFailure:
                return "No internet connection. Please check your network and try again."
            case .notAuthenticated:
                return "Please sign in to iCloud in Settings."
            case .permissionFailure:
                return "You don't have permission to access this share."
            case .serverRejectedRequest:
                return "The share invitation is invalid or has expired."
            case .quotaExceeded:
                return "iCloud storage is full. Please free up space."
            case .participantMayNeedVerification:
                return "Please verify your iCloud account in Settings."
            case .unknownItem:
                return "Share not found. It may have been deleted, or the pilot may be using a different app version (e.g. TestFlight vs. development build)."
            case .alreadyShared:
                return "This share has already been accepted."
            case .zoneBusy:
                return "iCloud is busy. Please try again in a moment."
            case .requestRateLimited:
                return "Too many requests. Please wait a moment and try again."
            case .serviceUnavailable:
                return "iCloud is temporarily unavailable. Please try again later."
            case .operationCancelled:
                return "The operation was cancelled."
            case .invalidArguments:
                // Detect "owner participant" via structured CKError data
                // instead of fragile localizedDescription string matching.
                if let ckError = error as? CKError,
                   let partialErrors = ckError.partialErrorsByItemID {
                    // When the share owner accepts their own share, CloudKit
                    // nests per-item .invalidArguments inside partialErrorsByItemID.
                    let isOwnerParticipant = partialErrors.values.contains { itemError in
                        (itemError as? CKError)?.code == .invalidArguments
                    }
                    if isOwnerParticipant {
                        return "You're already connected as the pilot on this account."
                    }
                }
                return "The share link appears to be invalid. Please ask your pilot to share a new link."
            default:
                return "iCloud error (code \(nsError.code)). Please try again later."
            }
        }

        return "Unable to accept share. Please try again."
    }
}

// MARK: - Error Types

enum CloudKitShareError: LocalizedError {
    case noMetadata
    case noShare

    var errorDescription: String? {
        switch self {
        case .noMetadata:
            return "No share metadata returned from CloudKit"
        case .noShare:
            return "No accepted share returned from CloudKit"
        }
    }
}
