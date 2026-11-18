//
//  LiveWindow.swift
//  CrewLuve
//
//  When a flight's live data is worth asking for (Stage 3 spec §10.2, and CrewLu's partner-api.md): the same
//  window Crewlu Cloud watches it in.
//

import Foundation

nonisolated enum LiveWindow {

    /// It opens this long before the flight leaves the gate.
    static let opensBefore: TimeInterval = 30 * 60

    /// It closes this long after the flight reaches the gate.
    static let closesAfter: TimeInterval = 2 * 3600

    /// Past that, it stays open while the flight is in the air with a fix newer than this.
    static let keepsFor: TimeInterval = 30 * 60

    /// And never longer than this after the flight reaches the gate.
    static let endsAfter: TimeInterval = 12 * 3600

    /// Whether the window of a flight leaving the gate at `departure` and reaching it at `arrival`, both moved by any
    /// reported delay, is open at `now`. `flight` is its live data so far.
    static func isOpen(departure: Date, arrival: Date, flight: LiveFlight?, at now: Date) -> Bool {
        guard now >= departure.addingTimeInterval(-opensBefore), flight?.state != .landed else { return false }
        if now < arrival.addingTimeInterval(closesAfter) { return true }
        guard flight?.state == .airborne, let fix = flight?.fix else { return false }
        return fix.seenAt > now.addingTimeInterval(-keepsFor) && now < arrival.addingTimeInterval(endsAfter)
    }
}
