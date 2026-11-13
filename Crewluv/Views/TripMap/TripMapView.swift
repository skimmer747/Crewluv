//
//  TripMapView.swift
//  CrewLuve
//
//  The trip map itself (moving map spec §7.1, §10): SwiftUI's `Map` with night, routes, airports, cars, the heart
//  and the plane. It renders `TripMapDrawing` and decides nothing. North stays up: the map pans and zooms but never
//  rotates or tilts, which is what lets `PlaneHeading` aim the plane from coordinates alone.
//

import MapKit
import SwiftUI

struct TripMapView: View {
    let tripMap: TripMap
    let date: Date
    let style: TripMapStyle
    /// How often the night is redrawn, in trip seconds (`TripMapDrawing.nightDate`).
    var nightStep: TimeInterval = 60
    @Binding var position: MapCameraPosition
    var isInteractive = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let drawing = TripMapDrawing(tripMap: tripMap, at: date)
        let night = NightBand.bands(at: TripMapDrawing.nightDate(for: date, step: nightStep))
        let palette = style.palette(for: colorScheme)
        Map(position: $position, interactionModes: isInteractive ? [.pan, .zoom] : []) {
            ForEach(night) { band in
                MapPolygon(coordinates: band.coordinates)
                    .foregroundStyle(TripMapPalette.night)
            }
            ForEach(drawing.segments) { segment in
                MapPolyline(coordinates: segment.coordinates, contourStyle: segment.isGeodesic ? .geodesic : .straight)
                    .stroke(palette.color(for: segment.style), style: palette.stroke(for: segment.style))
            }
            ForEach(drawing.airports) { airport in
                Annotation(airport.code, coordinate: airport.coordinate) {
                    TripMapMarkers.Airport()
                }
            }
            ForEach(drawing.cars) { car in
                Annotation("", coordinate: car.coordinate) {
                    TripMapMarkers.Car()
                }
                .annotationTitles(.hidden)
            }
            if let pin = drawing.pin {
                Annotation("", coordinate: pin.coordinate, anchor: .bottom) {
                    TripMapMarkers.Heart()
                }
                .annotationTitles(.hidden)
            }
            if let plane = drawing.plane {
                Annotation("", coordinate: plane.coordinate) {
                    PlaneMarker(angle: plane.angle)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(style.mapStyle)
    }
}
