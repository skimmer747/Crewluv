//
//  GreatCircle.swift
//  CrewLuve
//
//  The shortest path between two places, for the trip map's routes and planes (moving map spec §7.1).
//

import CoreLocation

/// The earth as a sphere: distances along it, and places part way along the shortest path between two others.
nonisolated enum GreatCircle {

    /// The earth's mean radius, in meters.
    static let earthRadius: Double = 6_371_008.8

    /// One statute mile, in meters. Families think in miles (moving map spec §8.3).
    static let metersPerMile: Double = 1_609.344

    /// The distance between two places along the earth's surface, in meters.
    static func distance(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        earthRadius * centralAngle(from: start, to: end)
    }

    /// The place `fraction` of the way from `start` to `end`. A fraction outside 0...1 is held at the nearer end.
    /// Two places on exactly opposite sides of the earth have no single shortest path; no leg is ever that long.
    static func point(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, fraction: Double) -> CLLocationCoordinate2D {
        let share = min(max(fraction, 0), 1)
        let angle = centralAngle(from: start, to: end)
        guard angle > 1e-9 else { return start }
        let weightOfStart = sin((1 - share) * angle) / sin(angle)
        let weightOfEnd = sin(share * angle) / sin(angle)
        let a = vector(start)
        let b = vector(end)
        let x = weightOfStart * a.x + weightOfEnd * b.x
        let y = weightOfStart * a.y + weightOfEnd * b.y
        let z = weightOfStart * a.z + weightOfEnd * b.z
        return CLLocationCoordinate2D(latitude: degrees(atan2(z, (x * x + y * y).squareRoot())),
                                      longitude: degrees(atan2(y, x)))
    }

    /// `count` evenly spaced places from `start` to `end`, both ends included. Never fewer than two.
    static func points(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, count: Int) -> [CLLocationCoordinate2D] {
        let total = max(count, 2)
        return (0..<total).map { point(from: start, to: end, fraction: Double($0) / Double(total - 1)) }
    }

    // MARK: - Private

    /// The angle between two places seen from the earth's centre, in radians. The haversine form stays exact for
    /// short hops, where the cosine form loses digits.
    private static func centralAngle(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let startLatitude = radians(start.latitude)
        let endLatitude = radians(end.latitude)
        let latitudeChange = endLatitude - startLatitude
        let longitudeChange = radians(end.longitude - start.longitude)
        let haversine = sin(latitudeChange / 2) * sin(latitudeChange / 2)
            + cos(startLatitude) * cos(endLatitude) * sin(longitudeChange / 2) * sin(longitudeChange / 2)
        return 2 * asin(min(1, haversine.squareRoot()))
    }

    private static func vector(_ coordinate: CLLocationCoordinate2D) -> (x: Double, y: Double, z: Double) {
        let latitude = radians(coordinate.latitude)
        let longitude = radians(coordinate.longitude)
        return (cos(latitude) * cos(longitude), cos(latitude) * sin(longitude), sin(latitude))
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}
