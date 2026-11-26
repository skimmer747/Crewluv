//
//  FlightTracking.swift
//  CrewLuve
//
//  How the flight between its gates is known now (live or scheduled design §2), as the website's FlightTracking.
//

nonisolated enum FlightTracking: Equatable, Sendable {
    /// Crewlu Cloud saw the plane in the last 3 minutes: at its gate, in the air, landed or down somewhere else.
    case live
    /// Last seen in the air over 3 minutes ago: the faded plane.
    case bestGuess
    /// No live data, never seen, or seen on the ground over 3 minutes ago: the schedule's plane alone.
    case notTracked
    /// No live data yet: Crewlu Cloud hasn't answered since the status screen came up. It reads as `notTracked`, but
    /// the pill, the card's bar and the facts say nothing of where it comes from, so nothing flips from "Not tracked
    /// live" to "Live" in the first second. Hedged words ("Should be flying", "By the schedule", "about") still show:
    /// they're true either way.
    case waiting

    /// Whether the flight is known by the schedule alone: not tracked live, or waiting to hear.
    var isBySchedule: Bool { self == .notTracked || self == .waiting }
}
