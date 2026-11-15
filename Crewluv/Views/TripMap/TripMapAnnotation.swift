//
//  TripMapAnnotation.swift
//  CrewLuve
//
//  One marker on the trip map as MapKit holds it: an airport, a car, the pilot's marker or the plane. Its coordinate is
//  observable, so MapKit moves the marker's view when the coordinator moves it.
//

import MapKit

/// Not isolated to the main actor: `MKAnnotation` isn't, and MapKit reads `coordinate` through Objective-C. Only the
/// coordinator, on the main actor, changes it.
nonisolated final class TripMapAnnotation: NSObject, MKAnnotation {
    /// The marker's name in `TripMapMarker.placements`.
    let id: String
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var marker: TripMapMarker

    init(id: String, coordinate: CLLocationCoordinate2D, marker: TripMapMarker) {
        self.id = id
        self.coordinate = coordinate
        self.marker = marker
    }
}
