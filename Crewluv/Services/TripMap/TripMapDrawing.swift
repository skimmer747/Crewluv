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
    /// The airports only drives reach, which give way where they crowd another airport (tidy markers design §2).
    let driveOnlyAirportCodes: Set<String>
    /// The car of a drive under way.
    let cars: [TripMapPoint]
    let plane: PlaneMark?
    /// What the pilot is doing on the ground, and where (activity markers design §2): nil while a leg moves, when the
    /// plane or the car shows them.
    let pilot: TripActivity?

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
                // The car shows only while the pilot drives: a drive that's over or still to come is its line alone.
                if leg.isMoving(at: date) {
                    cars.append(TripMapPoint(id: "\(leg.id)-car", coordinate: leg.position(atFraction: leg.progress(at: date))))
                }
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
        let airports = tripMap.legs.flatMap { [$0.origin, $0.destination] }.filter { seen.insert($0.code).inserted }
        self.airports = airports
        let flightAirportCodes = tripMap.legs.filter { $0.kind == .flight }.flatMap { [$0.origin.code, $0.destination.code] }
        self.driveOnlyAirportCodes = Set(airports.map(\.code)).subtracting(flightAirportCodes)
        self.cars = cars
        self.plane = plane
        self.pilot = tripMap.activity(at: date).flatMap { $0.kind.isMoving ? nil : $0 }
    }
}
