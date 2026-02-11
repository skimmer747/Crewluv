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
    var isSyncing: Bool = false
    var errorMessage: String? = nil
    var hasAcceptedShare: Bool = false
    var lastSyncTime: Date? = nil
    var lastSyncError: String? = nil

    private let container = CKContainer(identifier: "iCloud.com.toddanderson.duty")
    private var sharedDatabase: CKDatabase { container.sharedCloudDatabase }
    private var subscriptionID: String? = nil
    private var rawPilotStatus: SharedPilotStatus?
    private var transitionTask: Task<Void, Never>?

    init(shareManager: CloudKitShareManager) {
        // Listen for share acceptance notification FIRST, before initial check
        NotificationCenter.default.addObserver(
            forName: .shareAccepted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            debugLog("[StatusReceiver] Received share acceptance notification, refreshing...")
            Task { @MainActor in
                await self?.refresh()
            }
        }

        // Wait for any in-progress share acceptance to complete before checking
        Task {
            // Wait for share acceptance if currently in progress
            while shareManager.shareState == .accepting {
                debugLog("[StatusReceiver] Waiting for share acceptance...")
                try? await Task.sleep(for: .milliseconds(100))
            }

            debugLog("[StatusReceiver] Share state is \(shareManager.shareState), proceeding to check for data")
            await checkForSharedData()

            // If no data found, scan shared database for accepted shares
            // Handles: cold launch from share link, shares accepted outside the app
            if !hasAcceptedShare {
                await shareManager.checkForAcceptedShares()
            }
        }
    }

    /// Check if user has accepted a share and can access pilot status
    func checkForSharedData() async {
        if pilotStatus == nil {
            isLoading = true
        }
        isSyncing = true
        defer {
            isLoading = false
            isSyncing = false
        }

        let syncStartTime = Date()
        debugLog("[CrewLuv] 🔄 Starting sync at \(syncStartTime.formatted(date: .omitted, time: .standard))")

        do {
            // Use the account status to check if we have iCloud access
            let accountStatus = try await container.accountStatus()
            guard accountStatus == .available else {
                debugLog("[CrewLuv] iCloud account not available: \(accountStatus.rawValue)")
                errorMessage = "Please sign in to iCloud to access shared pilot status."
                lastSyncError = "iCloud unavailable"
                hasAcceptedShare = false
                return
            }

            // Get the stored zone owner name from when the share was accepted
            // This is set by CrewluvApp when the user taps the share link
            guard let ownerName = UserDefaults.standard.string(forKey: "SharedZoneOwner") else {
                debugLog("[CrewLuv] No stored zone owner - share not yet accepted")
                hasAcceptedShare = false
                lastSyncError = "No share accepted"
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
            debugLog("[CrewLuv] Record modification date: \(statusRecord.modificationDate?.formatted(date: .abbreviated, time: .standard) ?? "unknown")")

            guard let newStatus = SharedPilotStatus.from(record: statusRecord) else {
                throw NSError(domain: "CrewLuv", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse status record"])
            }
            
            // Check if data actually changed
            if let oldStatus = pilotStatus {
                let changed = oldStatus.lastUpdated != newStatus.lastUpdated
                debugLog("[CrewLuv] Data changed: \(changed ? "YES" : "NO")")
                debugLog("[CrewLuv] Old lastUpdated: \(oldStatus.lastUpdated.formatted(date: .abbreviated, time: .standard))")
                debugLog("[CrewLuv] New lastUpdated: \(newStatus.lastUpdated.formatted(date: .abbreviated, time: .standard))")
                
                // Log key time fields
                debugLog("[CrewLuv] Old nextDepartureTime: \(oldStatus.nextDepartureTime?.formatted(date: .abbreviated, time: .standard) ?? "nil")")
                debugLog("[CrewLuv] New nextDepartureTime: \(newStatus.nextDepartureTime?.formatted(date: .abbreviated, time: .standard) ?? "nil")")
                debugLog("[CrewLuv] Old homeArrivalTime: \(oldStatus.homeArrivalTime?.formatted(date: .abbreviated, time: .standard) ?? "nil")")
                debugLog("[CrewLuv] New homeArrivalTime: \(newStatus.homeArrivalTime?.formatted(date: .abbreviated, time: .standard) ?? "nil")")
            } else {
                debugLog("[CrewLuv] First time loading status")
                debugLog("[CrewLuv] nextDepartureTime: \(newStatus.nextDepartureTime?.formatted(date: .abbreviated, time: .standard) ?? "nil")")
                debugLog("[CrewLuv] homeArrivalTime: \(newStatus.homeArrivalTime?.formatted(date: .abbreviated, time: .standard) ?? "nil")")
            }
            
            rawPilotStatus = newStatus
            resolveAndSchedule()
            hasAcceptedShare = true
            lastSyncTime = syncStartTime
            lastSyncError = nil
            
            let syncDuration = Date().timeIntervalSince(syncStartTime)
            debugLog("[CrewLuv] ✅ Successfully loaded pilot status (took \(String(format: "%.2f", syncDuration))s)")
        } catch {
            debugLog("[CrewLuv] ❌ Error fetching status: \(error)")
            lastSyncError = error.localizedDescription
            // Only mark as no-share if there's no stored zone owner
            // A stored owner means share was accepted; we just can't fetch right now
            if UserDefaults.standard.string(forKey: "SharedZoneOwner") != nil {
                hasAcceptedShare = true
                errorMessage = "Unable to load pilot status. Please try again."
            } else {
                hasAcceptedShare = false
                errorMessage = "Please accept the share invitation from your pilot."
            }
        }
    }

    /// Refresh pilot status manually
    func refresh() async {
        await checkForSharedData()
    }

    /// Instant local re-resolve from cached trip legs (no network)
    func reResolve() {
        resolveAndSchedule()
    }

    // MARK: - Trip State Resolution

    /// Resolve current state from trip legs and schedule next transition
    private func resolveAndSchedule() {
        guard let raw = rawPilotStatus else {
            pilotStatus = nil
            return
        }

        guard raw.hasTripLegs else {
            // No trip legs — use the status as-is (backward compat)
            pilotStatus = raw
            return
        }

        let resolved = TripStateResolver.resolve(legs: raw.tripLegs, at: Date())

        // Rebuild SharedPilotStatus with resolved fields, keeping identity/metadata from raw
        pilotStatus = SharedPilotStatus(
            pilotId: raw.pilotId,
            pilotFirstName: raw.pilotFirstName,
            displayStatus: resolved.displayStatus,
            isHome: resolved.isHome,
            isInFlight: resolved.isInFlight,
            isOnDuty: resolved.isOnDuty,
            currentAirport: resolved.currentAirport,
            currentCity: resolved.currentCity,
            currentTimezone: resolved.currentTimezone,
            localTimeAtPilot: nil,
            currentLatitude: nil,
            currentLongitude: nil,
            currentFlightNumber: resolved.currentFlightNumber,
            currentFlightDeparture: resolved.currentFlightDeparture,
            currentFlightArrival: resolved.currentFlightArrival,
            currentFlightDepartureTime: resolved.currentFlightDepartureTime,
            currentFlightArrivalTime: resolved.currentFlightArrivalTime,
            homeArrivalTime: resolved.homeArrivalTime,
            nextDepartureTime: resolved.nextDepartureTime,
            nextFlightNumber: resolved.nextFlightNumber,
            nextFlightDestination: resolved.nextFlightDestination,
            currentTripId: raw.currentTripId,
            tripDayNumber: resolved.tripDayNumber,
            tripTotalDays: resolved.tripTotalDays,
            upcomingCities: resolved.upcomingCities,
            tripLegsJSON: raw.tripLegsJSON,
            lastUpdated: raw.lastUpdated,
            appVersion: raw.appVersion
        )

        debugLog("[CrewLuv] Resolved status: \(resolved.displayStatus), next transition in \(resolved.timeUntilNextTransition.map { String(format: "%.0f", $0) } ?? "nil")s")

        // Schedule re-resolve at next leg boundary
        transitionTask?.cancel()
        if let delay = resolved.timeUntilNextTransition, delay > 0 {
            transitionTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay + 0.5))
                guard !Task.isCancelled else { return }
                guard let self else { return }
                self.resolveAndSchedule()
            }
        }
    }
}
