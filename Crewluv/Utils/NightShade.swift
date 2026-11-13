//
//  NightShade.swift
//  CrewLuve
//
//  Where it is night on a flat map, as shapes MapKit can fill (moving map spec §7.1). Ported from CrewLu's moving
//  map (Duty/Duty/Utils/NightShade.swift). Pure: no MapKit and no views. `TripMapView` fills each shape.
//
//  The dark area for a given sun height is everything within a set distance of the point on earth directly
//  opposite the sun. On any one line of longitude that area is a single stretch of latitude, so each shape is
//  built one line of longitude at a time and no edge ever crosses the date line.
//

import Foundation
import CoreLocation

nonisolated enum NightShade {
    /// How far below the horizon the sun is at the edge of each layer, in degrees: sunset through the end of
    /// astronomical twilight. Stacked, the layers make the night's soft edge.
    static let sunDepths: [Double] = [0, 3, 6, 9, 12, 15, 18]

    /// The opacity of one layer. Seven stacked reach 42%.
    static let layerAlpha: Double = 0.075

    /// MapKit's flat map ends at this latitude, north and south.
    static let maxLatitude: Double = 85.05

    /// One layer per entry in `sunDepths` for the sun's position at `date`. Each layer is one or two closed shapes.
    static func layers(at date: Date) -> [[[CLLocationCoordinate2D]]] {
        let sun = SolarPosition.subsolarPoint(at: date)
        return sunDepths.map {
            region(sunDepth: $0, declination: sun.declination, subsolarLongitude: sun.longitude)
        }
    }

    /// The area where the sun is more than `sunDepth` degrees below the horizon, as one or two closed shapes.
    /// `declination` is in radians and `subsolarLongitude` in degrees, as `SolarPosition.subsolarPoint` gives them.
    /// Every longitude is within -180...180 and every latitude within `maxLatitude`. Edges are drawn between points
    /// up to 1 degree of longitude apart, so close to an equinox, when the sunset line runs almost straight north
    /// to south, it can sit up to that far out.
    static func region(sunDepth: Double, declination: Double, subsolarLongitude: Double) -> [[CLLocationCoordinate2D]] {
        // The middle of the dark area is the point opposite the sun.
        let centerLatitude = -declination
        var centerLongitude = subsolarLongitude + 180
        while centerLongitude >= 180 { centerLongitude -= 360 }
        while centerLongitude < -180 { centerLongitude += 360 }
        // The cosine of the dark area's radius. Zero at sunset, when the area is exactly half the earth.
        let reach = sin(sunDepth * .pi / 180)

        func shape(longitudes: [Double], shiftedBy shift: Double) -> [CLLocationCoordinate2D] {
            let stretches = longitudes.map { longitude in
                (longitude: longitude + shift,
                 stretch: darkStretch(centerLatitude: centerLatitude, centerLongitude: centerLongitude, reach: reach, longitude: longitude))
            }
            let northEdge = stretches.map { CLLocationCoordinate2D(latitude: $0.stretch.north, longitude: $0.longitude) }
            let southEdge = stretches.reversed().map { CLLocationCoordinate2D(latitude: $0.stretch.south, longitude: $0.longitude) }
            return northEdge + southEdge
        }

        // The dark area reaches a pole: every line of longitude has a stretch, so the shape spans the whole map.
        if abs(sin(centerLatitude)) >= reach {
            return [shape(longitudes: (0...360).map { -180 + Double($0) }, shiftedBy: 0)]
        }

        // Otherwise it is a rounded blob. Its lines of longitude crowd together towards the two ends, where the
        // edge turns steeply, so the ends stay round.
        let squeeze = (reach * reach - sin(centerLatitude) * sin(centerLatitude)) / (cos(centerLatitude) * cos(centerLatitude))
        let halfWidth = acos(min(1, max(0, squeeze)).squareRoot()) * 180 / .pi
        let longitudes = stride(from: -90.0, through: 90.0, by: 2.0).map {
            centerLongitude + halfWidth * sin($0 * .pi / 180)
        }
        // A blob over the date line is cut there into two shapes, each with an exact edge on the line. A blob is
        // never more than 180 degrees wide, so it can pass the line at one end only: at most one of these runs.
        if let last = longitudes.last, last > 180 {
            return [shape(longitudes: longitudes.filter { $0 < 180 } + [180], shiftedBy: 0),
                    shape(longitudes: [180] + longitudes.filter { $0 > 180 }, shiftedBy: -360)]
        }
        if let first = longitudes.first, first < -180 {
            return [shape(longitudes: longitudes.filter { $0 < -180 } + [-180], shiftedBy: 360),
                    shape(longitudes: [-180] + longitudes.filter { $0 > -180 }, shiftedBy: 0)]
        }
        return [shape(longitudes: longitudes, shiftedBy: 0)]
    }

    /// The dark stretch of one line of longitude, as its south and north ends in degrees. A stretch that lies
    /// wholly beyond the map's edge comes back with both ends on that edge, and the line at the very tip of a blob
    /// comes back as a single point. Either way it adds no area.
    private static func darkStretch(centerLatitude: Double, centerLongitude: Double, reach: Double, longitude: Double) -> (south: Double, north: Double) {
        let a = sin(centerLatitude)
        let b = cos(centerLatitude) * cos((longitude - centerLongitude) * .pi / 180)
        let size = max((a * a + b * b).squareRoot(), 1e-12)
        let middle = atan2(a, b) * 180 / .pi
        let halfHeight = acos(min(1, max(-1, reach / size))) * 180 / .pi
        let south = min(max(middle - halfHeight, -maxLatitude), maxLatitude)
        let north = max(min(middle + halfHeight, maxLatitude), -maxLatitude)
        return (south, north)
    }
}
