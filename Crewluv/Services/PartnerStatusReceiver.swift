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

        // Listen for CloudKit silent pushes
        NotificationCenter.default.addObserver(
            forName: .cloudKitPushReceived,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            debugLog("[StatusReceiver] Received CloudKit push, refreshing...")
            Task { @MainActor in
                await self?.refresh()
            }
        }

        // Listen for share data reset (disconnect)
        NotificationCenter.default.addObserver(
            forName: .shareDataReset,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            debugLog("[StatusReceiver] Share data reset, clearing state")
            guard let self else { return }
            Task { @MainActor in
                self.dataSource = nil
                self.hasAcceptedShare = false
                self.pilotStatus = nil
                self.rawPilotStatus = nil
                self.errorMessage = nil
                self.lastSyncError = nil
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
        debugLog("[StatusReceiver] Starting sync")

        do {
            // Use the account status to check if we have iCloud access
            let accountStatus = try await container.accountStatus()
            guard accountStatus == .available else {
                debugLog("[StatusReceiver] iCloud account not available: \(accountStatus.rawValue)")
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
                debugLog("[StatusReceiver] Using private database (same-account mode)")
            } else {
                // Get the stored zone owner name from when the share was accepted
                guard let storedOwner = UserDefaults.standard.string(forKey: "SharedZoneOwner") else {
                    debugLog("[StatusReceiver] No stored zone owner - share not yet accepted")
                    hasAcceptedShare = false
                    lastSyncError = "No share accepted"
                    errorMessage = "Please accept the share invitation from your pilot."
                    return
                }
                database = sharedDatabase
                ownerName = storedOwner
                debugLog("[StatusReceiver] Using shared database with zone owner: \(ownerName)")
            }

            // Construct the zone ID with the owner name
            let zoneID = CKRecordZone.ID(zoneName: "PartnerBeaconZone", ownerName: ownerName)

            // Fetch the SharedPilotStatus record by its well-known ID
            // We use a fixed record name "pilot-status" so we can fetch without querying
            let statusRecordID = CKRecord.ID(recordName: "pilot-status", zoneID: zoneID)

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

            guard let newStatus = SharedPilotStatus.from(record: statusRecord) else {
                throw NSError(domain: "CrewLuve", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse status record"])
            }

            debugLog("[StatusReceiver] Raw delay: \(newStatus.flightDelayMinutes.map(String.init) ?? "nil"), effective: \(newStatus.effectiveFlightDelayMinutes.map(String.init) ?? "nil")")

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
                    UserDefaults.standard.set(name, forKey: "ResolvedPilotDisplayName")
                    debugLog("[StatusReceiver] Resolved display name: \(name)")
                } else {
                    UserDefaults.standard.removeObject(forKey: "ResolvedPilotDisplayName")
                }
            }

            // Check if data actually changed
            let isInitialLoad = pilotStatus == nil
            let changed = pilotStatus.map { $0.lastUpdated != newStatus.lastUpdated } ?? true
            debugLog("[StatusReceiver] Data changed: \(changed ? "YES" : "NO"), initial: \(isInitialLoad)")

            if changed {
                let effectiveDelay = newStatus.effectiveFlightDelayMinutes
                let pilotName = UserDefaults.standard.string(forKey: "ResolvedPilotDisplayName")
                    ?? newStatus.pilotFirstName
                let previousStatus = pilotStatus
                let resolvedHome = TripStateResolver.resolveHomeArrival(
                    legs: newStatus.tripLegs, homeAirportCode: newStatus.homeAirportCode, at: Date()
                )?.arrivalTime
                Task.detached {
                    await StatusChangeNotifier.shared.evaluateChanges(
                        old: previousStatus, new: newStatus, pilotName: pilotName,
                        newEffectiveDelay: effectiveDelay,
                        resolvedHomeArrivalTime: resolvedHome ?? newStatus.homeArrivalTime
                    )
                }
            }

            logTripLegDiff(old: rawPilotStatus, new: newStatus, recordModDate: statusRecord.modificationDate)
            rawPilotStatus = newStatus
            resolveAndSchedule()
            hasAcceptedShare = true
            lastSyncTime = syncStartTime
            lastSyncError = nil

            debugLog("[StatusReceiver] Sync complete")
        } catch {
            debugLog("[StatusReceiver] ❌ Error fetching status: \(error)")
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
        debugLog("[StatusReceiver] Checking private database for PartnerBeaconZone...")

        do {
            let allZones = try await privateDatabase.allRecordZones()
            debugLog("[StatusReceiver] Found \(allZones.count) private zones")

            for zone in allZones {
                if zone.zoneID.zoneName == "PartnerBeaconZone" {
                    debugLog("[StatusReceiver] ✅ Found PartnerBeaconZone in private database!")
                    dataSource = .privateDB
                    UserDefaults.standard.set(DataSource.privateDB.rawValue, forKey: dataSourceKey)
                    await checkForSharedData()
                    return
                }
            }

            debugLog("[StatusReceiver] No PartnerBeaconZone in private database")
        } catch {
            debugLog("[StatusReceiver] Error checking private database: \(error)")
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

        let now = Date()
        let resolved = TripStateResolver.resolve(legs: legs, flightDelayMinutes: raw.flightDelayMinutes, homeAirportCode: raw.homeAirportCode, at: now)

        // If resolver found an active leg, use its real-time data for status/location/flight.
        // Otherwise, trust Duty's pre-computed values entirely.
        let displayStatus = resolved?.displayStatus ?? raw.displayStatus
        let isInFlight = resolved?.isInFlight ?? raw.isInFlight

        // Find when the pilot arrives home by scanning ALL legs for the first
        // future flight to the home airport (handles multi-trip absences).
        let homeArrival = TripStateResolver.resolveHomeArrival(
            legs: legs, homeAirportCode: raw.homeAirportCode, at: now
        )

        // When a homebound flight exists in legs, use it for the card.
        // Fall back to Duty's values when no homebound leg is found,
        // or when Duty's time is fresher (not stale).
        let isDutyTimeStale = raw.homeArrivalTime.map { $0 <= now } ?? true

        let effectiveHomeArrivalLabel: String?
        let effectiveHomeArrivalCity: String?
        let effectiveHomeArrivalTime: Date?

        if let homeArrival {
            // Legs have a homebound flight — always use its label, city, and time.
            // Duty's homeArrivalTime may refer to a different event (e.g. base return),
            // so mixing it with the leg's label/city would produce incorrect results.
            effectiveHomeArrivalLabel = homeArrival.arrivalLabel
            effectiveHomeArrivalCity = homeArrival.arrivalCity
            effectiveHomeArrivalTime = homeArrival.arrivalTime
        } else {
            // No homebound flight in legs — use Duty's data.
            // If Duty's time is also stale, try resolveTripEnd for the trip-end fallback.
            let tripEnd = isDutyTimeStale
                ? TripStateResolver.resolveTripEnd(legs: legs, homeAirportCode: raw.homeAirportCode, at: now)
                : nil
            effectiveHomeArrivalLabel = tripEnd?.arrivalLabel ?? raw.homeArrivalLabel
            effectiveHomeArrivalCity = tripEnd?.arrivalCity ?? raw.homeArrivalCity
            effectiveHomeArrivalTime = tripEnd?.arrivalTime ?? raw.homeArrivalTime
        }

        if let homeArrival {
            debugLog("[Resolve] Home arrival from legs: label=\(homeArrival.arrivalLabel) city=\(homeArrival.arrivalCity ?? "nil") time=\(homeArrival.arrivalTime.formatted(date: .abbreviated, time: .shortened))")
        }

        // Compute trip progress from legs — always current, unlike
        // raw.tripDayNumber/tripTotalDays which Duty writes once per trip.
        let isHomeStatus = ["Home", "Base"].contains(displayStatus)
        let sorted = legs.sorted { $0.startTime < $1.startTime }

        let effectiveTripDayNumber: Int?
        let effectiveTripTotalDays: Int?
        let effectiveUpcomingCities: [String]

        if isHomeStatus {
            effectiveTripDayNumber = nil
            effectiveTripTotalDays = nil
            effectiveUpcomingCities = []
        } else if let tripId = currentTripId(sorted: sorted, at: now) {
            let tripLegs = sorted.filter { $0.tripId == tripId }
            if let firstLeg = tripLegs.first, let lastLeg = tripLegs.last {
                let calendar = Calendar.current
                let startDay = calendar.startOfDay(for: firstLeg.startTime)
                let today = calendar.startOfDay(for: now)
                let endDay = calendar.startOfDay(for: lastLeg.endTime)

                effectiveTripDayNumber = max(1, (calendar.dateComponents([.day], from: startDay, to: today).day ?? 0) + 1)
                effectiveTripTotalDays = max(1, (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1)
                effectiveUpcomingCities = sorted
                    .filter { $0.tripId == tripId && $0.type == .flight && $0.startTime > now }
                    .compactMap(\.arrivalCity)
            } else {
                effectiveTripDayNumber = nil
                effectiveTripTotalDays = nil
                effectiveUpcomingCities = []
            }
        } else {
            // No identifiable trip in legs — fall back to raw (best effort)
            effectiveTripDayNumber = raw.tripDayNumber
            effectiveTripTotalDays = raw.tripTotalDays
            effectiveUpcomingCities = raw.upcomingCities
        }

        pilotStatus = SharedPilotStatus(
            pilotId: raw.pilotId,
            pilotFirstName: displayName,
            homeAirportCode: raw.homeAirportCode,
            homeTimezone: raw.homeTimezone,
            displayStatus: displayStatus,
            isSleeping: raw.isSleeping,
            isHome: raw.isHome,
            isInFlight: isInFlight,
            isOnDuty: raw.isOnDuty,
            currentAirport: resolved.flatMap(\.currentAirport) ?? raw.currentAirport,
            currentCity: resolved.map { $0.isInFlight ? nil : $0.currentCity } ?? raw.currentCity,
            currentTimezone: resolved.flatMap(\.currentTimezone) ?? raw.currentTimezone,
            localTimeAtPilot: resolved == nil ? raw.localTimeAtPilot : nil,
            currentLatitude: resolved == nil ? raw.currentLatitude : nil,
            currentLongitude: resolved == nil ? raw.currentLongitude : nil,
            currentFlightNumber: resolved.flatMap(\.currentFlightNumber) ?? raw.currentFlightNumber,
            currentFlightDeparture: resolved.flatMap(\.currentFlightDeparture) ?? raw.currentFlightDeparture,
            currentFlightArrival: resolved.flatMap(\.currentFlightArrival) ?? raw.currentFlightArrival,
            currentFlightDepartureTime: resolved.flatMap(\.currentFlightDepartureTime) ?? raw.currentFlightDepartureTime,
            currentFlightArrivalTime: resolved.flatMap(\.currentFlightArrivalTime) ?? raw.currentFlightArrivalTime,
            currentFlightArrivalTimezone: resolved.flatMap(\.currentFlightArrivalTimezone) ?? raw.currentFlightArrivalTimezone,
            homeArrivalTime: effectiveHomeArrivalTime,
            homeArrivalLabel: effectiveHomeArrivalLabel,
            homeArrivalCity: effectiveHomeArrivalCity,
            nextDepartureTime: raw.nextDepartureTime,
            nextFlightNumber: raw.nextFlightNumber,
            nextFlightDestination: raw.nextFlightDestination,
            nextDepartureLabel: raw.nextDepartureLabel,
            lastTripEndDate: raw.lastTripEndDate,
            lastTripDurationDays: raw.lastTripDurationDays,
            currentTripId: raw.currentTripId,
            tripDayNumber: effectiveTripDayNumber,
            tripTotalDays: effectiveTripTotalDays,
            upcomingCities: effectiveUpcomingCities,
            tripLegsJSON: raw.tripLegsJSON,
            quickStatus: raw.quickStatus,
            quickStatusIcon: raw.quickStatusIcon,
            quickStatusExpiry: raw.quickStatusExpiry,
            flightDelayMinutes: resolved.flatMap(\.flightDelayMinutes) ?? raw.flightDelayMinutes,
            displayNameByPartnerJSON: raw.displayNameByPartnerJSON,
            lastUpdated: raw.lastUpdated,
            appVersion: raw.appVersion
        )

        let transitionInfo = resolved?.timeUntilNextTransition.map { String(format: "%.0f", $0) } ?? "nil"
        debugLog("[StatusReceiver] Resolved status: \(displayStatus), next transition in \(transitionInfo)s")

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

    // MARK: - Trip Identification

    /// Find the tripId for the pilot's current context.
    /// Active leg -> its trip. Same-trip gap -> that trip. Between trips -> next trip.
    private func currentTripId(sorted: [TripLeg], at now: Date) -> String? {
        let activeLeg = sorted.first { $0.startTime <= now && now < $0.endTime }
        if let tripId = activeLeg?.tripId { return tripId }

        let completedLeg = sorted.last { $0.endTime <= now }
        let nextLeg = sorted.first { $0.startTime > now }

        // Same-trip gap (Turn/Layover)
        if let c = completedLeg, let n = nextLeg, c.tripId != nil, c.tripId == n.tripId {
            return c.tripId
        }

        // Between trips -> show next trip. All done -> last trip.
        return nextLeg?.tripId ?? completedLeg?.tripId
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
