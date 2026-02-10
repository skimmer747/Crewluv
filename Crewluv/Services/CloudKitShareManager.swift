//
//  CloudKitShareManager.swift
//  CrewLuv
//
//  Centralized CloudKit share acceptance service
//  Eliminates duplication and provides a single point of control for share operations
//

import CloudKit
import Foundation

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
        shareState = .accepting
        debugLog("[ShareManager] Starting share acceptance from URL: \(url)")

        do {
            // Fetch share metadata
            let metadata = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKShare.Metadata, Error>) in
                container.fetchShareMetadata(with: url) { metadata, error in
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
            let message = userFriendlyError(error)
            shareState = .error(message)
            debugLog("[ShareManager] ❌ Share acceptance failed: \(error.localizedDescription)")
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
            let message = userFriendlyError(error)
            shareState = .error(message)
            debugLog("[ShareManager] ❌ Share acceptance failed: \(error.localizedDescription)")
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
        debugLog("[ShareManager] Stored zone owner: \(ownerName)")

        // Update state to accepted
        shareState = .accepted

        // Notify the app to refresh the status
        NotificationCenter.default.post(name: .shareAccepted, object: nil)
        debugLog("[ShareManager] Posted share acceptance notification")
    }

    /// Checks for recently accepted shares in the shared CloudKit database
    /// Useful for detecting shares accepted outside the app (e.g., from system share sheet)
    func checkForAcceptedShares() async {
        debugLog("[CrewLuv] Checking for accepted shares...")

        let sharedDatabase = container.sharedCloudDatabase

        // Try multiple times with delays to handle CloudKit sync timing
        for attempt in 1...3 {
            debugLog("[CrewLuv] Attempt \(attempt) to find shared zones...")

            do {
                let allZones = try await sharedDatabase.allRecordZones()
                debugLog("[CrewLuv] Found \(allZones.count) shared zones")

                // Look for PartnerBeaconZone
                for zone in allZones {
                    debugLog("[CrewLuv] Checking zone: \(zone.zoneID.zoneName) owned by \(zone.zoneID.ownerName)")

                    if zone.zoneID.zoneName == "PartnerBeaconZone" {
                        debugLog("[CrewLuv] Found PartnerBeaconZone!")

                        // Store the zone owner name
                        let ownerName = zone.zoneID.ownerName
                        UserDefaults.standard.set(ownerName, forKey: zoneOwnerKey)
                        debugLog("[CrewLuv] Stored zone owner: \(ownerName)")

                        // Notify the app to refresh
                        NotificationCenter.default.post(name: .shareAccepted, object: nil)
                        debugLog("[CrewLuv] Posted share acceptance notification")
                        return
                    }
                }

                debugLog("[CrewLuv] No PartnerBeaconZone found in shared zones")
            } catch {
                debugLog("[CrewLuv] Error checking for shares (attempt \(attempt)): \(error)")
            }

            // Wait before retrying (except on last attempt)
            if attempt < 3 {
                try? await Task.sleep(for: .seconds(2))
            }
        }

        debugLog("[CrewLuv] No shared zones found after all attempts")
    }

    /// Clears stored zone owner information
    /// Useful for resetting the app to accept a new share
    func resetShareData() {
        UserDefaults.standard.removeObject(forKey: zoneOwnerKey)
        debugLog("[CrewLuv] Cleared stored zone owner")
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
            default:
                return "Unable to connect to iCloud. Please try again later."
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
