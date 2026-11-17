//
//  MapLeg.swift
//  CrewLuve
//
//  One drawable leg of the trip map: a flight or a drive between two known airports, at its delay-shifted times
//  (moving map spec §7.1, §7.3). A flight carries its plan, its path and its record (Stage 3 spec §11), and a
//  flight with a real plane has the real plane's times (Stage 3 spec §7.1).
//

import CoreLocation

nonisolated struct MapLeg: Identifiable {
    nonisolated enum Kind { case flight, drive }

    let id: String
    let kind: Kind
    let origin: AirportMark
    let destination: AirportMark
    /// Leaving the gate (or the driveway), moved by any delay.
    let start: Date
    /// Reaching the gate, moved by any delay.
    let end: Date
    let flightNumber: String?
    /// A flight's plan, its path and, once it's been seen in the air, its record. Nil for a drive, and for a flight
    /// that arrives no later than it leaves.
    let flight: MapFlight?

    init(
        id: String, kind: Kind, origin: AirportMark, destination: AirportMark, start: Date, end: Date,
        flightNumber: String?, flight: MapFlight? = nil
    ) {
        self.id = id
        self.kind = kind
        self.origin = origin
        self.destination = destination
        self.start = start
        self.end = end
        self.flightNumber = flightNumber
        self.flight = flight
    }

    /// Whether `end` is the real plane's estimate, which the words mark with "about" (Stage 3 spec §9).
    var isArrivalEstimated: Bool { flight?.isEstimate(end) ?? false }

    /// The great-circle distance between the two airports, in meters.
    var distance: Double { GreatCircle.distance(from: origin.coordinate, to: destination.coordinate) }

    /// True from leaving the gate until reaching the other one.
    func isMoving(at date: Date) -> Bool { start <= date && date < end }

    /// Whether the flight is between its gates at `date` while its real plane is still on the ground at its departure
    /// airport after the plan's takeoff time (`MapFlight.isAtDeparture`, which plane design §4).
    func isStillOnGround(at date: Date) -> Bool {
        isMoving(at: date) && (flight?.isAtDeparture(at: date) ?? false)
    }

    /// How far along the leg the schedule has the pilot at `date`, 0...1. A flight uses the taxi allowances;
    /// a drive moves steadily.
    func progress(at date: Date) -> Double {
        switch kind {
        case .flight:
            return FlightProgress.scheduledFraction(departure: start, arrival: end, at: date)
        case .drive:
            let duration = end.timeIntervalSince(start)
            guard duration > 0 else { return date >= end ? 1 : 0 }
            return min(max(date.timeIntervalSince(start) / duration, 0), 1)
        }
    }

    /// When the schedule has the pilot `fraction` of the way along: in the air for a flight, steadily for a drive.
    func time(atFraction fraction: Double) -> Date? {
        switch kind {
        case .flight:
            return FlightProgress.scheduledTime(atFraction: fraction, departure: start, arrival: end)
        case .drive:
            return start.addingTimeInterval(min(max(fraction, 0), 1) * end.timeIntervalSince(start))
        }
    }

    func position(at date: Date) -> CLLocationCoordinate2D {
        position(atFraction: progress(at: date))
    }

    func position(atFraction fraction: Double) -> CLLocationCoordinate2D {
        GreatCircle.point(from: origin.coordinate, to: destination.coordinate, fraction: fraction)
    }

    /// The angle the plane points at `date` on a north-up map (`PlaneHeading`). Nil for a leg that starts and
    /// ends at the same place.
    func heading(at date: Date) -> Double? {
        let aim = PlaneHeading.aimFractions(at: progress(at: date))
        return PlaneHeading.flatMapAngle(from: position(atFraction: aim.from), to: position(atFraction: aim.to))
    }
}
