//
//  StatusChangeNotifier.swift
//  CrewLuve
//
//  Diffs old vs new SharedPilotStatus and fires local notifications
//  for meaningful changes (schedule, quickStatus, delays, status transitions).
//

import Foundation
import UserNotifications

actor StatusChangeNotifier {
    static let shared = StatusChangeNotifier()

    /// Where the snapshot is kept, the time zone the alerts' times read in, and what posts an alert. Tests give
    /// their own.
    private let defaults: UserDefaults
    private let timeZone: TimeZone
    private let post: @Sendable (NotificationSpec) -> Void

    init(
        defaults: UserDefaults = .standard,
        timeZone: TimeZone = .current,
        post: @escaping @Sendable (NotificationSpec) -> Void = StatusChangeNotifier.schedule
    ) {
        self.defaults = defaults
        self.timeZone = timeZone
        self.post = post
    }

    // MARK: - Snapshot Persistence

    private struct PilotSnapshot: Codable {
        let quickStatus: String?
        let flightDelayMinutes: Int?
        /// Encodes/decodes as the same single-value String the previous
        /// stringly-typed snapshot used, so persisted JSON stays byte-compatible.
        let displayStatus: PilotDisplayStatus
        let currentTripId: String?
        let tripTotalDays: Int?
        let homeArrivalTime: Date?
        /// The trips the home arrival belongs to (alert pushes spec §15.3). Nil in a snapshot an older Crewluve saved,
        /// whose home arrival is then compared with no other.
        let homeArrivalTrips: [String]?
        let nextDepartureTime: Date?
        let pilotFirstName: String
        let tripLegsJSON: Data?
    }

    private let snapshotKey = "LastSeenPilotSnapshot"
    private let lastEvaluatedKey = "LastEvaluatedPilotStatusTimestamp"
    private var hasSnapshot: Bool {
        defaults.data(forKey: snapshotKey) != nil
    }

    // MARK: - Authorization

    private var hasRequestedAuth = false

    func requestAuthorizationIfNeeded() async {
        guard !hasRequestedAuth else { return }
        hasRequestedAuth = true

        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            debugLog("[Notifier] Authorization \(granted ? "granted" : "denied")")
        } catch {
            debugLog("[Notifier] Authorization error: \(error)")
        }
    }

    // MARK: - Evaluate Changes

    /// Compares `new` with the snapshot, saves it as the next snapshot, and posts its alerts when `posting`. A
    /// reading the alert pushes have already alerted is compared and saved, but posts nothing (alert pushes spec §6.3).
    ///
    /// - Parameter newEffectiveDelay: Pre-computed effective delay for `new`, computed
    ///   on the MainActor side since `tripLegs` requires MainActor access.
    func evaluateChanges(
        old: SharedPilotStatus?,
        new: SharedPilotStatus,
        pilotName: String,
        newEffectiveDelay: Int? = nil,
        resolvedHomeArrivalTime: Date? = nil,
        resolvedHomeArrivalTrips: [String]? = nil,
        posting: Bool = true
    ) {
        // Skip evaluation entirely if Duty hasn't published anything new since
        // the last time we evaluated. Prevents spurious notifications from
        // silent-push replays and BG refreshes against an unchanged record.
        let lastEvaluated = defaults.object(forKey: lastEvaluatedKey) as? Date
        if let lastEvaluated, new.lastUpdated <= lastEvaluated {
            debugLog("[Notifier] Skipping eval — lastUpdated unchanged (\(new.lastUpdated))")
            return
        }

        let snapshot = loadSnapshot()
        let resolvedNewDelay = newEffectiveDelay ?? new.flightDelayMinutes ?? 0

        // First-ever load — save snapshot, no notifications
        guard let baseline = snapshotToComparable(snapshot) ?? old else {
            saveSnapshot(from: new, effectiveDelay: newEffectiveDelay, resolvedHomeArrivalTime: resolvedHomeArrivalTime,
                         resolvedHomeArrivalTrips: resolvedHomeArrivalTrips)
            debugLog("[Notifier] First load — saving baseline, no notifications")
            return
        }

        debugLog("[Notifier] Baseline delay: \(baseline.flightDelayMinutes ?? 0), new delay: \(resolvedNewDelay)")

        var notifications: [NotificationSpec] = []

        // Schedule changes
        notifications += Self.evaluateScheduleChanges(
            old: baseline, new: new, name: pilotName,
            oldHomeArrivalTrips: snapshot?.homeArrivalTrips,
            resolvedHomeArrivalTime: resolvedHomeArrivalTime,
            resolvedHomeArrivalTrips: resolvedHomeArrivalTrips,
            newEffectiveDelay: newEffectiveDelay,
            timeZone: timeZone
        )

        // Quick status
        notifications += Self.evaluateQuickStatus(old: baseline, new: new, name: pilotName, timeZone: timeZone)

        // Flight delay
        notifications += Self.evaluateFlightDelay(old: baseline, new: new, name: pilotName, newEffectiveDelay: newEffectiveDelay,
                                                  timeZone: timeZone)

        // Display status transitions
        notifications += Self.evaluateStatusTransitions(old: baseline, new: new, name: pilotName, timeZone: timeZone)

        // Save updated snapshot
        saveSnapshot(from: new, effectiveDelay: newEffectiveDelay, resolvedHomeArrivalTime: resolvedHomeArrivalTime,
                     resolvedHomeArrivalTrips: resolvedHomeArrivalTrips)

        guard posting else {
            if !notifications.isEmpty {
                debugLog("[Notifier] \(notifications.count) alert(s) left to the alert pushes")
            }
            return
        }

        // Fire notifications
        for spec in notifications {
            post(spec)
        }

        if !notifications.isEmpty {
            debugLog("[Notifier] Fired \(notifications.count) notification(s)")
        }
    }

    // MARK: - Schedule Changes

    /// The schedule's alerts between two statuses (alert pushes spec §5.3, as §15 changed it): a trip added or taken
    /// off, by its legs, and the way home or the departure moving within the same trip. It reads only what it's given,
    /// so it's static, and a test checks that the switch to Crewlu Cloud alerts nothing (partner links piece 4 spec §14).
    nonisolated static func evaluateScheduleChanges(
        old: SharedPilotStatus,
        new: SharedPilotStatus,
        name: String,
        oldHomeArrivalTrips: [String]? = nil,
        resolvedHomeArrivalTime: Date? = nil,
        resolvedHomeArrivalTrips: [String]? = nil,
        newEffectiveDelay: Int? = nil,
        timeZone: TimeZone = .current
    ) -> [NotificationSpec] {
        var specs: [NotificationSpec] = []
        let effectiveNewHome = resolvedHomeArrivalTime ?? new.homeArrivalTime
        let alert = { (kind: AlertKind) in
            spec(kind, name: name, status: new, effectiveDelay: newEffectiveDelay ?? new.flightDelayMinutes ?? 0,
                 homeArrival: effectiveNewHome, timeZone: timeZone)
        }

        // A trip added to the schedule, or taken off it, judged at the new status's moment (alert pushes spec §15).
        let oldLegs = old.tripLegsJSON.flatMap(legs(in:)) ?? []
        let newLegs = new.tripLegsJSON.flatMap(legs(in:)) ?? []
        let added = tripsMissing(from: newLegs, to: oldLegs, at: new.lastUpdated)
        let removed = tripsMissing(from: oldLegs, to: newLegs, at: new.lastUpdated)
        if added > 0 {
            specs.append(alert(added > 1 ? .newTrips : .newTrip))
        }
        if removed > 0 {
            specs.append(alert(removed > 1 ? .tripsCancelled : .tripCancelled))
        }

        // Home arrival time shifted (>15 min), within the same trip.
        // Only evaluate when Duty's underlying data actually changed — either the
        // published homeArrivalTime field or the trip-leg bytes. Otherwise any
        // diff is wall-clock drift from the resolver picking a different leg.
        let publishedHomeChanged = old.homeArrivalTime != effectiveNewHome
        let legsChanged = Self.legsDiffer(old.tripLegsJSON, new.tripLegsJSON)
        let sameTrip = (oldHomeArrivalTrips ?? []).contains { (resolvedHomeArrivalTrips ?? []).contains($0) }

        if (publishedHomeChanged || legsChanged), sameTrip,
           let oldHome = old.homeArrivalTime, let newHome = effectiveNewHome {
            let shift = newHome.timeIntervalSince(oldHome)
            if abs(shift) > 15 * 60 {
                specs.append(alert(shift > 0 ? .homeLater : .homeEarlier))
            }
        }

        // Departure time shifted (>15 min), within the same trip.
        // Only evaluate when the underlying trip-leg bytes changed. Otherwise
        // any diff is the writer's findNextDeparture picking a later leg as
        // the previous one becomes past-tense on each 5-min republish.
        if legsChanged,
           let oldDep = old.nextDepartureTime, let newDep = new.nextDepartureTime,
           !trips(at: oldDep, in: oldLegs).isDisjoint(with: trips(at: newDep, in: newLegs)) {
            if abs(newDep.timeIntervalSince(oldDep)) > 15 * 60 {
                specs.append(alert(.departure))
            }
        }

        // Trip extended/shortened, while the same trip is under way (alert pushes spec §15.3).
        if let oldDays = old.tripTotalDays, let newDays = new.tripTotalDays, oldDays != newDays,
           let trip = old.currentTripId, trip == new.currentTripId {
            specs.append(alert(newDays > oldDays ? .tripExtended : .tripShortened))
        }

        return specs
    }

    // MARK: - Trips

    /// A stretch of time, as a trip's.
    nonisolated struct Span: Equatable, Sendable {
        let start: Date
        let end: Date
    }

    /// The legs' trips, by id, each with its span: from its first leg's start to its last leg's end. Legs with no trip
    /// id belong to none: jumpseats, events and commutes.
    nonisolated static func trips(in legs: [TripLeg]) -> [String: Span] {
        var trips: [String: Span] = [:]
        for leg in legs {
            guard let id = leg.tripId else { continue }
            let span = trips[id]
            trips[id] = Span(start: min(span?.start ?? leg.startTime, leg.startTime),
                             end: max(span?.end ?? leg.endTime, leg.endTime))
        }
        return trips
    }

    /// How many of `from`'s trips `to` has no part of (alert pushes spec §15.3): trips that haven't ended at `moment`,
    /// where no leg of a trip in `to` overlaps their span, each starting before the other ends. Matching by span, a
    /// trip merged on import, imported again, or with its flights moved is still there. When `to` has no trip legs,
    /// none: a status written without its trips, as during a reset of CrewLu's data, never reads as every trip gone,
    /// nor the next as every trip new.
    ///
    /// `to`'s trip legs are sorted by start once, so each trip takes one binary search, as in Crewlu Cloud's
    /// partner-push. Of the legs that start before a trip ends, one overlaps it when the latest of their ends is after
    /// its start.
    nonisolated static func tripsMissing(from: [TripLeg], to: [TripLeg], at moment: Date) -> Int {
        let legs = to.filter { $0.tripId != nil }.sorted { $0.startTime < $1.startTime }
        guard !legs.isEmpty else { return 0 }
        var latestEnd: [Date] = []
        for leg in legs {
            latestEnd.append(max(latestEnd.last ?? leg.endTime, leg.endTime))
        }
        return trips(in: from).values.filter { trip in
            guard trip.end > moment else { return false }
            var starting = 0
            var high = legs.count
            while starting < high {
                let middle = (starting + high) / 2
                if legs[middle].startTime < trip.end {
                    starting = middle + 1
                } else {
                    high = middle
                }
            }
            return starting == 0 || !(latestEnd[starting - 1] > trip.start)
        }.count
    }

    /// The trips a departure belongs to (alert pushes spec §15.3): those whose spans hold it. Where one trip ends as
    /// the next begins, both, so the answer never rests on the order of the legs.
    nonisolated static func trips(at time: Date, in legs: [TripLeg]) -> Set<String> {
        Set(trips(in: legs).filter { $0.value.start <= time && time <= $0.value.end }.keys)
    }

    // MARK: - Legs

    /// Whether two statuses' legs differ, compared as legs: iCloud and Crewlu Cloud write the same
    /// legs with their keys in another order, and iCloud's with fields this app doesn't read
    /// (partner links piece 4 spec §14). Bytes that don't read as legs compare as bytes, as before.
    nonisolated static func legsDiffer(_ old: Data?, _ new: Data?) -> Bool {
        guard let old, let new, let oldLegs = legs(in: old), let newLegs = legs(in: new) else { return old != new }
        return oldLegs != newLegs
    }

    private nonisolated static func legs(in data: Data) -> [TripLeg]? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode([TripLeg].self, from: data)
    }

    // MARK: - Quick Status

    private nonisolated static func evaluateQuickStatus(
        old: SharedPilotStatus,
        new: SharedPilotStatus,
        name: String,
        timeZone: TimeZone
    ) -> [NotificationSpec] {
        guard old.quickStatus != new.quickStatus else { return [] }

        // Cleared — no notification
        guard let status = new.quickStatus, !status.isEmpty else { return [] }

        return [spec(.quickStatus, name: name, status: new, effectiveDelay: 0, homeArrival: nil, timeZone: timeZone)]
    }

    // MARK: - Flight Delay

    private nonisolated static func evaluateFlightDelay(
        old: SharedPilotStatus,
        new: SharedPilotStatus,
        name: String,
        newEffectiveDelay: Int? = nil,
        timeZone: TimeZone
    ) -> [NotificationSpec] {
        // Baseline's flightDelayMinutes already holds the effective value from the previous snapshot.
        let oldDelay = old.flightDelayMinutes ?? 0
        let newDelay = newEffectiveDelay ?? new.flightDelayMinutes ?? 0

        guard oldDelay != newDelay else { return [] }

        let kind: AlertKind
        if newDelay > 0 {
            kind = .delayed
        } else if newDelay < 0 {
            kind = .early
        } else {
            kind = oldDelay < 0 ? .earlyCleared : .delayCleared
        }

        return [spec(kind, name: name, status: new, effectiveDelay: newDelay, homeArrival: nil, timeZone: timeZone)]
    }

    // MARK: - Status Transitions

    private nonisolated static func evaluateStatusTransitions(
        old: SharedPilotStatus,
        new: SharedPilotStatus,
        name: String,
        timeZone: TimeZone
    ) -> [NotificationSpec] {
        guard old.displayStatus != new.displayStatus else { return [] }

        switch new.displayStatus {
        case .home:
            return [spec(.home, name: name, status: new, effectiveDelay: 0, homeArrival: nil, timeZone: timeZone)]
        case .inFlight:
            return [spec(.tookOff, name: name, status: new, effectiveDelay: 0, homeArrival: nil, timeZone: timeZone)]
        case .base, .commutingHome, .drivingHome, .drivingToWork, .turn, .layover, .reserve, .hotStandby, .training, .elsewhere, .unknown:
            return []
        }
    }

    // MARK: - Notification Delivery

    /// One alert: its kind, its words, and whether it plays a sound.
    nonisolated struct NotificationSpec: Equatable, Sendable {
        let kind: AlertKind
        let title: String
        let body: String
        let playsSound: Bool
    }

    /// An alert of `kind` about `status`, in its words (`AlertWording`), or in its plain line should the status not
    /// fit the kind.
    private nonisolated static func spec(
        _ kind: AlertKind,
        name: String,
        status: SharedPilotStatus,
        effectiveDelay: Int,
        homeArrival: Date?,
        timeZone: TimeZone
    ) -> NotificationSpec {
        let words = AlertWording.words(
            for: kind, name: name, status: status, effectiveDelay: effectiveDelay, homeArrival: homeArrival, timeZone: timeZone
        )
        return NotificationSpec(
            kind: kind,
            title: words?.title ?? name,
            body: words?.body ?? AlertWording.plainLine(for: kind),
            playsSound: AlertWording.playsSound(kind, quickStatus: status.quickStatus)
        )
    }

    /// Posts an alert now.
    nonisolated static func schedule(_ spec: NotificationSpec) {
        let content = UNMutableNotificationContent()
        content.title = spec.title
        content.body = spec.body
        if spec.playsSound {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: "\(spec.kind.rawValue)-\(UUID().uuidString)",
            content: content,
            trigger: nil // Fire immediately
        )

        NotificationDiagnostics.shared.record(.localNotificationFired)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                debugLog("[Notifier] Failed to schedule \(spec.kind.rawValue): \(error)")
            }
        }
    }

    // MARK: - Snapshot Persistence

    private func saveSnapshot(
        from status: SharedPilotStatus,
        effectiveDelay: Int? = nil,
        resolvedHomeArrivalTime: Date? = nil,
        resolvedHomeArrivalTrips: [String]? = nil
    ) {
        let snapshot = PilotSnapshot(
            quickStatus: status.quickStatus,
            flightDelayMinutes: effectiveDelay ?? status.flightDelayMinutes,
            displayStatus: status.displayStatus,
            currentTripId: status.currentTripId,
            tripTotalDays: status.tripTotalDays,
            homeArrivalTime: resolvedHomeArrivalTime ?? status.homeArrivalTime,
            homeArrivalTrips: resolvedHomeArrivalTrips,
            nextDepartureTime: status.nextDepartureTime,
            pilotFirstName: status.pilotFirstName,
            tripLegsJSON: status.tripLegsJSON
        )

        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
        }
        defaults.set(status.lastUpdated, forKey: lastEvaluatedKey)
    }

    private func loadSnapshot() -> PilotSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(PilotSnapshot.self, from: data)
    }

    private func snapshotToComparable(_ snapshot: PilotSnapshot?) -> SharedPilotStatus? {
        guard let s = snapshot else { return nil }

        return SharedPilotStatus(
            pilotId: "",
            pilotFirstName: s.pilotFirstName,
            homeAirportCode: nil,
            baseAirportCode: nil,
            homeTimezone: nil,
            displayStatus: s.displayStatus,
            isSleeping: false,
            isHome: false,
            isInFlight: false,
            isOnDuty: false,
            currentAirport: nil,
            currentCity: nil,
            currentTimezone: nil,
            localTimeAtPilot: nil,
            currentLatitude: nil,
            currentLongitude: nil,
            currentFlightNumber: nil,
            currentFlightDeparture: nil,
            currentFlightArrival: nil,
            currentFlightDepartureTime: nil,
            currentFlightArrivalTime: nil,
            currentFlightArrivalTimezone: nil,
            homeArrivalTime: s.homeArrivalTime,
            homeArrivalLabel: nil,
            homeArrivalCity: nil,
            nextDepartureTime: s.nextDepartureTime,
            nextFlightNumber: nil,
            nextFlightDestination: nil,
            nextDepartureLabel: nil,
            lastTripEndDate: nil,
            lastTripDurationDays: nil,
            currentTripId: s.currentTripId,
            tripDayNumber: nil,
            tripTotalDays: s.tripTotalDays,
            upcomingCities: [],
            tripLegsJSON: s.tripLegsJSON,
            quickStatus: s.quickStatus,
            quickStatusIcon: nil,
            quickStatusExpiry: nil,
            flightDelayMinutes: s.flightDelayMinutes,
            displayNameByPartnerJSON: nil,
            lastUpdated: .distantPast,
            appVersion: ""
        )
    }
}
