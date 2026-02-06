//
//  CrewluvApp.swift
//  CrewLuv
//
//  Main entry point for CrewLuv companion app
//

import SwiftUI
import CloudKit

// Notification names
extension Notification.Name {
    static let shareAccepted = Notification.Name("shareAccepted")
}

@main
struct CrewluvApp: App {
    init() {
        debugLog("[CrewLuv] 🚀 App launching...")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    debugLog("[CrewLuv] 📲 onContinueUserActivity triggered")
                    handleIncomingShare(userActivity)
                }
                .onOpenURL { url in
                    debugLog("[CrewLuv] 🔗 onOpenURL triggered with: \(url)")
                    handleIncomingShareURL(url)
                }
                .task {
                    // Check for recently accepted shares on launch
                    await checkForAcceptedShares()
                }
        }
    }

    private func checkForAcceptedShares() async {
        debugLog("[CrewLuv] Checking for accepted shares...")

        let container = CKContainer(identifier: "iCloud.com.toddanderson.duty")
        let sharedDatabase = container.sharedCloudDatabase

        // Try multiple times with delays to handle CloudKit sync timing
        for attempt in 1...3 {
            debugLog("[CrewLuv] Attempt \(attempt) to find shared zones...")

            do {
                // First, get all shared zones (zones that have been shared with us)
                let allZones = try await sharedDatabase.allRecordZones()
                debugLog("[CrewLuv] Found \(allZones.count) shared zones")

                // Look for PartnerBeaconZone
                for zone in allZones {
                    debugLog("[CrewLuv] Checking zone: \(zone.zoneID.zoneName) owned by \(zone.zoneID.ownerName)")

                    if zone.zoneID.zoneName == "PartnerBeaconZone" {
                        debugLog("[CrewLuv] Found PartnerBeaconZone!")

                        // Store the zone owner name
                        let ownerName = zone.zoneID.ownerName
                        UserDefaults.standard.set(ownerName, forKey: "SharedZoneOwner")
                        debugLog("[CrewLuv] Stored zone owner: \(ownerName)")

                        // Notify the app to refresh
                        await MainActor.run {
                            NotificationCenter.default.post(name: .shareAccepted, object: nil)
                        }
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

    private func handleIncomingShare(_ userActivity: NSUserActivity) {
        guard let url = userActivity.webpageURL else {
            debugLog("[CrewLuv] No URL in user activity")
            return
        }

        debugLog("[CrewLuv] Received share URL: \(url)")

        // Accept the CloudKit share
        let container = CKContainer(identifier: "iCloud.com.toddanderson.duty")

        Task {
            do {
                // Fetch share metadata using completion handler API
                let metadata = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKShare.Metadata, Error>) in
                    container.fetchShareMetadata(with: url) { metadata, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let metadata = metadata {
                            continuation.resume(returning: metadata)
                        } else {
                            continuation.resume(throwing: NSError(domain: "CrewLuv", code: -1, userInfo: [NSLocalizedDescriptionKey: "No metadata returned"]))
                        }
                    }
                }

                debugLog("[CrewLuv] Share metadata fetched: \(metadata.share.recordID)")

                // Accept the share using completion handler API
                let acceptedShare = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKShare, Error>) in
                    container.accept(metadata) { acceptedShare, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let acceptedShare = acceptedShare {
                            continuation.resume(returning: acceptedShare)
                        } else {
                            continuation.resume(throwing: NSError(domain: "CrewLuv", code: -1, userInfo: [NSLocalizedDescriptionKey: "No share returned"]))
                        }
                    }
                }

                debugLog("[CrewLuv] ✅ Share accepted: \(acceptedShare.recordID)")

                // Store the zone owner name for future access
                let ownerName = acceptedShare.recordID.zoneID.ownerName
                UserDefaults.standard.set(ownerName, forKey: "SharedZoneOwner")
                debugLog("[CrewLuv] Stored zone owner: \(ownerName)")

                // Notify the app to refresh the status
                await MainActor.run {
                    NotificationCenter.default.post(name: .shareAccepted, object: nil)
                }
                debugLog("[CrewLuv] Posted share acceptance notification")
            } catch {
                debugLog("[CrewLuv] ❌ Error accepting share: \(error)")
            }
        }
    }

    private func handleIncomingShareURL(_ url: URL) {
        debugLog("[CrewLuv] Received URL: \(url)")

        // Accept the CloudKit share
        let container = CKContainer(identifier: "iCloud.com.toddanderson.duty")

        Task {
            do {
                // Fetch share metadata using completion handler API
                let metadata = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKShare.Metadata, Error>) in
                    container.fetchShareMetadata(with: url) { metadata, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let metadata = metadata {
                            continuation.resume(returning: metadata)
                        } else {
                            continuation.resume(throwing: NSError(domain: "CrewLuv", code: -1, userInfo: [NSLocalizedDescriptionKey: "No metadata returned"]))
                        }
                    }
                }

                debugLog("[CrewLuv] Share metadata fetched: \(metadata.share.recordID)")

                // Accept the share using completion handler API
                let acceptedShare = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKShare, Error>) in
                    container.accept(metadata) { acceptedShare, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let acceptedShare = acceptedShare {
                            continuation.resume(returning: acceptedShare)
                        } else {
                            continuation.resume(throwing: NSError(domain: "CrewLuv", code: -1, userInfo: [NSLocalizedDescriptionKey: "No share returned"]))
                        }
                    }
                }

                debugLog("[CrewLuv] ✅ Share accepted: \(acceptedShare.recordID)")

                // Store the zone owner name for future access
                let ownerName = acceptedShare.recordID.zoneID.ownerName
                UserDefaults.standard.set(ownerName, forKey: "SharedZoneOwner")
                debugLog("[CrewLuv] Stored zone owner: \(ownerName)")

                // Notify the app to refresh the status
                await MainActor.run {
                    NotificationCenter.default.post(name: .shareAccepted, object: nil)
                }
                debugLog("[CrewLuv] Posted share acceptance notification")
            } catch {
                debugLog("[CrewLuv] ❌ Error accepting share: \(error)")
            }
        }
    }
}
