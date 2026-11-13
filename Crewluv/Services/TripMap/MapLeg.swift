//
//  MapLeg.swift
//  CrewLuve
//
//  One drawable leg of the trip map: a flight or a drive between two known airports, at its delay-shifted times
//  (moving map spec §7.1, §7.3).
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

    /// The great-circle distance between the two airports, in meters.
    var distance: Double { GreatCircle.distance(from: origin.coordinate, to: destination.coordinate) }

    /// True from leaving the gate until reaching the other one.
    func isMoving(at date: Date) -> Bool { start <= date && date < end }

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
