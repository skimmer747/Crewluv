//
//  TripMapDrawing.swift
//  CrewLuve
//
//  Everything the trip map draws at one instant (moving map spec §7.1, §7.2), worked out here so `TripMapView`
//  only renders it.
//

import CoreLocation

/// One line on the map.
nonisolated struct RouteSegment: Identifiable {
    nonisolated enum Style: Equatable {
        /// Still to fly: dashed.
        case upcoming
        /// Flown so far on the leg in the air: solid.
        case flying
        /// A leg already flown: grey.
        case flown
        /// A drive: dotted.
        case drive
    }

    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let style: Style

    /// Flights follow the great circle. Drives are short enough to draw straight.
    var isGeodesic: Bool { style != .drive }
}

/// A place with an identity, for a marker.
nonisolated struct TripMapPoint: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
}

/// The schedule's plane and the way it points (`PlaneHeading`'s angle).
nonisolated struct PlaneMark {
    let coordinate: CLLocationCoordinate2D
    let angle: Double
}

nonisolated struct TripMapDrawing {
    let segments: [RouteSegment]
    let airports: [AirportMark]
    let cars: [TripMapPoint]
    let plane: PlaneMark?
    /// The heart: where the pilot is when nothing is moving.
    let pin: AirportMark?

    init(tripMap: TripMap, at date: Date) {
        var segments: [RouteSegment] = []
        var cars: [TripMapPoint] = []
        var plane: PlaneMark?
        for leg in tripMap.legs {
            let origin = leg.origin.coordinate
            let destination = leg.destination.coordinate
            switch leg.kind {
            case .drive:
                segments.append(RouteSegment(id: "\(leg.id)-drive", coordinates: [origin, destination], style: .drive))
                let fraction = leg.isMoving(at: date) ? leg.progress(at: date) : 0.5
                cars.append(TripMapPoint(id: "\(leg.id)-car", coordinate: leg.position(atFraction: fraction)))
            case .flight where date >= leg.end:
                segments.append(RouteSegment(id: "\(leg.id)-flown", coordinates: [origin, destination], style: .flown))
            case .flight where leg.isMoving(at: date):
                let fraction = leg.progress(at: date)
                let here = leg.position(atFraction: fraction)
                if fraction > 0 {
                    segments.append(RouteSegment(id: "\(leg.id)-flying", coordinates: [origin, here], style: .flying))
                }
                if fraction < 1 {
                    segments.append(RouteSegment(id: "\(leg.id)-upcoming", coordinates: [here, destination], style: .upcoming))
                }
                plane = PlaneMark(coordinate: here, angle: leg.heading(at: date) ?? 0)
            case .flight:
                segments.append(RouteSegment(id: "\(leg.id)-upcoming", coordinates: [origin, destination], style: .upcoming))
            }
        }
        var seen = Set<String>()
        self.segments = segments
        self.airports = tripMap.legs.flatMap { [$0.origin, $0.destination] }.filter { seen.insert($0.code).inserted }
        self.cars = cars
        self.plane = plane
        self.pin = tripMap.pilotLocation(at: date)
    }

    /// `date` held back to a whole number of `step` seconds, so the night is redrawn only once it has moved enough
    /// to see (moving map spec §10): every minute live, about ten times a second in replay.
    static func nightDate(for date: Date, step: TimeInterval) -> Date {
        guard step > 0 else { return date }
        return Date(timeIntervalSince1970: (date.timeIntervalSince1970 / step).rounded(.down) * step)
    }
}
