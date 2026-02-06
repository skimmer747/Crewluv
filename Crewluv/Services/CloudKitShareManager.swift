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
final class CloudKitShareManager {
    static let shared = CloudKitShareManager()

    private let container = CKContainer(identifier: "iCloud.com.toddanderson.duty")
    private let zoneOwnerKey = "SharedZoneOwner"

    private init() {}

    /// Accepts a CloudKit share from the given URL and stores the zone owner information
    /// - Parameter url: The CloudKit share URL
    /// - Throws: CloudKit errors or custom errors if metadata/share acceptance fails
    func acceptShare(from url: URL) async throws {
        debugLog("[CrewLuv] Accepting share from URL: \(url)")

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

        debugLog("[CrewLuv] Share metadata fetched: \(metadata.share.recordID)")

        // Accept the share
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

        debugLog("[CrewLuv] ✅ Share accepted: \(acceptedShare.recordID)")

        // Store the zone owner name for future access
        let ownerName = acceptedShare.recordID.zoneID.ownerName
        UserDefaults.standard.set(ownerName, forKey: zoneOwnerKey)
        debugLog("[CrewLuv] Stored zone owner: \(ownerName)")

        // Notify the app to refresh the status
        NotificationCenter.default.post(name: .shareAccepted, object: nil)
        debugLog("[CrewLuv] Posted share acceptance notification")
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
