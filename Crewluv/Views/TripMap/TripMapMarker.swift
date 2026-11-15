//
//  TripMapMarker.swift
//  CrewLuve
//
//  What each of the trip map's markers shows (moving map spec §5.1, §7.2; activity markers design §2), and which
//  markers a drawing has, by names that stay the same while a marker is on the map, so MapKit moves a marker instead of
//  replacing it.
//

import CoreLocation

nonisolated enum TripMapMarker: Equatable {
    /// An airport's dot, with its code under it. One only drives reach gives way where it crowds another airport (tidy
    /// markers design §2).
    case airport(code: String, palette: TripMapPalette, isDriveOnly: Bool)
    /// The car of a drive under way.
    case car
    /// Where the pilot is on the ground, showing what they're doing there: a layover, a turn, base or home.
    case pilot(TripActivity.Kind)
    /// The schedule's plane, alone, pointing at `angle` (`PlaneHeading`).
    case plane(angle: Double)
    /// The real plane (Stage 3 spec §5.4), faded while it's an estimate of where the plane is.
    case realPlane(angle: Double, isEstimated: Bool)
    /// Where an on-schedule plane would be, beside the real one.
    case ghost(angle: Double)

    /// One marker, and where it goes.
    nonisolated struct Placement {
        let coordinate: CLLocationCoordinate2D
        let marker: TripMapMarker
    }

    /// Markers the same size share a key: a marker's view is measured again only when its key changes. Every kind of
    /// the pilot's marker is the same size.
    var sizeKey: String {
        switch self {
        case .airport(let code, _, _): "airport-\(code)"
        case .car: "car"
        case .pilot: "pilot"
        case .plane, .realPlane, .ghost: "plane"
        }
    }

    /// Every marker `drawing` shows, by name: each airport by its code, each car by its drive's own id, and the
    /// pilot's marker and each of the planes by themselves. The pilot's marker keeps its name as its kind changes.
    static func placements(for drawing: TripMapDrawing, palette: TripMapPalette) -> [String: Placement] {
        var placements: [String: Placement] = [:]
        for airport in drawing.airports {
            let marker = TripMapMarker.airport(code: airport.code, palette: palette,
                                               isDriveOnly: drawing.driveOnlyAirportCodes.contains(airport.code))
            placements["airport-\(airport.code)"] = Placement(coordinate: airport.coordinate, marker: marker)
        }
        for car in drawing.cars {
            placements[car.id] = Placement(coordinate: car.coordinate, marker: .car)
        }
        if let pilot = drawing.pilot {
            placements["pilot"] = Placement(coordinate: pilot.place.coordinate, marker: .pilot(pilot.kind))
        }
        if let plane = drawing.plane {
            placements["plane"] = Placement(coordinate: plane.coordinate, marker: .plane(angle: plane.angle))
        }
        if let ghost = drawing.ghost {
            placements["ghost"] = Placement(coordinate: ghost.coordinate, marker: .ghost(angle: ghost.angle))
        }
        if let realPlane = drawing.realPlane {
            placements["real-plane"] = Placement(coordinate: realPlane.coordinate,
                                                 marker: .realPlane(angle: realPlane.angle, isEstimated: realPlane.isEstimated))
        }
        return placements
    }
}
