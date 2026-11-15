//
//  FlightPath.swift
//  CrewLuve
//
//  The path a flight is drawn and measured along (Stage 3 spec §6.1). With no live data it's the great circle
//  between the airports, as before. With a trail it's the real path: the departure airport, each place the plane
//  was seen, and the great circle from the last of them to the arrival airport.
//

import CoreLocation

nonisolated struct FlightPath: Sendable {

    nonisolated enum Kind: String, Sendable {
        /// Flown, between two places the plane was seen close enough together.
        case seen
        /// Flown, and nobody saw it: the straight join is a guess.
        case unseen
        /// The great circle the schedule flies: a flight with no trail, or the way ahead of a real plane.
        case planned
    }

    /// One join of the path, a great circle between two places.
    nonisolated struct Stretch: Sendable {
        let start: CLLocationCoordinate2D
        let end: CLLocationCoordinate2D
        let kind: Kind
        /// How far along the path it starts, in meters.
        let startDistance: Double
        let length: Double
    }

    /// A place the plane was seen: when, and how far along the path.
    nonisolated struct Knot: Equatable, Sendable {
        let time: Date
        let distance: Double
    }

    /// Two neighbouring places seen further apart in time than this have an unseen join between them.
    static let unseenGap: TimeInterval = 10 * 60

    /// A first place further than this from the departure airport is joined to it unseen, and doesn't tell the
    /// takeoff's time: 30 nautical miles, in meters.
    static let firstPointRadius: Double = 30 * GreatCircle.metersPerNauticalMile

    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    /// Never empty, from the departure airport to the arrival airport.
    let stretches: [Stretch]
    /// Each place the plane was seen in the air, oldest first, and then its landing, when it has landed. Empty for a
    /// flight never seen in the air.
    let knots: [Knot]
    /// The whole path, flown and ahead, in meters.
    let length: Double
    /// How far along the path the plane was last seen: where the way ahead begins. The whole path once it has landed.
    let flownLength: Double
    /// Whether the path ends with a landing: the flight has landed, and was seen in the air before it. A landed
    /// flight never seen in the air has the great circle, and this is false: `LiveProgress.phase` says it landed.
    let hasLanded: Bool

    /// Whether it's a real path, from places the plane was seen.
    var isReal: Bool { !knots.isEmpty }

    /// The path of a flight from `origin` to `destination`: the real one when `flight` has been seen in the air.
    init(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, flight: LiveFlight? = nil) {
        self.origin = origin
        self.destination = destination
        let seen = Self.sightings(of: flight)
        guard let first = seen.first, let last = seen.last else {
            let length = GreatCircle.distance(from: origin, to: destination)
            stretches = [Stretch(start: origin, end: destination, kind: .planned, startDistance: 0, length: length)]
            knots = []
            self.length = length
            flownLength = 0
            hasLanded = false
            return
        }
        var stretches: [Stretch] = []
        var knots: [Knot] = []
        var distance = 0.0
        func add(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, _ kind: Kind) {
            let length = GreatCircle.distance(from: start, to: end)
            stretches.append(Stretch(start: start, end: end, kind: kind, startDistance: distance, length: length))
            distance += length
        }
        let isFirstFar = GreatCircle.distance(from: origin, to: first.coordinate) > Self.firstPointRadius
        add(from: origin, to: first.coordinate, isFirstFar ? .unseen : .seen)
        knots.append(Knot(time: first.time, distance: distance))
        for (earlier, later) in zip(seen, seen.dropFirst()) {
            let isGap = later.time.timeIntervalSince(earlier.time) > Self.unseenGap
            add(from: earlier.coordinate, to: later.coordinate, isGap ? .unseen : .seen)
            knots.append(Knot(time: later.time, distance: distance))
        }
        let lastSeenDistance = distance
        if flight?.state == .landed {
            let landedAt = max(flight?.landedAt ?? flight?.fix?.seenAt ?? last.time, last.time)
            let isGap = landedAt.timeIntervalSince(last.time) > Self.unseenGap
            add(from: last.coordinate, to: destination, isGap ? .unseen : .seen)
            knots.append(Knot(time: landedAt, distance: distance))
            hasLanded = true
            flownLength = distance
        } else {
            add(from: last.coordinate, to: destination, .planned)
            hasLanded = false
            flownLength = lastSeenDistance
        }
        self.stretches = stretches
        self.knots = knots
        length = distance
    }

    /// A place the plane was seen in the air, and when.
    private typealias Sighting = (coordinate: CLLocationCoordinate2D, time: Date)

    /// Each place `flight` was seen in the air, oldest first: its trail's points, with two of one time in the order
    /// they came, and then its fix, when that's in the air and newer than the last of them.
    private static func sightings(of flight: LiveFlight?) -> [Sighting] {
        var seen: [Sighting] = (flight?.trail ?? []).enumerated()
            .sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }
            .map { ($0.element.coordinate, $0.element.time) }
        if let fix = flight?.fix, !fix.isOnGround, fix.seenAt > seen.last?.time ?? .distantPast {
            seen.append((fix.coordinate, fix.seenAt))
        }
        return seen
    }

    /// The place `distance` meters along the path. Before its start that's the departure airport, and past its end
    /// the arrival airport.
    func point(atDistance distance: Double) -> CLLocationCoordinate2D {
        let far = min(max(distance, 0), length)
        guard let stretch = stretches.first(where: { far <= $0.startDistance + $0.length }) else { return destination }
        guard stretch.length > 0 else { return stretch.start }
        return GreatCircle.point(from: stretch.start, to: stretch.end, fraction: (far - stretch.startDistance) / stretch.length)
    }
}
