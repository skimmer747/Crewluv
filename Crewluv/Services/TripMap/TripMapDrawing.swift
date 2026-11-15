//
//  TripMapDrawing.swift
//  CrewLuve
//
//  Everything the trip map draws at one instant (moving map spec §7.1, §7.2), worked out here so `TripMapView`
//  only renders it. Each flight's lines and planes are `FlightDrawing`'s.
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
        /// The real path flown, where the plane was seen: solid (Stage 3 spec §6.2).
        case seen
        /// The real path flown, where nobody saw the plane, and the plan's line behind an estimated plane: dotted.
        case unseen
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

/// The real plane and the way it points (Stage 3 spec §5.4).
nonisolated struct RealPlaneMark {
    let coordinate: CLLocationCoordinate2D
    let angle: Double
    /// It hasn't been seen for a while, or the moment is ahead of where it was last seen: it's drawn faded, where
    /// the plan has it.
    let isEstimated: Bool
}

nonisolated struct TripMapDrawing {
    let segments: [RouteSegment]
    let airports: [AirportMark]
    /// The airports only drives reach, which give way where they crowd another airport (tidy markers design §2).
    let driveOnlyAirportCodes: Set<String>
    /// The car of a drive under way.
    let cars: [TripMapPoint]
    /// The schedule's plane, alone: the flight in the air has no real plane at this moment.
    let plane: PlaneMark?
    /// The real plane (Stage 3 spec §5.1).
    let realPlane: RealPlaneMark?
    /// Where an on-schedule plane would be, beside the real one (Stage 3 spec §5.4).
    let ghost: PlaneMark?
    /// What the pilot is doing on the ground, and where (activity markers design §2): nil while a leg moves, when the
    /// plane or the car shows them.
    let pilot: TripActivity?

    /// - Parameter isReplay: `date` is a moment of the replay, not now: a flight with a record shows its real plane
    ///   alone, where the record has it (Stage 3 spec §7.3).
    init(tripMap: TripMap, at date: Date, isReplay: Bool = false) {
        var segments: [RouteSegment] = []
        var cars: [TripMapPoint] = []
        var plane: PlaneMark?
        var realPlane: RealPlaneMark?
        var ghost: PlaneMark?
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
            case .flight:
                let flight = FlightDrawing(leg: leg, at: date, isReplay: isReplay)
                segments += flight.segments
                plane = flight.plane ?? plane
                realPlane = flight.realPlane ?? realPlane
                ghost = flight.ghost ?? ghost
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
        self.realPlane = realPlane
        self.ghost = ghost
        self.pilot = tripMap.activity(at: date).flatMap { $0.kind.isMoving ? nil : $0 }
    }
}
