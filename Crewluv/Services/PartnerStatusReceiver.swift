//
//  PartnerStatusReceiver.swift
//  CrewLuv
//
//  Receives shared pilot status from CloudKit
//

import Foundation
import CloudKit
import Observation

@MainActor
@Observable
class PartnerStatusReceiver {
    var pilotStatus: SharedPilotStatus? = nil
    var isLoading: Bool = true
    var errorMessage: String? = nil
    var hasAcceptedShare: Bool = false

    private let container = CKContainer(identifier: "iCloud.com.toddanderson.duty")
    private var sharedDatabase: CKDatabase { container.sharedCloudDatabase }
    private var subscriptionID: String? = nil
    private var refreshTask: Task<Void, Never>? = nil

    init() {
        // Listen for share acceptance notification FIRST, before initial check
        NotificationCenter.default.addObserver(
            forName: .shareAccepted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            debugLog("[CrewLuv] Received share acceptance notification, refreshing...")
            Task { @MainActor in
                await self?.refresh()
            }
        }

        // Then do initial check with a small delay to allow share acceptance to complete
        Task {
            // Give share acceptance a moment to complete if app just launched from link
            try? await Task.sleep(for: .seconds(1))
            await checkForSharedData()

            // Start automatic refresh every 2 minutes
            await startAutoRefresh()
        }
    }

    /// Start automatic refresh every 2 minutes
    private func startAutoRefresh() async {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(120)) // Refresh every 2 minutes
                if !Task.isCancelled {
                    debugLog("[CrewLuv] Auto-refreshing status...")
                    await refresh()
                }
            }
        }
    }

    /// Check if user has accepted a share and can access pilot status
    func checkForSharedData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Use the account status to check if we have iCloud access
            let accountStatus = try await container.accountStatus()
            guard accountStatus == .available else {
                debugLog("[CrewLuv] iCloud account not available: \(accountStatus.rawValue)")
                errorMessage = "Please sign in to iCloud to access shared pilot status."
                hasAcceptedShare = false
                return
            }

            // Get the stored zone owner name from when the share was accepted
            // This is set by CrewluvApp when the user taps the share link
            guard let ownerName = UserDefaults.standard.string(forKey: "SharedZoneOwner") else {
                debugLog("[CrewLuv] No stored zone owner - share not yet accepted")
                hasAcceptedShare = false
                errorMessage = "Please accept the share invitation from your pilot."
                return
            }

            debugLog("[CrewLuv] Using stored zone owner: \(ownerName)")

            // Construct the zone ID with the owner name
            let zoneID = CKRecordZone.ID(zoneName: "PartnerBeaconZone", ownerName: ownerName)

            // Fetch the SharedPilotStatus record by its well-known ID
            // We use a fixed record name "pilot-status" so we can fetch without querying
            let statusRecordID = CKRecord.ID(recordName: "pilot-status", zoneID: zoneID)

            debugLog("[CrewLuv] Fetching SharedPilotStatus record: \(statusRecordID.recordName)")

            let statusRecord = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
                sharedDatabase.fetch(withRecordID: statusRecordID) { record, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let record = record {
                        continuation.resume(returning: record)
                    } else {
                        continuation.resume(throwing: NSError(domain: "CrewLuv", code: -1, userInfo: [NSLocalizedDescriptionKey: "No status record found"]))
                    }
                }
            }

            debugLog("[CrewLuv] Found shared record: \(statusRecord.recordID.recordName)")

            pilotStatus = SharedPilotStatus.from(record: statusRecord)
            hasAcceptedShare = true
            debugLog("[CrewLuv] ✅ Successfully loaded pilot status")
        } catch {
            debugLog("[CrewLuv] ❌ Error fetching status: \(error)")
            errorMessage = "Unable to load pilot status. Make sure you've accepted the share invitation."
            hasAcceptedShare = false
        }
    }

    /// Refresh pilot status manually
    func refresh() async {
        await checkForSharedData()
    }
}
