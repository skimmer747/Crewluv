//
//  TripMapCoordinator.swift
//  CrewLuve
//
//  Runs the trip map's `MKMapView` for `TripMapView` (moving map spec §7.1, §10): the style, the markers as
//  annotations, and each update's drawing. The night and the lines are `TripMapShapesController`'s, and the camera is
//  `TripMapCameraController`'s. In shape it's CrewLu's `FlightMapUIView.Coordinator` without its display link: the
//  screen's and the card's timelines drive every update.
//

import MapKit
import SwiftUI
import UIKit

final class TripMapCoordinator: NSObject, MKMapViewDelegate {
    var parent: TripMapView

    private weak var container: TripMapContainerView?
    private var shapes: TripMapShapesController?
    private var cameraController: TripMapCameraController?
    /// The markers on the map, by `TripMapMarker.placements`' names.
    private var annotations: [String: TripMapAnnotation] = [:]
    private var appliedStyle: TripMapStyle?

    private var mapView: MKMapView? { container?.mapView }

    init(parent: TripMapView) {
        self.parent = parent
        super.init()
    }

    // MARK: - Lifecycle

    /// Sets up a new map. Called once, from `makeUIView`, before the map is on screen: the camera reads the map's own
    /// margins then, before any safe area is in them.
    func attach(to container: TripMapContainerView) {
        self.container = container
        let mapView = container.mapView
        mapView.delegate = self
        mapView.register(TripMapAnnotationView.self, forAnnotationViewWithReuseIdentifier: TripMapAnnotationView.reuseIdentifier)
        mapView.showsCompass = false
        mapView.showsScale = false
        // North stays up and the map never tilts: `PlaneHeading` aims the plane from coordinates alone, and
        // `MapProjection` is right only for a map seen from straight above.
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        shapes = TripMapShapesController(mapView: mapView)
        let cameraController = TripMapCameraController(mapView: mapView)
        cameraController.onUserMoved = { [weak self] in self?.cameraWasMovedByUser() }
        cameraController.onFramedWithoutAnimation = { [weak self] in self?.shapes?.draw() }
        self.cameraController = cameraController
        container.onLayoutChange = { [weak self] in self?.layoutDidChange() }
    }

    /// Lets go of the map. Nothing calls back into this coordinator afterwards.
    func tearDown() {
        container?.onLayoutChange = nil
        mapView?.delegate = nil
        shapes?.tearDown()
        shapes = nil
        cameraController = nil
    }

    // MARK: - Updates

    /// Brings the map up to date with SwiftUI's latest: every tick of the screen's or the card's timeline, and every
    /// change of camera, clearance, style or look.
    func update(colorScheme: ColorScheme) {
        guard let mapView else { return }
        let isFullScreen = parent.isFullScreen
        mapView.isUserInteractionEnabled = isFullScreen
        // On the card, the card is one VoiceOver element: its button's sentence (moving map spec §14).
        mapView.accessibilityElementsHidden = !isFullScreen
        if appliedStyle != parent.style {
            appliedStyle = parent.style
            mapView.preferredConfiguration = parent.style.configuration
        }
        let palette = parent.style.palette(for: colorScheme)
        shapes?.setPalette(palette)
        let drawing = TripMapDrawing(tripMap: parent.tripMap, at: parent.date)
        syncAnnotations(with: TripMapMarker.placements(for: drawing, palette: palette), on: mapView)
        shapes?.setNight(at: parent.date)
        shapes?.setLines(drawing.segments.map(TripMapLine.init(segment:)))
        cameraController?.update(camera: parent.camera, clearance: parent.clearance, respectsSafeArea: isFullScreen)
        shapes?.draw()
    }

    /// The map's size or safe area has changed.
    private func layoutDidChange() {
        cameraController?.layoutDidChange(camera: parent.camera)
        shapes?.draw()
    }

    /// The family moved the map: the recenter button shows, and automatic refits leave it alone.
    private func cameraWasMovedByUser() {
        guard !parent.camera.isPositionedByUser else { return }
        parent.camera.markPositionedByUser()
    }

    /// Adds, moves, changes and removes markers to match `placements`. A marker that stays keeps its annotation, so
    /// MapKit moves its view.
    private func syncAnnotations(with placements: [String: TripMapMarker.Placement], on mapView: MKMapView) {
        let gone = annotations.keys.filter { placements[$0] == nil }
        mapView.removeAnnotations(gone.compactMap { annotations.removeValue(forKey: $0) })
        var added: [TripMapAnnotation] = []
        for (id, placement) in placements {
            guard let annotation = annotations[id] else {
                let annotation = TripMapAnnotation(id: id, coordinate: placement.coordinate, marker: placement.marker)
                annotations[id] = annotation
                added.append(annotation)
                continue
            }
            if annotation.coordinate.latitude != placement.coordinate.latitude
                || annotation.coordinate.longitude != placement.coordinate.longitude {
                annotation.coordinate = placement.coordinate
            }
            if annotation.marker != placement.marker {
                annotation.marker = placement.marker
                (mapView.view(for: annotation) as? TripMapAnnotationView)?.refresh()
            }
        }
        mapView.addAnnotations(added)
    }

    // MARK: - MKMapViewDelegate

    func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
        guard annotation is TripMapAnnotation else { return nil }
        return mapView.dequeueReusableAnnotationView(withIdentifier: TripMapAnnotationView.reuseIdentifier, for: annotation)
    }

    /// Any marker's view shows where MapKit keeps them all. Our drawing goes just under that view.
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        shapes?.noteAnnotationContainer(views.first?.superview)
    }

    /// Called all through a pan, pinch or camera move: our drawing is laid where the map now is.
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        shapes?.draw()
    }

    /// Called once the map has settled after any change in what it shows. When the map itself changes size this is
    /// the call MapKit makes (CrewLu found this), so the drawing is laid again here too.
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        shapes?.draw()
    }
}
