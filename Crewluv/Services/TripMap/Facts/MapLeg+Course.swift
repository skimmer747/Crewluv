//
//  MapLeg+Course.swift
//  CrewLuve
//
//  A leg as the facts follow it (Stage 3 spec §8): along its real path at the times of its record, once the plane
//  has been seen in the air, and otherwise along the great circle on the schedule. The facts ask these, so they
//  needn't know which kind of flight it is. `MapLeg`'s own `progress(at:)` and `position(at:)` stay the schedule's.
//

import CoreLocation

nonisolated extension MapLeg {

    // MARK: - The path

    /// The path the facts follow: the flight's own, real once the plane has been seen in the air, else the great
    /// circle between the airports.
    var path: FlightPath {
        flight?.path ?? FlightPath(from: origin.coordinate, to: destination.coordinate)
    }

    /// The path's whole length in meters, flown and ahead. Without a real path, the great-circle distance.
    var pathLength: Double {
        flight?.path.length ?? distance
    }

    /// Whether Crewlu Cloud has seen this flight: it knows a place it was last seen, or the path it flew.
    var hasLiveData: Bool {
        guard let flight else { return false }
        return flight.live?.fix != nil || flight.path.isReal
    }

    // MARK: - Its times

    /// When the plane was, or is expected to be, `distance` meters along its path: by its record, and without one
    /// by the schedule. Nil for a flight with no time in the air.
    func time(atDistance distance: Double) -> Date? {
        if let record = flight?.record { return record.time(atDistance: distance) }
        let length = pathLength
        return time(atFraction: length > 0 ? distance / length : 0)
    }

    /// When the plane is halfway along its path, flown and ahead: by its record, else the middle of the schedule's
    /// time in the air.
    var halfwayTime: Date? {
        if let record = flight?.record { return record.time(atDistance: record.path.length / 2) }
        return time(atFraction: 0.5)
    }

    /// Whether the plane was seen `distance` meters along its path. Where nobody saw it, on a stretch with no
    /// coverage or past the last place it was seen, what happens there is a best guess, and its time reads
    /// "about" (best guesses design §1). A flight with no real path flies the schedule, which is told as it is.
    func isSeen(atDistance distance: Double) -> Bool {
        guard let path = flight?.path, path.isReal else { return true }
        return path.kind(atDistance: distance) == .seen
    }

    // MARK: - The sky's questions

    /// When the plane is in the air. With a record, from leaving the departure airport to its touchdown, real or
    /// estimated. Otherwise the schedule's time in the air. Nil for a flight that arrives no later than it leaves.
    var airborne: DateInterval? {
        guard let record = flight?.record else { return FlightProgress.airborneWindow(departure: start, arrival: end) }
        let takeoff = record.time(atDistance: 0)
        return record.touchdown > takeoff ? DateInterval(start: takeoff, end: record.touchdown) : nil
    }

    /// Where the plane was, or is expected to be, at `date`: by its record, else by the schedule. Unlike
    /// `plane(at:isReplay:)` it keeps moving between the places the real plane is seen, which the sun's times and
    /// the plane's speed across the sky need.
    func coursePosition(at date: Date) -> CLLocationCoordinate2D {
        flight?.record?.position(at: date) ?? position(at: date)
    }
}

nonisolated extension FlightPath {

    /// The kind of the path `distance` meters along it: the stretch `point(atDistance:)` reads there.
    func kind(atDistance distance: Double) -> Kind {
        let far = min(max(distance, 0), length)
        return stretches.first { far <= $0.startDistance + $0.length }?.kind ?? .planned
    }
}
