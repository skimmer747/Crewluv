//
//  TripMap+Camera.swift
//  CrewLuve
//
//  Where the trip map's camera looks (moving map spec §6): one leg, or the whole trip and home.
//

import MapKit
import SwiftUI

nonisolated extension TripMap {
    /// The flat-map rectangle that frames `leg`, or the whole trip and home when there's none (`MapFit`).
    func framingRect(focusingOn leg: MapLeg?) -> MKMapRect? {
        MapFit.rect(enclosing: framingCoordinates(focusingOn: leg))
    }
}

extension TripMap {
    /// SwiftUI's camera for the same rectangle.
    func camera(focusingOn leg: MapLeg?) -> MapCameraPosition {
        guard let rect = framingRect(focusingOn: leg) else { return .automatic }
        return .rect(rect)
    }
}
