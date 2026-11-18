//
//  TripMapMarkerView.swift
//  CrewLuve
//
//  A trip map marker's SwiftUI view, by kind, for `TripMapAnnotationView` to host.
//

import SwiftUI

struct TripMapMarkerView: View {
    let marker: TripMapMarker

    var body: some View {
        switch marker {
        case .airport(let code, let palette, _):
            TripMapMarkers.AirportLabel(code: code, palette: palette)
        case .car:
            TripMapMarkers.Car()
        case .pilot(let kind):
            TripMapMarkers.Pilot(kind: kind)
        case .plane(let angle):
            PlaneMarker(angle: angle)
        case .realPlane(let angle, let isEstimated):
            PlaneMarker(angle: angle, look: .real(isEstimated: isEstimated))
        case .ghost(let angle):
            PlaneMarker(angle: angle, look: .ghost)
        }
    }
}
