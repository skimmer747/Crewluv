//
//  PartnerStatusReceiver.swift
//  CrewLuve
//
//  The status screen's model: the pilot's status as PilotStatusSource reads it
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
    private(set) var isInDemoMode = false

    // MARK: - Data Source

    enum DataSource: String {
        case shared
        case privateDB
    }

    var dataSource: DataSource? = nil

    private let container = CKContainer(identifier: "iCloud.com.toddanderson.duty")
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }
    private let dataSourceKey = "PilotDataSource"
    private let statusSource: PilotStatusSource
    private let periodicCheck = RepeatingRefresh()
    private var transitionTask: Task<Void, Never>?

    init(shareManager: CloudKitShareManager) {
        statusSource = .shared

        // Restore persisted data source
        if let raw = UserDefaults.standard.string(forKey: dataSourceKey),
           let source = DataSource(rawValue: raw) {
            dataSource = source
            debugLog("[StatusReceiver] Restored data source: \(raw)")
        }

        // An accepted share takes precedence over a stale .privateDB lock.
        // Why: a cross-account user who once tripped the same-account fallback
        // would otherwise be stuck reading their own zone forever.
        if dataSource == .privateDB,
           UserDefaults.standard.string(forKey: "SharedZoneOwner") != nil {
            dataSource = .shared
            UserDefaults.standard.set(DataSource.shared.rawValue, forKey: dataSourceKey)
            debugLog("[StatusReceiver] Corrected data source to .shared (share owner present)")
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

        // Show how every read went, whoever asked for it: this screen, a push, the background
        // refresh or the 60-second check. The source posts on the main actor.
        NotificationCenter.default.addObserver(
            forName: .pilotStatusDidUpdate,
            object: statusSource,
            queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let update = self.statusSource.lastUpdate else { return }
                self.show(update)
            }
        }

        // Retry when iCloud reports an account change — Apple's signal that an account
        // that was temporarily unavailable (CKError 36) is ready for CloudKit again.
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            debugLog("[StatusReceiver] iCloud account changed, refreshing...")
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
                self.statusSource.forgetICloudReading()
                self.dataSource = nil
                self.hasAcceptedShare = false
                self.pilotStatus = nil
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

            // If still no data found, check private database (same-account scenario).
            // Skip when a share has ever been recorded — its presence proves cross-account
            // intent, and self-zone discovery would silently shadow the partner's zone.
            if !hasAcceptedShare && UserDefaults.standard.string(forKey: "SharedZoneOwner") == nil {
                await checkPrivateDatabase()
            }
        }
    }

    /// Reads the pilot's status through the status source. How the read went reaches `show(_:)`,
    /// as every read's does.
    func checkForSharedData() async {
        if pilotStatus == nil {
            isLoading = true
        }
        isSyncing = true
        defer {
            isLoading = false
            isSyncing = false
        }

        // Sync in-memory dataSource with whatever UserDefaults says before fetching.
        // CloudKitShareManager.acceptShare writes "shared" to UserDefaults to break a prior
        // .privateDB lock (which can fire when Duty is installed on the same device and
        // its own PartnerBeaconZone is visible in the private DB), but the in-memory enum
        // would otherwise stay stuck on .privateDB and keep showing the local Duty data.
        syncDataSourceFromDefaults()

        debugLog("[StatusReceiver] Starting sync")

        // The iCloud account matters only while the status comes through iCloud.
        if !statusSource.isOnCrewluCloud {
            do {
                let accountStatus = try await container.accountStatus()
                if let issue = CloudAccountIssue(accountStatus: accountStatus) {
                    debugLog("[StatusReceiver] iCloud account not available: \(accountStatus.rawValue)")
                    errorMessage = issue.message
                    lastSyncError = "iCloud unavailable"
                    // An account that isn't ready says nothing about the share. Keep a recorded
                    // connection so the partner sees how to fix iCloud rather than onboarding;
                    // the CKAccountChanged observer retries once the account is available.
                    hasAcceptedShare = hasRecordedConnection
                    return
                }
            } catch {
                showFailure(error.localizedDescription)
                return
            }
        }

        _ = await statusSource.refresh()
    }

    /// Shows how a read went, whoever asked for it.
    private func show(_ update: PilotStatusUpdate) {
        guard !isInDemoMode else { return }
        switch update.outcome {
        case .newStatus, .unchanged:
            showReading()
            lastSyncTime = update.readAt
            lastSyncError = nil
            debugLog("[StatusReceiver] Sync complete")
        case .noStatusYet:
            hasAcceptedShare = true
            lastSyncTime = update.readAt
            lastSyncError = nil
            errorMessage = "Waiting for your pilot's first update."
        case .notConnected:
            debugLog("[StatusReceiver] No stored zone owner - share not yet accepted")
            hasAcceptedShare = false
            lastSyncError = "No share accepted"
            errorMessage = "Please accept the share invitation from your pilot."
        case .sharingEnded:
            // The pilot revoked sharing. The source has already forgotten the share or the
            // connection, so stop showing the status and surface a copy that says so.
            debugLog("[StatusReceiver] ⚠️ Sharing has ended")
            transitionTask?.cancel()
            hasAcceptedShare = false
            pilotStatus = nil
            errorMessage = "Sharing has ended. Ask your pilot for a new pairing link."
            lastSyncError = "share ended"
        case .failed(let message):
            showFailure(message)
        }
    }

    /// Shows the source's reading, resolved for now. With none, there's nothing to show.
    private func showReading() {
        guard !isInDemoMode else { return }
        guard statusSource.reading != nil else {
            transitionTask?.cancel()
            pilotStatus = nil
            hasAcceptedShare = false
            return
        }
        resolveAndSchedule()
        hasAcceptedShare = true
    }

    private func showFailure(_ message: String) {
        debugLog("[StatusReceiver] ❌ Error fetching status: \(message)")
        lastSyncError = message
        // Keep hasAcceptedShare true if we have a known data source
        if hasRecordedConnection {
            hasAcceptedShare = true
            errorMessage = "Unable to load pilot status. Please try again."
        } else {
            hasAcceptedShare = false
            errorMessage = "Please accept the share invitation from your pilot."
        }
    }

    // MARK: - Demo Mode

    func enterDemoMode() {
        isInDemoMode = true
        pilotStatus = .demo
        hasAcceptedShare = true
        isLoading = false
        errorMessage = nil
    }

    func exitDemoMode() {
        isInDemoMode = false
        pilotStatus = nil
        hasAcceptedShare = false
    }

    /// Refresh pilot status manually
    func refresh() async {
        if isInDemoMode {
            pilotStatus = .demo
            return
        }

        await checkForSharedData()

        // If shared path found nothing and we're not already in private mode, try private DB
        if !hasAcceptedShare && dataSource != .privateDB && !statusSource.isOnCrewluCloud {
            await checkPrivateDatabase()
        }
    }

    /// Pulls the persisted data source out of UserDefaults and applies it to the in-memory
    /// enum. Called at the top of each `checkForSharedData()` so a write from
    /// `CloudKitShareManager.acceptShare` (e.g., after the user taps an incoming share
    /// link) takes effect on the very next fetch instead of waiting for app relaunch.
    private func syncDataSourceFromDefaults() {
        guard let raw = UserDefaults.standard.string(forKey: dataSourceKey),
              let source = DataSource(rawValue: raw),
              source != dataSource else { return }
        debugLog("[StatusReceiver] dataSource synced from UserDefaults: \(dataSource?.rawValue ?? "nil") → \(raw)")
        dataSource = source
    }

    /// Whether this device has connected to pilot data — Crewlu Cloud, a stored share owner or
    /// the same-account private zone. Transient failures must not undo that.
    private var hasRecordedConnection: Bool {
        statusSource.isOnCrewluCloud
            || dataSource == .privateDB
            || UserDefaults.standard.string(forKey: "SharedZoneOwner") != nil
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
        let now = Date()
        guard let reading = statusSource.reading else {
            pilotStatus = nil
            return
        }

        let raw = reading.status(at: now)
        let displayName = reading.displayName ?? raw.pilotFirstName

        guard raw.hasTripLegs else {
            debugLog("[Resolve] No trip legs, using raw status")
            pilotStatus = raw
            scheduleResolve(transition: nil, reading: reading, now: now)
            return
        }

        let legs = raw.tripLegs
        debugLog("[Resolve] Passing \(legs.count) legs to TripStateResolver")

        let resolved = TripStateResolver.resolve(legs: legs, flightDelayMinutes: raw.flightDelayMinutes, homeAirportCode: raw.homeAirportCode, baseAirportCode: raw.baseAirportCode, at: now)

        // If resolver found an active leg, use its real-time data for status/location/flight.
        // Otherwise, trust Duty's pre-computed values entirely.
        let displayStatus = resolved?.displayStatus ?? raw.displayStatus
        let isInFlight = resolved?.isInFlight ?? raw.isInFlight

        // Find when the pilot's current trip brings him home: the last homebound
        // leg — flight or drive — of the trip block he is in (see resolveHomeArrival).
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
            // Drop a past arrival time — resolve() will have flipped displayStatus to
            // Home, and no surface should render a negative countdown during the transition.
            effectiveHomeArrivalTime = homeArrival.arrivalTime > now ? homeArrival.arrivalTime : nil
        } else {
            // No homebound flight in legs — use Duty's data.
            // If Duty's time is also stale, try resolveTripEnd for the trip-end fallback.
            let tripEnd = isDutyTimeStale
                ? TripStateResolver.resolveTripEnd(legs: legs, homeAirportCode: raw.homeAirportCode, at: now)
                : nil
            effectiveHomeArrivalLabel = tripEnd?.arrivalLabel ?? raw.homeArrivalLabel
            effectiveHomeArrivalCity = tripEnd?.arrivalCity ?? raw.homeArrivalCity
            // Drop a past arrival (e.g. a commuter already sitting at base with no
            // homebound leg logged): a past instant would render a frozen "Now!" card.
            // The view then falls back to the schedule link instead of lying.
            effectiveHomeArrivalTime = (tripEnd?.arrivalTime ?? raw.homeArrivalTime).flatMap { $0 > now ? $0 : nil }
        }

        if let homeArrival {
            debugLog("[Resolve] Home arrival from legs: label=\(homeArrival.arrivalLabel) city=\(homeArrival.arrivalCity ?? "nil") time=\(homeArrival.arrivalTime.formatted(date: .abbreviated, time: .shortened))")
        }

        // Compute trip progress from legs — always current, unlike
        // raw.tripDayNumber/tripTotalDays which Duty writes once per trip.
        let isHomeStatus = displayStatus.isSettled
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
            baseAirportCode: raw.baseAirportCode,
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
        debugLog("[StatusReceiver] Resolved status: \(displayStatus.rawDisplayString), next transition in \(transitionInfo)s")

        scheduleResolve(transition: resolved?.timeUntilNextTransition, reading: reading, now: now)
    }

    /// Schedules a re-resolve at the next leg boundary, or when the quick status shown now
    /// expires and another may take its place, whichever comes first.
    private func scheduleResolve(transition: TimeInterval?, reading: PilotReading, now: Date) {
        transitionTask?.cancel()
        let quickStatusChange = reading.change(after: now).map { $0.timeIntervalSince(now) }
        guard let delay = [transition, quickStatusChange].compactMap({ $0 }).filter({ $0 > 0 }).min() else { return }
        transitionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay + 0.5))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            self.resolveAndSchedule()
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

    // MARK: - The 60-Second Check

    /// While the app is in front, on Crewlu Cloud and outside the demo, reads every 60 seconds
    /// (partner links piece 4 spec §5.5). With nothing new, Crewlu Cloud answers "unchanged".
    func startPeriodicCheck() {
        guard statusSource.isOnCrewluCloud, !isInDemoMode else {
            periodicCheck.stop()
            return
        }
        periodicCheck.start { [weak self] in
            await self?.refresh()
        }
    }

    func stopPeriodicCheck() {
        periodicCheck.stop()
    }
}
