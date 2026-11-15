//
//  TripMapLine.swift
//  CrewLuve
//
//  One route line as the trip map's own drawing takes it (moving map spec §7.1, §10): places on the flat map, laid
//  out in one piece across the date line. A flight follows its great circle in straight stretches of at most a
//  degree; a drive is drawn straight, as SwiftUI's map drew it.
//

import CoreLocation

nonisolated struct TripMapLine: Equatable {
    /// The most arc between two neighbouring points of a flight's line, in degrees: about 69 miles.
    static let arcStep: Double = 1

    let style: RouteSegment.Style
    /// Each point within half a world of the one before (`MapProjection.unwrapped`).
    let points: [FlatMapPoint]

    init(segment: RouteSegment) {
        let coordinates = segment.isGeodesic ? Self.greatCircle(through: segment.coordinates) : segment.coordinates
        style = segment.style
        points = MapProjection.unwrapped(coordinates.filter(CLLocationCoordinate2DIsValid).map(MapProjection.point(for:)))
    }

    /// The great circle between each pair of neighbouring coordinates, as points at most `arcStep` apart. Every
    /// given coordinate is kept exactly, so a leg split at the plane meets at the plane.
    private static func greatCircle(through coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard let first = coordinates.first else { return [] }
        var points = [first]
        for (start, end) in zip(coordinates, coordinates.dropFirst()) {
            let degrees = GreatCircle.distance(from: start, to: end) / GreatCircle.earthRadius * 180 / .pi
            // A coordinate that isn't a number has no great circle: keep the point and let the projection drop it.
            guard degrees.isFinite else {
                points.append(end)
                continue
            }
            let count = max(2, Int((degrees / arcStep).rounded(.up)) + 1)
            points += GreatCircle.points(from: start, to: end, count: count).dropFirst().dropLast()
            points.append(end)
        }
        return points
    }
}
