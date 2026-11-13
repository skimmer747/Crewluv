//
//  TripMap+Camera.swift
//  CrewLuve
//
//  Where the trip map's camera looks (moving map spec §6): one leg, or the whole trip and home.
//

import MapKit
import SwiftUI

extension TripMap {
    func camera(focusingOn leg: MapLeg?) -> MapCameraPosition {
        guard let rect = MapFit.rect(enclosing: framingCoordinates(focusingOn: leg)) else { return .automatic }
        return .rect(rect)
    }
}
