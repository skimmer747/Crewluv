//
//  MapLeg+Takeoff.swift
//  CrewLuve
//
//  When a flight left the ground (time labels design §3.3), for its takeoff row and the weather it took off in.
//

import Foundation

/// A flight's takeoff: when, and whether that's the real plane's or the schedule's.
nonisolated struct Takeoff: Equatable, Sendable {
    let time: Date
    /// The real plane was seen leaving. Otherwise the time is the schedule's, a guess the words mark "about".
    let isSeen: Bool
}

nonisolated extension MapLeg {
    /// The real plane's takeoff where it was first seen close enough to its departure airport to tell, else the
    /// schedule's, after its taxi allowance. Nil for a real plane first seen too far out: for a late flight the
    /// schedule's time could be an hour off.
    var takeoff: Takeoff? {
        if let record = flight?.record {
            return record.takeoff.map { Takeoff(time: $0, isSeen: true) }
        }
        let schedules = flight?.plan.takeoff ?? FlightProgress.airborneWindow(departure: start, arrival: end)?.start
        return schedules.map { Takeoff(time: $0, isSeen: false) }
    }
}
