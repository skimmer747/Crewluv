//
//  MapFlight.swift
//  CrewLuve
//
//  A flight leg as the trip map measures and draws it (Stage 3 spec §11): the schedule's plan, the path, and once
//  the plane has been seen in the air, its record. The three are made together from one answer of Crewlu Cloud's,
//  so they always agree.
//

import CoreLocation

nonisolated struct MapFlight: Sendable {
    /// The schedule's plan, from the leg's scheduled times moved by its reported delay and by nothing else.
    let plan: FlightPlan
    /// The real path once the plane has been seen in the air, else the great circle between the airports.
    let path: FlightPath
    /// Where the plane was at any moment. Nil without a real path.
    let record: FlightRecord?
    /// The flight's live data, or nil when Crewlu Cloud answered none for its leg.
    let live: LiveFlight?
    /// Crewlu Cloud's clock minus this device's, as of the answer `live` came in.
    let clockOffset: TimeInterval

    /// Nil for a leg that arrives no later than it leaves.
    /// - Parameters:
    ///   - departure: leaving the gate, moved by any reported delay.
    ///   - arrival: reaching the gate, moved by any reported delay.
    init?(
        departure: Date, arrival: Date, from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D,
        live: LiveFlight? = nil, clockOffset: TimeInterval = 0
    ) {
        let distance = GreatCircle.distance(from: origin, to: destination)
        guard let plan = FlightPlan(departure: departure, arrival: arrival, distance: distance) else { return nil }
        let path = FlightPath(from: origin, to: destination, flight: live)
        self.plan = plan
        self.path = path
        record = FlightRecord(path: path, plan: plan)
        self.live = live
        self.clockOffset = clockOffset
    }

    /// The real plane when this device's clock says `now`. A fix's age is measured by Crewlu Cloud's clock, so a
    /// wrong phone clock doesn't age it.
    func progress(at now: Date) -> LiveProgress {
        LiveProgress(plan: plan, path: path, record: record, flight: live, at: now.addingTimeInterval(clockOffset))
    }

    /// Whether `arrival`, the leg's gate arrival as it's shown, is the real plane's estimate, which the words mark
    /// with "about" (spec §9): it isn't the plan's, and the plane hasn't landed.
    func isEstimate(_ arrival: Date) -> Bool {
        live?.state != .landed && abs(arrival.timeIntervalSince(plan.arrival)) >= 1
    }

    /// Where the real plane is on the ground at its departure airport, when this device's clock says `now` (live or
    /// scheduled design §3): at its gate before the plan's takeoff, `atGate`; still there after it, `stillAtGate`; or
    /// back there after an air return, `returned`. Nil anywhere else, and when it isn't live.
    func seenAtDeparture(at now: Date) -> AtDeparture? {
        let progress = self.progress(at: now)
        switch progress.phase {
        case .returned:
            return .returned
        case .onGround:
            if case .stillOnGround = progress.label { return .stillAtGate }
            return .atGate
        case .notLive, .inAir, .estimated, .landed, .elsewhere:
            return nil
        }
    }

    /// Whether the real plane is back on the ground at its departure airport after flying, when this device's clock
    /// says `now` (air return design §2): the words say "Returned to Rockford" in place of "Still on the ground".
    func hasReturned(at now: Date) -> Bool {
        progress(at: now).phase == .returned
    }

    /// Whether Crewlu Cloud's answer says nothing of the plane now, when this device's clock says `now`: never seen,
    /// or seen on the ground over 3 minutes ago (Stage 3 spec §5.1's `notLive`). The flight is then known by the
    /// schedule alone (live or scheduled design §2).
    func isNotLive(at now: Date) -> Bool {
        progress(at: now).phase == .notLive
    }

    /// Whether the real plane is down at its arrival airport, by Crewlu Cloud's state, when this device's clock says
    /// `now` (spec §5.1's `landed`). Until the gate, the facts and the status say "Landed in Anchorage" (landed before
    /// the gate design §2). A plane last seen on the ground away from it landed somewhere else, which nothing names.
    func hasLanded(at now: Date) -> Bool {
        guard progress(at: now).phase == .landed else { return false }
        guard let fix = live?.fix, fix.isOnGround else { return true }
        return GreatCircle.distance(from: fix.coordinate, to: path.destination) <= LiveProgress.airportRadius
    }
}
