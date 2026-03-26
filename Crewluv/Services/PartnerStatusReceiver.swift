//
//  PartnerStatusReceiver.swift
//  CrewLuve
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

    // MARK: - Data Source

    enum DataSource: String {
        case shared
        case privateDB
    }

    var dataSource: DataSource? = nil

    private let container = CKContainer(identifier: "iCloud.com.toddanderson.duty")
    private var sharedDatabase: CKDatabase { container.sharedCloudDatabase }
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }
    private let dataSourceKey = "PilotDataSource"
    private var subscriptionID: String? = nil
    private var rawPilotStatus: SharedPilotStatus?
    private var transitionTask: Task<Void, Never>?
    private var cachedUserRecordName: String?
    private var resolvedDisplayName: String?

    init(shareManager: CloudKitShareManager) {
        // Restore persisted data source
        if let raw = UserDefaults.standard.string(forKey: dataSourceKey),
           let source = DataSource(rawValue: raw) {
            dataSource = source
            debugLog("[StatusReceiver] Restored data source: \(raw)")
        }

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

            // If still no data found, check private database (same-account scenario)
            if !hasAcceptedShare {
                await checkPrivateDatabase()
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
        debugLog("[CrewLuve] 🔄 Starting sync at \(syncStartTime.formatted(date: .omitted, time: .standard))")

        do {
            // Use the account status to check if we have iCloud access
            let accountStatus = try await container.accountStatus()
            guard accountStatus == .available else {
                debugLog("[CrewLuve] iCloud account not available: \(accountStatus.rawValue)")
                errorMessage = "Please sign in to iCloud to access shared pilot status."
                lastSyncError = "iCloud unavailable"
                hasAcceptedShare = false
                return
            }

            // Determine which database and owner to use
            let database: CKDatabase
            let ownerName: String

            if dataSource == .privateDB {
                database = privateDatabase
                ownerName = CKCurrentUserDefaultName
                debugLog("[CrewLuve] Using private database (same-account mode)")
            } else {
                // Get the stored zone owner name from when the share was accepted
                guard let storedOwner = UserDefaults.standard.string(forKey: "SharedZoneOwner") else {
                    debugLog("[CrewLuve] No stored zone owner - share not yet accepted")
                    hasAcceptedShare = false
                    lastSyncError = "No share accepted"
                    errorMessage = "Please accept the share invitation from your pilot."
                    return
                }
                database = sharedDatabase
                ownerName = storedOwner
                debugLog("[CrewLuve] Using shared database with zone owner: \(ownerName)")
            }

            // Construct the zone ID with the owner name
            let zoneID = CKRecordZone.ID(zoneName: "PartnerBeaconZone", ownerName: ownerName)

            // Fetch the SharedPilotStatus record by its well-known ID
            // We use a fixed record name "pilot-status" so we can fetch without querying
            let statusRecordID = CKRecord.ID(recordName: "pilot-status", zoneID: zoneID)

            debugLog("[CrewLuve] Fetching SharedPilotStatus record: \(statusRecordID.recordName)")

            let statusRecord = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
                database.fetch(withRecordID: statusRecordID) { record, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let record = record {
                        continuation.resume(returning: record)
                    } else {
                        continuation.resume(throwing: NSError(domain: "CrewLuve", code: -1, userInfo: [NSLocalizedDescriptionKey: "No status record found"]))
                    }
                }
            }

            debugLog("[CrewLuve] Found shared record: \(statusRecord.recordID.recordName)")
            debugLog("[CrewLuve] Record modification date: \(statusRecord.modificationDate?.formatted(date: .abbreviated, time: .standard) ?? "unknown")")

            guard let newStatus = SharedPilotStatus.from(record: statusRecord) else {
                throw NSError(domain: "CrewLuve", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse status record"])
            }

            // Resolve per-partner display name (stored separately — model stays immutable).
            // Reset so removals are reflected.
            resolvedDisplayName = nil
            let nameMap = newStatus.displayNameByPartner
            if !nameMap.isEmpty {
                if cachedUserRecordName == nil {
                    cachedUserRecordName = try? await container.userRecordID().recordName
                }
                // Look up by this user's record ID (works for shared-database partners)
                let matched: String? = cachedUserRecordName.flatMap { nameMap[$0] }
                // Same-account mode: user is the owner, not a participant — pick deterministically
                let name = matched ?? (dataSource == .privateDB ? nameMap.min(by: { $0.key < $1.key })?.value : nil)
                if let name, !name.isEmpty {
                    resolvedDisplayName = name
                    debugLog("[CrewLuve] Resolved display name: \(name)")
                }
            }

            // Check if data actually changed
            if let oldStatus = pilotStatus {
                let changed = oldStatus.lastUpdated != newStatus.lastUpdated
                debugLog("[CrewLuve] Data changed: \(changed ? "YES" : "NO")")
                debugLog("[CrewLuve] Old lastUpdated: \(oldStatus.lastUpdated.formatted(date: .abbreviated, time: .standard))")
                debugLog("[CrewLuve] New lastUpdated: \(newStatus.lastUpdated.formatted(date: .abbreviated, time: .standard))")
                
                // Log key time fields
                debugLog("[CrewLuve] Old nextDepartureTime: \(oldStatus.nextDepartureTime?.formatted(date: .abbreviated, time: .standard) ?? "nil")")
                debugLog("[CrewLuve] New nextDepartureTime: \(newStatus.nextDepartureTime?.formatted(date: .abbreviated, time: .standard) ?? "nil")")
                debugLog("[CrewLuve] Old homeArrivalTime: \(oldStatus.homeArrivalTime?.formatted(date: .abbreviated, time: .standard) ?? "nil")")
                debugLog("[CrewLuve] New homeArrivalTime: \(newStatus.homeArrivalTime?.formatted(date: .abbreviated, time: .standard) ?? "nil")")
            } else {
                debugLog("[CrewLuve] First time loading status")
                debugLog("[CrewLuve] nextDepartureTime: \(newStatus.nextDepartureTime?.formatted(date: .abbreviated, time: .standard) ?? "nil")")
                debugLog("[CrewLuve] homeArrivalTime: \(newStatus.homeArrivalTime?.formatted(date: .abbreviated, time: .standard) ?? "nil")")
            }
            
            logTripLegDiff(old: rawPilotStatus, new: newStatus, recordModDate: statusRecord.modificationDate)
            rawPilotStatus = newStatus
            resolveAndSchedule()
            hasAcceptedShare = true
            lastSyncTime = syncStartTime
            lastSyncError = nil
            
            let syncDuration = Date().timeIntervalSince(syncStartTime)
            debugLog("[CrewLuve] ✅ Successfully loaded pilot status (took \(String(format: "%.2f", syncDuration))s)")
        } catch {
            debugLog("[CrewLuve] ❌ Error fetching status: \(error)")
            lastSyncError = error.localizedDescription
            // Keep hasAcceptedShare true if we have a known data source
            if dataSource == .privateDB || UserDefaults.standard.string(forKey: "SharedZoneOwner") != nil {
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

        // If shared path found nothing and we're not already in private mode, try private DB
        if !hasAcceptedShare && dataSource != .privateDB {
            await checkPrivateDatabase()
        }
    }

    /// Check the private database for PartnerBeaconZone (same-account scenario)
    private func checkPrivateDatabase() async {
        debugLog("[CrewLuve] Checking private database for PartnerBeaconZone...")

        do {
            let allZones = try await privateDatabase.allRecordZones()
            debugLog("[CrewLuve] Found \(allZones.count) private zones")

            for zone in allZones {
                if zone.zoneID.zoneName == "PartnerBeaconZone" {
                    debugLog("[CrewLuve] ✅ Found PartnerBeaconZone in private database!")
                    dataSource = .privateDB
                    UserDefaults.standard.set(DataSource.privateDB.rawValue, forKey: dataSourceKey)
                    await checkForSharedData()
                    return
                }
            }

            debugLog("[CrewLuve] No PartnerBeaconZone in private database")
        } catch {
            debugLog("[CrewLuve] Error checking private database: \(error)")
        }
    }

    /// Instant local re-resolve from cached trip legs (no network)
    func reResolve() {
        resolveAndSchedule()
    }

    // MARK: - Trip State Resolution

    /// Resolve current state from trip legs and schedule next transition.
    /// Trusts Duty's pre-computed fields; only overrides displayStatus and location
    /// when the resolver finds an active leg for real-time transitions.
    private func resolveAndSchedule() {
        guard let raw = rawPilotStatus else {
            pilotStatus = nil
            return
        }

        let displayName = resolvedDisplayName ?? raw.pilotFirstName

        guard raw.hasTripLegs else {
            debugLog("[Resolve] No trip legs, using raw status")
            pilotStatus = raw
            return
        }

        let legs = raw.tripLegs
        debugLog("[Resolve] Passing \(legs.count) legs to TripStateResolver")

        let resolved = TripStateResolver.resolve(legs: legs, flightDelayMinutes: raw.flightDelayMinutes, at: Date())

        // If resolver found an active leg, use its real-time data for status/location/flight.
        // Otherwise, trust Duty's pre-computed values entirely.
        let displayStatus = resolved?.displayStatus ?? raw.displayStatus
        let isInFlight = resolved?.isInFlight ?? raw.isInFlight

        pilotStatus = SharedPilotStatus(
            pilotId: raw.pilotId,
            pilotFirstName: displayName,
            homeAirportCode: raw.homeAirportCode,
            displayStatus: displayStatus,
            isSleeping: raw.isSleeping,
            isHome: raw.isHome,
            isInFlight: isInFlight,
            isOnDuty: raw.isOnDuty,
            currentAirport: resolved?.currentAirport ?? raw.currentAirport,
            currentCity: resolved.map { $0.isInFlight ? nil : $0.currentCity } ?? raw.currentCity,
            currentTimezone: resolved?.currentTimezone ?? raw.currentTimezone,
            localTimeAtPilot: resolved == nil ? raw.localTimeAtPilot : nil,
            currentLatitude: resolved == nil ? raw.currentLatitude : nil,
            currentLongitude: resolved == nil ? raw.currentLongitude : nil,
            currentFlightNumber: resolved?.currentFlightNumber ?? raw.currentFlightNumber,
            currentFlightDeparture: resolved?.currentFlightDeparture ?? raw.currentFlightDeparture,
            currentFlightArrival: resolved?.currentFlightArrival ?? raw.currentFlightArrival,
            currentFlightDepartureTime: resolved?.currentFlightDepartureTime ?? raw.currentFlightDepartureTime,
            currentFlightArrivalTime: resolved?.currentFlightArrivalTime ?? raw.currentFlightArrivalTime,
            currentFlightArrivalTimezone: raw.currentFlightArrivalTimezone,
            homeArrivalTime: raw.homeArrivalTime,
            homeArrivalLabel: raw.homeArrivalLabel,
            homeArrivalCity: raw.homeArrivalCity,
            nextDepartureTime: raw.nextDepartureTime,
            nextFlightNumber: raw.nextFlightNumber,
            nextFlightDestination: raw.nextFlightDestination,
            nextDepartureLabel: raw.nextDepartureLabel,
            lastTripEndDate: raw.lastTripEndDate,
            lastTripDurationDays: raw.lastTripDurationDays,
            currentTripId: raw.currentTripId,
            tripDayNumber: raw.tripDayNumber,
            tripTotalDays: raw.tripTotalDays,
            upcomingCities: raw.upcomingCities,
            tripLegsJSON: raw.tripLegsJSON,
            quickStatus: raw.quickStatus,
            quickStatusIcon: raw.quickStatusIcon,
            quickStatusExpiry: raw.quickStatusExpiry,
            flightDelayMinutes: resolved?.flightDelayMinutes ?? raw.flightDelayMinutes,
            displayNameByPartnerJSON: raw.displayNameByPartnerJSON,
            lastUpdated: raw.lastUpdated,
            appVersion: raw.appVersion
        )

        let transitionInfo = resolved?.timeUntilNextTransition.map { String(format: "%.0f", $0) } ?? "nil"
        debugLog("[CrewLuve] Resolved status: \(displayStatus), next transition in \(transitionInfo)s")

        // Schedule re-resolve at next leg boundary for real-time updates
        transitionTask?.cancel()
        if let delay = resolved?.timeUntilNextTransition, delay > 0 {
            transitionTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay + 0.5))
                guard !Task.isCancelled else { return }
                guard let self else { return }
                self.resolveAndSchedule()
            }
        }
    }

    // MARK: - Diagnostic Logging

    /// Compare trip leg IDs between cached and incoming data to detect disappearing legs
    private func logTripLegDiff(old: SharedPilotStatus?, new: SharedPilotStatus, recordModDate: Date?) {
        let oldLegs = old?.tripLegs ?? []
        let newLegs = new.tripLegs

        let oldIds = Set(oldLegs.map(\.id))
        let newIds = Set(newLegs.map(\.id))

        guard oldIds != newIds else { return }

        let removed = oldLegs.filter { !newIds.contains($0.id) }
        let added = newLegs.filter { !oldIds.contains($0.id) }

        debugLog("[TripLegDiff] === LEG CHANGE DETECTED ===")
        debugLog("[TripLegDiff] Count: \(oldLegs.count) → \(newLegs.count)")
        debugLog("[TripLegDiff] Record mod date: \(recordModDate?.formatted(date: .abbreviated, time: .standard) ?? "unknown")")

        for leg in removed {
            debugLog("[TripLegDiff] REMOVED: \(legDescription(leg))")
        }
        for leg in added {
            debugLog("[TripLegDiff] ADDED: \(legDescription(leg))")
        }
    }

    private func legDescription(_ leg: TripLeg) -> String {
        let type = "[\(leg.type.rawValue)]"
        let route: String
        if leg.type == .flight {
            route = "\(leg.departureAirport ?? "?")→\(leg.arrivalAirport ?? "?")"
        } else {
            route = leg.airportCode ?? "?"
        }
        let trip = leg.tripId.map { "trip:\($0)" } ?? "standalone"
        let start = leg.startTime.formatted(date: .abbreviated, time: .shortened)
        let end = leg.endTime.formatted(date: .abbreviated, time: .shortened)
        return "\(type) \(route) (\(trip)) \(start)–\(end)"
    }
}
