//
//  LiveFlight+Return.swift
//  CrewLuve
//
//  An air return (air return design §2, §4): a plane back on the ground at its departure airport after flying, and
//  the trail of its latest try, which its path is made from.
//

import CoreLocation

nonisolated extension LiveFlight {

    /// A trail whose highest point is this much above its lowest has flown: 1,000 ft. Heights are from sea level, and
    /// a plane taxiing at Denver reads 5,400 ft, so it's a climb, not a height.
    static let returnClimbFeet: Double = 1000

    /// A point near the departure airport this long after the one before it, which was near it too, starts the trail
    /// again: 10 minutes. Points come every 2 minutes in the air, so a hold near the airport never leaves this gap.
    static let restartGap: TimeInterval = 10 * 60

    /// The trail oldest first, with two points of one time in the order they came.
    var sortedTrail: [TrailPoint] {
        trail.enumerated()
            .sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }
            .map(\.element)
    }

    /// Whether the plane is back on the ground at its departure airport, at `origin`, after flying: on the ground by
    /// Crewlu Cloud's state, its fix within `LiveProgress.airportRadius` of the airport, and its whole trail climbed
    /// `returnClimbFeet`. How old the fix is isn't asked: `LiveProgress` asks that.
    func isBack(at origin: CLLocationCoordinate2D) -> Bool {
        guard state == .ground, let fix else { return false }
        return GreatCircle.distance(from: fix.coordinate, to: origin) <= LiveProgress.airportRadius && Self.hasClimbed(trail)
    }

    /// The trail of the flight's latest try, oldest first. A try starts again at a place seen in the air within
    /// `FlightPath.firstPointRadius` of `origin` more than `restartGap` after the point before it, which was within
    /// `LiveProgress.airportRadius`, once the try before had climbed `returnClimbFeet`. The fix in the air, when it's
    /// newer than the trail, can start one too, with no trail points yet. None while the plane is back on the ground
    /// there.
    func latestTry(from origin: CLLocationCoordinate2D) -> [TrailPoint] {
        guard !isBack(at: origin) else { return [] }
        let points = sortedTrail
        var places = points.map { (time: $0.time, coordinate: $0.coordinate) }
        if let fix, !fix.isOnGround, fix.seenAt > points.last?.time ?? .distantPast {
            places.append((fix.seenAt, fix.coordinate))
        }
        func distance(_ coordinate: CLLocationCoordinate2D) -> Double { GreatCircle.distance(from: coordinate, to: origin) }
        var start = 0
        for index in places.indices.dropFirst() {
            let earlier = places[index - 1], later = places[index]
            if later.time.timeIntervalSince(earlier.time) > Self.restartGap,
               distance(earlier.coordinate) <= LiveProgress.airportRadius,
               distance(later.coordinate) <= FlightPath.firstPointRadius,
               Self.hasClimbed(points[start..<index]) {
                start = index
            }
        }
        return Array(points[start...])
    }

    /// Whether the highest of `points` is `returnClimbFeet` or more above the lowest. Points with no height don't
    /// count.
    private static func hasClimbed(_ points: some Collection<TrailPoint>) -> Bool {
        let feet = points.compactMap(\.altitudeFeet)
        guard let highest = feet.max(), let lowest = feet.min() else { return false }
        return highest - lowest >= returnClimbFeet
    }
}
