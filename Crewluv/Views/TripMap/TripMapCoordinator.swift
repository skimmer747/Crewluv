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
    private var popup: TripMapPopupController?
    /// The markers on the map, by `TripMapMarker.placements`' names.
    private var annotations: [String: TripMapAnnotation] = [:]
    private var appliedStyle: TripMapStyle?
    /// The plane whose popup is open (which plane design §3).
    private var openPopup: OpenPopup?

    private struct OpenPopup {
        /// The plane's marker's name in `TripMapMarker.placements`.
        let id: String
        /// The flight it's on. It closes when the next flight's planes take its plane's name.
        let legID: String
        let plane: PlaneKind
        /// Whether the map was replaying when it opened. It closes when a replay starts or stops, since what it says
        /// changes.
        let isReplay: Bool
    }

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
        // A framing or a glide's frame MapKit needn't report: our drawing, and any popup, are laid where the map now is.
        cameraController.onFramedWithoutAnimation = { [weak self] in
            self?.shapes?.draw()
            self?.popup?.reposition()
        }
        self.cameraController = cameraController
        popup = TripMapPopupController(container: container, mapView: mapView)
        container.onLayoutChange = { [weak self] in self?.layoutDidChange() }
    }

    /// Lets go of the map. Nothing calls back into this coordinator afterwards.
    func tearDown() {
        container?.onLayoutChange = nil
        mapView?.delegate = nil
        shapes?.tearDown()
        shapes = nil
        cameraController?.stopFollowing()
        cameraController = nil
        popup?.tearDown()
        popup = nil
    }

    // MARK: - Updates

    /// Brings the map up to date with SwiftUI's latest: every tick of the screen's or the card's timeline, and every
    /// change of camera, clearance, style or look.
    func update(colorScheme: ColorScheme, reduceMotion: Bool) {
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
        let drawing = TripMapDrawing(tripMap: parent.tripMap, at: parent.date, isReplay: parent.isReplay)
        syncAnnotations(with: TripMapMarker.placements(for: drawing, palette: palette), on: mapView)
        shapes?.setNight(at: parent.date)
        shapes?.setLines(drawing.segments.map(TripMapLine.init(segment:)))
        cameraController?.update(camera: parent.camera, clearance: parent.clearance, respectsSafeArea: isFullScreen,
                                 followFrame: parent.followFrame, glides: !reduceMotion)
        shapes?.draw()
        popup?.controlsHeight = parent.controlsHeight
        updatePopup(on: mapView)
    }

    /// The map's size or safe area has changed.
    private func layoutDidChange() {
        cameraController?.layoutDidChange(camera: parent.camera)
        shapes?.draw()
        popup?.reposition()
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

    // MARK: - The planes' popups

    /// Keeps the open popup over its plane with the words of the moment, or closes it once its plane isn't drawn, or a
    /// replay has started or stopped (which plane design §3).
    private func updatePopup(on mapView: MKMapView) {
        guard let open = openPopup else { return }
        guard parent.isFullScreen, open.isReplay == parent.isReplay, let annotation = annotations[open.id],
              let leg = parent.tripMap.flightInMotion(at: parent.date), leg.id == open.legID else {
            closePopup(on: mapView)
            return
        }
        popup?.show(PlanePopupWords(leg: leg, plane: open.plane, at: parent.date, isReplay: parent.isReplay),
                    at: annotation.coordinate)
    }

    private func closePopup(on mapView: MKMapView) {
        openPopup = nil
        popup?.hide()
        for annotation in mapView.selectedAnnotations {
            mapView.deselectAnnotation(annotation, animated: false)
        }
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

    /// Called all through a pan, pinch or camera move: our drawing, and any popup, are laid where the map now is.
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        shapes?.draw()
        popup?.reposition()
    }

    /// A tap on the real plane or its ghost opens its popup, in place of any other (which plane design §3). Only
    /// they can be selected: every other marker's view is disabled.
    func mapView(_ mapView: MKMapView, didSelect annotation: any MKAnnotation) {
        guard let annotation = annotation as? TripMapAnnotation, let plane = annotation.marker.planeKind else { return }
        guard let leg = parent.tripMap.flightInMotion(at: parent.date) else {
            mapView.deselectAnnotation(annotation, animated: false)
            return
        }
        openPopup = OpenPopup(id: annotation.id, legID: leg.id, plane: plane, isReplay: parent.isReplay)
        updatePopup(on: mapView)
    }

    /// A tap anywhere else on the map closes the popup. A tap on the other plane closes this one as it opens that one.
    func mapView(_ mapView: MKMapView, didDeselect annotation: any MKAnnotation) {
        guard let annotation = annotation as? TripMapAnnotation, annotation.id == openPopup?.id else { return }
        openPopup = nil
        popup?.hide()
    }

    /// Called once the map has settled after any change in what it shows. When the map itself changes size this is
    /// the call MapKit makes (CrewLu found this), so the drawing is laid again here too. It's also when an animated
    /// framing has finished, so the pilot's marker slides into view if it needs to.
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        shapes?.draw()
        cameraController?.regionDidChange()
    }
}
