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

    /// Whether the real plane is still on the ground at its departure airport after the plan's takeoff time, when
    /// this device's clock says `now`: seen there lately, not yet in the air (spec §5.1's `onGround`), and late
    /// leaving, as its bar says "Still on the ground". Before the plan's takeoff it's taxiing as the schedule has it,
    /// and nothing says so (which plane design §4).
    func isAtDeparture(at now: Date) -> Bool {
        let progress = self.progress(at: now)
        guard progress.phase == .onGround, case .stillOnGround = progress.label else { return false }
        return true
    }
}
