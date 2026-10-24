//
//  AlertWording.swift
//  CrewLuve
//
//  The alerts' kinds and words, for the app's own alerts and the alert pushes' helper
//

import Foundation

/// An alert's kind, as Crewlu Cloud's partner-push names it in an alert push (alert pushes spec §5.3, §15).
nonisolated enum AlertKind: String, CaseIterable, Sendable {
    case newTrip = "new-trip"
    case newTrips = "new-trips"
    case tripCancelled = "trip-cancelled"
    case tripsCancelled = "trips-cancelled"
    case homeLater = "home-later"
    case homeEarlier = "home-earlier"
    case departure
    case tripExtended = "trip-extended"
    case tripShortened = "trip-shortened"
    case quickStatus = "quick-status"
    case delayed
    case early
    case delayCleared = "delay-cleared"
    case earlyCleared = "early-cleared"
    case home
    case tookOff = "took-off"
}

/// The words an alert shows (alert pushes spec §5.3, §6.1, §6.4, §15.4): the pilot's name as this partner sees it, or
/// their flight, and what happened, with the numbers and times from the status the alert is about. The app's own
/// alerts and the helper's use the same words.
nonisolated enum AlertWording {
    /// What an alert push of a kind this app doesn't know shows: the push's own line.
    static let unknownKind = "New update"

    /// The title and body for `kind`, titled with `name`, from `status` and what's worked out of it at the moment:
    /// the effective delay and the home arrival. Times read "h:mm a" in `timeZone`. Nil when the status no longer
    /// fits the kind, as when the quick status was cleared or the delay is gone: the helper shows the plain line.
    static func words(
        for kind: AlertKind,
        name: String,
        status: SharedPilotStatus,
        effectiveDelay: Int,
        homeArrival: Date?,
        timeZone: TimeZone = .current
    ) -> (title: String, body: String)? {
        let flight = "\(name)'s Flight"
        switch kind {
        case .quickStatus:
            guard let quickStatus = status.quickStatus, !quickStatus.isEmpty else { return nil }
            return (name, quickStatusWords[quickStatus] ?? quickStatus)
        case .delayed:
            return effectiveDelay > 0 ? (flight, "Delayed \(effectiveDelay) minutes") : nil
        case .early:
            return effectiveDelay < 0 ? (flight, "Departing \(-effectiveDelay) minutes early") : nil
        case .delayCleared:
            return effectiveDelay == 0 ? (flight, "Delay cleared") : nil
        case .earlyCleared:
            return effectiveDelay == 0 ? (flight, "Early departure cleared") : nil
        case .home:
            return (name, "is home!")
        case .tookOff:
            return (name, "just took off")
        case .newTrip:
            return (name, "Has a new trip")
        case .newTrips:
            return (name, "Has new trips")
        case .tripCancelled:
            return (name, "Trip was cancelled")
        case .tripsCancelled:
            return (name, "Trips were cancelled")
        case .homeLater, .homeEarlier:
            guard let homeArrival else { return nil }
            let way = kind == .homeLater ? "later" : "earlier"
            return (name, "Getting home \(way) — now \(time(homeArrival, in: timeZone))")
        case .departure:
            guard let departure = status.nextDepartureTime else { return nil }
            return (name, "Departure changed — now \(time(departure, in: timeZone))")
        case .tripExtended, .tripShortened:
            guard let days = status.tripTotalDays else { return nil }
            let way = kind == .tripExtended ? "extended" : "shortened"
            return (name, "Trip \(way) to \(days) days")
        }
    }

    /// The line for `kind` when the helper can't read the status, or the status no longer fits (spec §6.4).
    static func plainLine(for kind: AlertKind) -> String {
        switch kind {
        case .quickStatus: "sent a quick status"
        case .home: "is home!"
        case .tookOff: "just took off"
        case .delayed: "Flight delayed"
        case .early: "Departing early"
        case .delayCleared: "Delay cleared"
        case .earlyCleared: "Early departure cleared"
        case .newTrip: "Has a new trip"
        case .newTrips: "Has new trips"
        case .tripCancelled: "Trip was cancelled"
        case .tripsCancelled: "Trips were cancelled"
        case .homeLater: "Getting home later"
        case .homeEarlier: "Getting home earlier"
        case .departure: "Departure changed"
        case .tripExtended: "Trip extended"
        case .tripShortened: "Trip shortened"
        }
    }

    /// Whether an alert plays a sound: every one but a Sleeping quick status (decision A4).
    static func playsSound(_ kind: AlertKind, quickStatus: String?) -> Bool {
        !(kind == .quickStatus && quickStatus == "Sleeping")
    }

    /// The words for the quick statuses CrewLu offers. Any other shows as itself.
    private static let quickStatusWords = [
        "Call Me": "is asking you to call",
        "Free to Talk": "is free to talk",
        "Out for Dinner": "went out for dinner",
        "Sleeping": "is sleeping",
    ]

    private static func time(_ date: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
