//
//  FlightPlan.swift
//  CrewLuve
//
//  The schedule's flight plan (Stage 3 spec §4): when an on-schedule plane takes off and touches down, and how fast
//  it flies in between. The real plane is measured against it, flown at the plane's own speed once that's known.
//  The constants are written down in CrewluvTests/Fixtures/TripMap/live-cases.json, which the website shares.
//

import Foundation

nonisolated struct FlightPlan: Equatable, Sendable {

    /// The last stretch before touchdown, flown at `descentSpeed`: 120 nautical miles, in meters.
    static let descentDistance: Double = 120 * GreatCircle.metersPerNauticalMile

    /// 280 knots, in meters a second.
    static let descentSpeed: Double = 280 * GreatCircle.metersPerNauticalMile / 3600

    /// How long the descent takes: 25.7 minutes.
    static let descentTime: TimeInterval = descentDistance / descentSpeed

    /// A plane's own speed is believed from 0.7 of the plan's speed to 1.5 of it, which the strongest winds stay
    /// inside. Outside that, the places it was seen can't be right.
    static let ownSpeedShares: ClosedRange<Double> = 0.7...1.5

    /// Leaving the gate and reaching it, both moved by any reported delay.
    let departure: Date
    let arrival: Date
    /// Wheels up and wheels down, as Stage 1's schedule plane has them (`FlightProgress.airborneWindow`).
    let takeoff: Date
    let touchdown: Date
    /// The great-circle distance between the leg's airports, in meters.
    let distance: Double
    /// The speed before the descent, in meters a second: the cruise, or a short leg's one speed. It's the schedule's,
    /// or the plane's own in a plan made by `flown(along:)`.
    let speed: Double
    /// Whether the whole leg is flown at `speed`, with no faster cruise before a descent: a short leg, or a slow one.
    let isSteady: Bool

    /// The plan of a leg between airports `distance` meters apart. Nil when it arrives no later than it leaves.
    init?(departure: Date, arrival: Date, distance: Double) {
        guard let window = FlightProgress.airborneWindow(departure: departure, arrival: arrival) else { return nil }
        self.departure = departure
        self.arrival = arrival
        takeoff = window.start
        touchdown = window.end
        self.distance = distance
        // A leg has a cruise of its own only when it's longer than the descent, in distance and in time.
        let hasRoomToCruise = distance > Self.descentDistance && window.duration > Self.descentTime
        let cruise = hasRoomToCruise ? (distance - Self.descentDistance) / (window.duration - Self.descentTime) : 0
        if cruise > Self.descentSpeed {
            speed = cruise
            isSteady = false
        } else {
            // A leg that goes nowhere has no speed of its own: the descent's stands in.
            let steady = distance / window.duration
            speed = steady > 0 ? steady : Self.descentSpeed
            isSteady = true
        }
    }

    /// `plan` with another speed before its descent.
    private init(_ plan: FlightPlan, speed: Double) {
        departure = plan.departure
        arrival = plan.arrival
        takeoff = plan.takeoff
        touchdown = plan.touchdown
        distance = plan.distance
        self.speed = speed
        isSteady = plan.isSteady
    }

    /// This plan as the plane flies it: with the plane's own speed over its cruise so far in place of the schedule's,
    /// once `path` has one that could be right. The takeoff and the touchdown stay the schedule's, and a leg flown at
    /// one steady speed keeps it. The landing estimate, the estimated plane and the ghost all fly this plan, so the
    /// gap between the two planes is still the label.
    func flown(along path: FlightPath) -> FlightPlan {
        guard !isSteady, let own = path.ownSpeed else { return self }
        let believed = speed * Self.ownSpeedShares.lowerBound...speed * Self.ownSpeedShares.upperBound
        guard believed.contains(own) else { return self }
        return FlightPlan(self, speed: own)
    }

    /// The plan's time in the air.
    var timeInAir: TimeInterval { touchdown.timeIntervalSince(takeoff) }

    /// From the gate to wheels up: Stage 1's allowance, or nothing on a block too short for it.
    var taxiOut: TimeInterval { takeoff.timeIntervalSince(departure) }

    /// From wheels down to the gate.
    var taxiIn: TimeInterval { arrival.timeIntervalSince(touchdown) }

    /// How long a plane flying this plan needs to fly `distance` meters to touchdown. Further than the whole leg, the
    /// extra is flown at `speed`.
    func timeToFly(_ distance: Double) -> TimeInterval {
        let far = max(distance, 0)
        if isSteady { return far / speed }
        if far <= Self.descentDistance { return far / Self.descentSpeed }
        return Self.descentTime + (far - Self.descentDistance) / speed
    }

    /// How far from touchdown a plane flying this plan is, `time` seconds before it: `timeToFly`'s inverse.
    func distanceLeft(_ time: TimeInterval) -> Double {
        let left = max(time, 0)
        if isSteady { return left * speed }
        if left <= Self.descentTime { return left * Self.descentSpeed }
        return Self.descentDistance + (left - Self.descentTime) * speed
    }
}
