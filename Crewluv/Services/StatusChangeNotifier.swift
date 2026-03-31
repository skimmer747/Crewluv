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

    // MARK: - Snapshot Persistence

    private struct PilotSnapshot: Codable {
        let quickStatus: String?
        let flightDelayMinutes: Int?
        let displayStatus: String
        let currentTripId: String?
        let tripTotalDays: Int?
        let homeArrivalTime: Date?
        let nextDepartureTime: Date?
        let pilotFirstName: String
    }

    private static let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private let snapshotKey = "LastSeenPilotSnapshot"
    private var hasSnapshot: Bool {
        UserDefaults.standard.data(forKey: snapshotKey) != nil
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

    /// - Parameter newEffectiveDelay: Pre-computed effective delay for `new`, computed
    ///   on the MainActor side since `tripLegs` requires MainActor access.
    func evaluateChanges(old: SharedPilotStatus?, new: SharedPilotStatus, pilotName: String, newEffectiveDelay: Int? = nil, resolvedHomeArrivalTime: Date? = nil) {
        performEvaluation(old: old, new: new, pilotName: pilotName, newEffectiveDelay: newEffectiveDelay, resolvedHomeArrivalTime: resolvedHomeArrivalTime)
    }

    private func performEvaluation(old: SharedPilotStatus?, new: SharedPilotStatus, pilotName: String, newEffectiveDelay: Int? = nil, resolvedHomeArrivalTime: Date? = nil) {
        let snapshot = loadSnapshot()
        let resolvedNewDelay = newEffectiveDelay ?? new.flightDelayMinutes ?? 0

        // First-ever load — save snapshot, no notifications
        guard let baseline = old ?? snapshotToComparable(snapshot) else {
            saveSnapshot(from: new, effectiveDelay: newEffectiveDelay, resolvedHomeArrivalTime: resolvedHomeArrivalTime)
            debugLog("[Notifier] First load — saving baseline, no notifications")
            return
        }

        debugLog("[Notifier] Baseline delay: \(baseline.flightDelayMinutes ?? 0), new delay: \(resolvedNewDelay)")

        var notifications: [NotificationSpec] = []

        // Schedule changes
        notifications += evaluateScheduleChanges(old: baseline, new: new, name: pilotName, resolvedHomeArrivalTime: resolvedHomeArrivalTime)

        // Quick status
        notifications += evaluateQuickStatus(old: baseline, new: new, name: pilotName)

        // Flight delay
        notifications += evaluateFlightDelay(old: baseline, new: new, name: pilotName, newEffectiveDelay: newEffectiveDelay)

        // Display status transitions
        notifications += evaluateStatusTransitions(old: baseline, new: new, name: pilotName)

        // Save updated snapshot
        saveSnapshot(from: new, effectiveDelay: newEffectiveDelay, resolvedHomeArrivalTime: resolvedHomeArrivalTime)

        // Fire notifications
        for spec in notifications {
            scheduleNotification(spec)
        }

        if !notifications.isEmpty {
            debugLog("[Notifier] Fired \(notifications.count) notification(s)")
        }
    }

    // MARK: - Schedule Changes

    private func evaluateScheduleChanges(
        old: SharedPilotStatus,
        new: SharedPilotStatus,
        name: String,
        resolvedHomeArrivalTime: Date? = nil
    ) -> [NotificationSpec] {
        var specs: [NotificationSpec] = []

        let hadTrip = old.currentTripId != nil
        let hasTrip = new.currentTripId != nil

        // New trip assigned
        if !hadTrip && hasTrip {
            let days = new.tripTotalDays.map { "\($0)-day " } ?? ""
            specs.append(NotificationSpec(
                id: "schedule-new-trip",
                title: name,
                body: "Has a new \(days)trip",
                sound: .default
            ))
        }

        // Trip cancelled
        if hadTrip && !hasTrip {
            specs.append(NotificationSpec(
                id: "schedule-trip-cancelled",
                title: name,
                body: "Trip was cancelled",
                sound: .default
            ))
        }

        // Home arrival time shifted (>15 min)
        // Use the resolved homecoming time (from trip legs) instead of the raw
        // CloudKit value, which may be the base-return time rather than actual homecoming.
        let effectiveNewHome = resolvedHomeArrivalTime ?? new.homeArrivalTime
        if let oldHome = old.homeArrivalTime, let newHome = effectiveNewHome {
            let shift = newHome.timeIntervalSince(oldHome)
            if abs(shift) > 15 * 60 {
                let timeStr = Self.shortTimeFormatter.string(from: newHome)

                if shift > 0 {
                    specs.append(NotificationSpec(
                        id: "schedule-home-arrival",
                        title: name,
                        body: "Getting home later — now \(timeStr)",
                        sound: .default
                    ))
                } else {
                    specs.append(NotificationSpec(
                        id: "schedule-home-arrival",
                        title: name,
                        body: "Getting home earlier — now \(timeStr)",
                        sound: .default
                    ))
                }
            }
        }

        // Departure time shifted (>15 min)
        if let oldDep = old.nextDepartureTime, let newDep = new.nextDepartureTime {
            let shift = newDep.timeIntervalSince(oldDep)
            if abs(shift) > 15 * 60 {
                let timeStr = Self.shortTimeFormatter.string(from: newDep)

                specs.append(NotificationSpec(
                    id: "schedule-departure",
                    title: name,
                    body: "Departure changed — now \(timeStr)",
                    sound: .default
                ))
            }
        }

        // Trip extended/shortened
        if let oldDays = old.tripTotalDays, let newDays = new.tripTotalDays,
           oldDays != newDays, hadTrip, hasTrip {
            let verb = newDays > oldDays ? "extended" : "shortened"
            specs.append(NotificationSpec(
                id: "schedule-trip-duration",
                title: name,
                body: "Trip \(verb) to \(newDays) days",
                sound: .default
            ))
        }

        return specs
    }

    // MARK: - Quick Status

    private func evaluateQuickStatus(
        old: SharedPilotStatus,
        new: SharedPilotStatus,
        name: String
    ) -> [NotificationSpec] {
        guard old.quickStatus != new.quickStatus else { return [] }

        // Cleared — no notification
        guard let status = new.quickStatus, !status.isEmpty else { return [] }

        let body: String
        let isSilent: Bool

        switch status {
        case "Call Me":
            body = "is asking you to call"
            isSilent = false
        case "Free to Talk":
            body = "is free to talk"
            isSilent = false
        case "Out for Dinner":
            body = "went out for dinner"
            isSilent = false
        case "Sleeping":
            body = "is sleeping"
            isSilent = true
        default:
            body = status
            isSilent = false
        }

        return [NotificationSpec(
            id: "quick-status",
            title: name,
            body: body,
            sound: isSilent ? nil : .default
        )]
    }

    // MARK: - Flight Delay

    private func evaluateFlightDelay(
        old: SharedPilotStatus,
        new: SharedPilotStatus,
        name: String,
        newEffectiveDelay: Int? = nil
    ) -> [NotificationSpec] {
        // Baseline's flightDelayMinutes already holds the effective value from the previous snapshot.
        let oldDelay = old.flightDelayMinutes ?? 0
        let newDelay = newEffectiveDelay ?? new.flightDelayMinutes ?? 0

        guard oldDelay != newDelay else { return [] }

        if newDelay > 0 {
            return [NotificationSpec(
                id: "flight-delay",
                title: "\(name)'s Flight",
                body: "Delayed \(newDelay) minutes",
                sound: .default
            )]
        } else {
            return [NotificationSpec(
                id: "flight-delay",
                title: "\(name)'s Flight",
                body: "Delay cleared",
                sound: .default
            )]
        }
    }

    // MARK: - Status Transitions

    private func evaluateStatusTransitions(
        old: SharedPilotStatus,
        new: SharedPilotStatus,
        name: String
    ) -> [NotificationSpec] {
        guard old.displayStatus != new.displayStatus else { return [] }

        switch new.displayStatus {
        case "Home":
            return [NotificationSpec(
                id: "status-transition",
                title: name,
                body: "is home!",
                sound: .default
            )]
        case "In Flight":
            return [NotificationSpec(
                id: "status-transition",
                title: name,
                body: "just took off",
                sound: .default
            )]
        default:
            return []
        }
    }

    // MARK: - Notification Delivery

    private struct NotificationSpec {
        let id: String
        let title: String
        let body: String
        let sound: UNNotificationSound?
    }

    private func scheduleNotification(_ spec: NotificationSpec) {
        let content = UNMutableNotificationContent()
        content.title = spec.title
        content.body = spec.body
        if let sound = spec.sound {
            content.sound = sound
        }

        let request = UNNotificationRequest(
            identifier: "\(spec.id)-\(UUID().uuidString)",
            content: content,
            trigger: nil // Fire immediately
        )

        NotificationDiagnostics.shared.record(.localNotificationFired)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                debugLog("[Notifier] Failed to schedule \(spec.id): \(error)")
            }
        }
    }

    // MARK: - Snapshot Persistence

    private func saveSnapshot(from status: SharedPilotStatus, effectiveDelay: Int? = nil, resolvedHomeArrivalTime: Date? = nil) {
        let snapshot = PilotSnapshot(
            quickStatus: status.quickStatus,
            flightDelayMinutes: effectiveDelay ?? status.flightDelayMinutes,
            displayStatus: status.displayStatus,
            currentTripId: status.currentTripId,
            tripTotalDays: status.tripTotalDays,
            homeArrivalTime: resolvedHomeArrivalTime ?? status.homeArrivalTime,
            nextDepartureTime: status.nextDepartureTime,
            pilotFirstName: status.pilotFirstName
        )

        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: snapshotKey)
        }
    }

    private func loadSnapshot() -> PilotSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(PilotSnapshot.self, from: data)
    }

    private func snapshotToComparable(_ snapshot: PilotSnapshot?) -> SharedPilotStatus? {
        guard let s = snapshot else { return nil }

        return SharedPilotStatus(
            pilotId: "",
            pilotFirstName: s.pilotFirstName,
            homeAirportCode: nil,
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
            tripLegsJSON: nil,
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
