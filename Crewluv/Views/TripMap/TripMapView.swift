//
//  TripMapView.swift
//  CrewLuve
//
//  The trip map itself (moving map spec §7.1, §10): Apple's map in an `MKMapView`, with the markers as MapKit
//  annotations and the night and the route lines drawn in our own view just under them, so nothing on the map is
//  swapped as a replay runs. It renders `TripMapDrawing` and decides nothing. North stays up and the map never tilts:
//  `PlaneHeading` aims the plane from coordinates alone, and `MapProjection` is right only for a map seen from
//  straight above.
//

import SwiftUI

struct TripMapView: UIViewRepresentable {
    let tripMap: TripMap
    let date: Date
    let style: TripMapStyle
    @Binding var camera: TripMapCamera
    /// What the facts sheet or panel covers: the camera frames the trip clear of it, and Apple's logo sits beside it.
    var clearance: TripMapClearance = .none
    /// How far down from the map's top edge the full-screen map's own controls reach: its top bar, and the banner and
    /// the key under it. A plane's popup stays below them (which plane design §3), whatever the camera keeps clear.
    var controlsHeight: CGFloat = 0
    /// The full-screen map: it pans and zooms, VoiceOver can explore it, and it keeps clear of the safe area. The
    /// card's map does none of these.
    var isFullScreen = false
    /// `date` is a moment of the replay, not now: a flight with a record shows its real plane alone, where the
    /// record has it (Stage 3 spec §7.3).
    var isReplay = false

    func makeCoordinator() -> TripMapCoordinator {
        TripMapCoordinator(parent: self)
    }

    func makeUIView(context: Context) -> TripMapContainerView {
        let container = TripMapContainerView()
        context.coordinator.attach(to: container)
        return container
    }

    func updateUIView(_ container: TripMapContainerView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.update(colorScheme: context.environment.colorScheme)
    }

    static func dismantleUIView(_ container: TripMapContainerView, coordinator: TripMapCoordinator) {
        coordinator.tearDown()
    }
}
