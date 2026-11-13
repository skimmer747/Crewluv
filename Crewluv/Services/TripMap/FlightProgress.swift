//
//  FlightProgress.swift
//  CrewLuve
//
//  Where the schedule says a flight is (moving map spec §7.3). Stage 3 adds the live plane beside it.
//  The constants are written down in CrewluvTests/Fixtures/TripMap/progress-cases.json, which the website shares.
//

import Foundation

nonisolated enum FlightProgress {

    /// The schedule's plane waits this long at the gate before it takes off.
    static let taxiOutAllowance: TimeInterval = 15 * 60

    /// It lands this long before the scheduled gate arrival.
    static let taxiInAllowance: TimeInterval = 7 * 60

    /// A block shorter than both allowances plus this is flown from gate to gate, with no allowances.
    static let shortestCruise: TimeInterval = 10 * 60

    /// When the schedule's plane is in the air, for a flight that leaves the gate at `departure` and reaches it at
    /// `arrival` (both already moved by any delay). Nil when it arrives no later than it leaves.
    static func airborneWindow(departure: Date, arrival: Date) -> DateInterval? {
        let block = arrival.timeIntervalSince(departure)
        guard block > 0 else { return nil }
        guard block >= taxiOutAllowance + taxiInAllowance + shortestCruise else {
            return DateInterval(start: departure, end: arrival)
        }
        return DateInterval(start: departure.addingTimeInterval(taxiOutAllowance),
                            end: arrival.addingTimeInterval(-taxiInAllowance))
    }

    /// How far along its route the schedule's plane is at `date`: 0 at the departure airport, 1 at the arrival
    /// airport, at a steady speed while it's in the air.
    static func scheduledFraction(departure: Date, arrival: Date, at date: Date) -> Double {
        guard let window = airborneWindow(departure: departure, arrival: arrival) else {
            return date >= arrival ? 1 : 0
        }
        let share = date.timeIntervalSince(window.start) / window.duration
        return min(max(share, 0), 1)
    }
}
