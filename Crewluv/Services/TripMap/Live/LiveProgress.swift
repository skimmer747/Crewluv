//
//  LiveProgress.swift
//  CrewLuve
//
//  A flight's real plane at one moment (Stage 3 spec §5, §7.1): whether it's live, when it will land, how far
//  ahead of the schedule or behind it that is, where the real plane and the ghost are, and the leg's real times.
//

import CoreLocation

nonisolated struct LiveProgress: Sendable {

    nonisolated enum Phase: String, Sendable {
        /// No live data, never seen, or last seen on the ground too long ago: the schedule's plane alone.
        case notLive
        /// Seen on the ground at the departure airport.
        case onGround
        /// Seen on the ground at the departure airport again, after flying: an air return (air return design §2).
        case returned
        case inAir
        /// Last seen in the air too long ago: the real plane flies the plan on from there, at the plane's own speed
        /// once that's known.
        case estimated
        case landed
        /// On the ground anywhere else: a diversion.
        case elsewhere
    }

    /// A fix this old or newer is live, by Crewlu Cloud's clock: 3 minutes. Crewlu Cloud asks for one a minute, so
    /// this outlasts a single answer that didn't come.
    static let freshFor: TimeInterval = 180

    /// On the ground this close to the departure airport is at it: 10 nautical miles, in meters.
    static let airportRadius: Double = 10 * GreatCircle.metersPerNauticalMile

    let phase: Phase
    /// When the real plane touches down, or did. Nil where there's no estimate.
    let touchdown: Date?
    /// When it reaches the gate: `touchdown` plus the plan's taxi in.
    let liveArrival: Date?
    /// The plan's touchdown minus `touchdown`, to the nearest minute. Ahead is positive.
    let gapMinutes: Int?
    let label: LiveLabel?
    /// How far along the path the real plane is, in meters. Nil when it isn't shown, or isn't on the path.
    let planeDistance: Double?
    /// Where the real plane is. Nil when it isn't shown.
    let plane: CLLocationCoordinate2D?
    /// How far along the path a plane that lands on schedule would be, flying as this one does. Nil when the ghost
    /// isn't shown.
    let ghostDistance: Double?
    /// The leg's real times (spec §7.1): its start, moved earlier by an early takeoff, and its end, the live arrival
    /// where there is one. Otherwise they're the plan's.
    let start: Date
    let end: Date

    /// - Parameters:
    ///   - plan: the leg's plan, from its scheduled times moved by the reported delay.
    ///   - path: the leg's path, made from `flight`.
    ///   - record: the path's record, when it's a real one.
    ///   - flight: the leg's live data, or nil when Crewlu Cloud answered none.
    ///   - now: the moment, by Crewlu Cloud's clock.
    init(plan: FlightPlan, path: FlightPath, record: FlightRecord?, flight: LiveFlight?, at now: Date) {
        let phase = Self.phase(of: flight, origin: path.origin, at: now)
        // The plane's own speed stands in for the plan's, for the estimate, the estimated plane and the ghost alike.
        let flown = plan.flown(along: path)
        let touchdown = Self.touchdown(in: phase, plan: flown, path: path, record: record, flight: flight, at: now)
        let plane = Self.plane(in: phase, plan: flown, path: path, fix: flight?.fix, touchdown: touchdown, at: now)
        self.phase = phase
        self.touchdown = touchdown
        liveArrival = touchdown?.addingTimeInterval(plan.taxiIn)
        gapMinutes = touchdown.map { Self.gapMinutes(aheadBy: plan.touchdown.timeIntervalSince($0)) }
        label = LiveLabel(phase: phase, gapMinutes: gapMinutes)
        planeDistance = plane.distance
        self.plane = plane.coordinate
        ghostDistance = Self.ghostDistance(in: phase, plan: flown, path: path, at: now)
        let earlyStart = record?.takeoff?.addingTimeInterval(-plan.taxiOut)
        start = earlyStart.map { min($0, plan.departure) } ?? plan.departure
        end = liveArrival ?? plan.arrival
    }

    /// The widest gap there can be, either way: a year of minutes. A time that can't be right is held to it, so it
    /// never overflows.
    private static let widestGap: Double = 365 * 24 * 60

    /// A gap of `seconds` ahead (behind when negative) in whole minutes, halves away from zero.
    static func gapMinutes(aheadBy seconds: TimeInterval) -> Int {
        let minutes = (seconds / 60).rounded(.toNearestOrAwayFromZero)
        guard !minutes.isNaN else { return 0 }
        return Int(min(max(minutes, -widestGap), widestGap))
    }

    // MARK: - Private

    /// When the real plane touches down, or did (spec §5.2). Nil where there's no estimate. `plan` is the plan as the
    /// plane flies it.
    private static func touchdown(
        in phase: Phase, plan: FlightPlan, path: FlightPath, record: FlightRecord?, flight: LiveFlight?, at now: Date
    ) -> Date? {
        switch phase {
        case .inAir, .estimated:
            // The last fix, plus the time for the straight distance left at the plane's own speed.
            return flight?.fix.map {
                $0.seenAt.addingTimeInterval(plan.timeToFly(GreatCircle.distance(from: $0.coordinate, to: path.destination)))
            }
        case .onGround, .returned:
            // Past the plan's takeoff, it's as if the plane, still or again at the departure airport, took off this
            // moment (air return design §3).
            return now >= plan.takeoff ? now.addingTimeInterval(plan.timeInAir) : nil
        case .landed:
            // The record's landing, where there is one, so the two can't disagree.
            return record?.touchdown ?? flight?.landedAt ?? flight?.fix?.seenAt
        case .notLive, .elsewhere:
            return nil
        }
    }

    /// Where the real plane is, and how far along the path. Neither when it isn't shown, and no distance when it
    /// isn't on the path.
    private static func plane(
        in phase: Phase, plan: FlightPlan, path: FlightPath, fix: LiveFlight.Fix?, touchdown: Date?, at now: Date
    ) -> (distance: Double?, coordinate: CLLocationCoordinate2D?) {
        switch phase {
        case .inAir:
            return (path.flownLength, fix?.coordinate)
        case .estimated:
            // It flies on from its last fix as the plan has it, and stays at the arrival airport once it's there
            // (spec §5.5).
            guard let touchdown else { return (nil, nil) }
            let left = plan.distanceLeft(touchdown.timeIntervalSince(now))
            let distance = min(max(path.length - left, path.flownLength), path.length)
            return (distance, path.point(atDistance: distance))
        case .landed:
            return (path.length, path.destination)
        case .onGround, .returned:
            return (0, fix?.coordinate)
        case .elsewhere:
            return (nil, fix?.coordinate)
        case .notLive:
            return (nil, nil)
        }
    }

    /// How far along the path a plane landing on schedule would be, flying `plan` (spec §5.4). Nil when the ghost
    /// isn't shown.
    private static func ghostDistance(in phase: Phase, plan: FlightPlan, path: FlightPath, at now: Date) -> Double? {
        switch phase {
        case .inAir, .estimated, .onGround:
            // Until the plan's takeoff it waits at the departure airport, however long the real path is.
            guard now >= plan.takeoff else { return 0 }
            return max(0, path.length - plan.distanceLeft(plan.touchdown.timeIntervalSince(now)))
        case .landed, .returned, .elsewhere, .notLive:
            // A plane back at its departure airport after an air return has no schedule left to be measured against
            // (air return design §3).
            return nil
        }
    }

    /// What the live data says of a flight from `origin` at `now` (spec §5.1).
    private static func phase(of flight: LiveFlight?, origin: CLLocationCoordinate2D, at now: Date) -> Phase {
        guard let flight, let fix = flight.fix else { return .notLive }
        let isFresh = now.timeIntervalSince(fix.seenAt) <= freshFor
        switch flight.state {
        case .waiting:
            return .notLive
        case .landed:
            return .landed
        case .airborne:
            return isFresh ? .inAir : .estimated
        case .ground:
            guard isFresh else { return .notLive }
            guard GreatCircle.distance(from: fix.coordinate, to: origin) <= airportRadius else { return .elsewhere }
            return flight.isBack(at: origin) ? .returned : .onGround
        }
    }
}
