//
//  LiveLabel.swift
//  CrewLuve
//
//  Whether the real plane is ahead of the schedule or behind it (Stage 3 spec §5.3). `TripMapWording` writes it.
//

import Foundation

nonisolated enum LiveLabel: Equatable, Sendable {
    case onSchedule
    /// `isEstimated` once the plane hasn't been seen for a while: the words gain "About".
    case ahead(minutes: Int, isEstimated: Bool)
    case behind(minutes: Int, isEstimated: Bool)
    /// Past the plan's takeoff and not off the ground. `minutesBehind` is nil for the first few minutes.
    case stillOnGround(minutesBehind: Int?)
    /// Back on the ground at the departure airport after an air return, whatever the gap (air return design §3). Its
    /// words name the airport.
    case returned
    case landedOnTime
    case landedEarly(minutes: Int)
    case landedLate(minutes: Int)

    /// A gap of this many minutes or fewer, either way, is on schedule.
    static let onScheduleWithin = 5

    /// The label for a flight in `phase`, `gapMinutes` ahead of the plan (behind when negative). Nil where there's
    /// no gap to tell, and for a flight that isn't live or is somewhere else.
    init?(phase: LiveProgress.Phase, gapMinutes: Int?) {
        if phase == .returned {
            self = .returned
            return
        }
        guard let gapMinutes else { return nil }
        let size = abs(gapMinutes)
        let isOnSchedule = size <= Self.onScheduleWithin
        switch phase {
        case .inAir, .estimated:
            let isEstimated = phase == .estimated
            if isOnSchedule {
                self = .onSchedule
            } else if gapMinutes > 0 {
                self = .ahead(minutes: size, isEstimated: isEstimated)
            } else {
                self = .behind(minutes: size, isEstimated: isEstimated)
            }
        case .onGround:
            self = .stillOnGround(minutesBehind: isOnSchedule ? nil : size)
        case .landed:
            if isOnSchedule {
                self = .landedOnTime
            } else if gapMinutes > 0 {
                self = .landedEarly(minutes: size)
            } else {
                self = .landedLate(minutes: size)
            }
        case .notLive, .elsewhere, .returned:
            // `.returned` is answered above.
            return nil
        }
    }
}
