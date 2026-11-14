//
//  TripMapMarker.swift
//  CrewLuve
//
//  What each of the trip map's markers shows (moving map spec §5.1, §7.2), and which markers a drawing has, by names
//  that stay the same while a marker is on the map, so MapKit moves a marker instead of replacing it.
//

import CoreLocation

nonisolated enum TripMapMarker: Equatable {
    /// An airport's dot, with its code under it.
    case airport(code: String, palette: TripMapPalette)
    /// A drive's car.
    case car
    /// Where the pilot is.
    case heart
    /// The schedule's plane, pointing at `angle` (`PlaneHeading`).
    case plane(angle: Double)

    /// One marker, and where it goes.
    nonisolated struct Placement {
        let coordinate: CLLocationCoordinate2D
        let marker: TripMapMarker
    }

    /// Markers the same size share a key: a marker's view is measured again only when its key changes.
    var sizeKey: String {
        switch self {
        case .airport(let code, _): "airport-\(code)"
        case .car: "car"
        case .heart: "heart"
        case .plane: "plane"
        }
    }

    /// Every marker `drawing` shows, by name: each airport by its code, each car by its drive's own id, and the
    /// heart and the plane by themselves.
    static func placements(for drawing: TripMapDrawing, palette: TripMapPalette) -> [String: Placement] {
        var placements: [String: Placement] = [:]
        for airport in drawing.airports {
            placements["airport-\(airport.code)"] = Placement(coordinate: airport.coordinate,
                                                              marker: .airport(code: airport.code, palette: palette))
        }
        for car in drawing.cars {
            placements[car.id] = Placement(coordinate: car.coordinate, marker: .car)
        }
        if let pin = drawing.pin {
            placements["heart"] = Placement(coordinate: pin.coordinate, marker: .heart)
        }
        if let plane = drawing.plane {
            placements["plane"] = Placement(coordinate: plane.coordinate, marker: .plane(angle: plane.angle))
        }
        return placements
    }
}
