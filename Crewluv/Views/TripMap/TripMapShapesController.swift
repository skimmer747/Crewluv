//
//  TripMapShapesController.swift
//  CrewLuve
//
//  Keeps the trip map's own drawing (`TripMapShapesView`) just under MapKit's markers and laid where the map is now
//  (moving map spec §10). Ported from CrewLu's `FlightMapUIView.Coordinator` (`drawShapes`, `currentFit` and
//  `placeShapesView`), without the sun button and the fade between legs, which Crewluve's map doesn't have.
//

import CoreGraphics
import Foundation
import MapKit
import SwiftUI
import UIKit

final class TripMapShapesController {
    private let shapesView = TripMapShapesView(nightLayerCount: NightShade.sunDepths.count,
                                               nightFill: UIColor(TripMapPalette.night))
    private weak var mapView: MKMapView?
    /// The view MapKit keeps the markers' views in. Our drawing sits just under it.
    private weak var annotationContainer: UIView?
    private var hasLoggedFallback = false
    /// The night's shapes on the flat map, one entry for each of `NightShade.sunDepths`, and the moment they're for.
    private var nightShapes: [[[FlatMapPoint]]] = []
    private var nightDate: Date?
    private var lines: [TripMapLine] = []
    /// The projection the layers were last laid with, and whether the night and the lines have been laid since they
    /// last changed. A draw that would change none of these leaves the layers alone.
    private var drawnProjection: MapProjection?
    private var isNightDrawn = false
    private var areLinesDrawn = false

    init(mapView: MKMapView) {
        self.mapView = mapView
        shapesView.onNeedsRedraw = { [weak self] in self?.redrawEverything() }
    }

    func tearDown() {
        shapesView.onNeedsRedraw = nil
        shapesView.removeFromSuperview()
    }

    // MARK: - What to draw

    func setPalette(_ palette: TripMapPalette) {
        shapesView.setPalette(palette)
    }

    /// The night for `date`, worked out again only when the time has moved.
    func setNight(at date: Date) {
        guard date != nightDate else { return }
        nightShapes = NightShade.layers(at: date).map { layer in
            layer.map { shape in shape.map(MapProjection.point(for:)) }
        }
        nightDate = date
        isNightDrawn = false
    }

    func setLines(_ newLines: [TripMapLine]) {
        guard newLines != lines else { return }
        lines = newLines
        areLinesDrawn = false
    }

    /// MapKit has shown a marker's view. The view holding it is where every marker is kept.
    func noteAnnotationContainer(_ container: UIView?) {
        guard let container else { return }
        annotationContainer = container
        draw()
    }

    // MARK: - Drawing

    /// Draws the night and the lines where the map shows them now. Called on every update, all through a pan, pinch
    /// or camera move, when the map settles, and when the map or our view changes size. The layers are laid again
    /// only when the map, the night or the lines have changed since the last draw.
    func draw() {
        guard let mapView else { return }
        placeShapesView(in: mapView)
        guard shapesView.superview != nil, let projection = currentProjection(in: mapView) else { return }
        let mapMoved = projection != drawnProjection
        drawnProjection = projection
        if mapMoved || !isNightDrawn {
            shapesView.drawNight(nightShapes, projection: projection)
            isNightDrawn = true
        }
        if mapMoved || !areLinesDrawn {
            shapesView.drawLines(lines, projection: projection)
            areLinesDrawn = true
        }
    }

    /// Our view has changed size: everything is laid again.
    private func redrawEverything() {
        drawnProjection = nil
        draw()
    }

    /// Asks the map where three places are on screen: the middle of what it shows, a place a short way east of that,
    /// and a place a short way south of it. Where everything else is follows from those three (`MapProjection`). Nil
    /// while the map has no size.
    private func currentProjection(in mapView: MKMapView) -> MapProjection? {
        guard shapesView.bounds.width > 0, shapesView.bounds.height > 0 else { return nil }
        // How much of one world's width the map is showing.
        let shown = mapView.visibleMapRect.size.width / MKMapSize.world.width
        guard shown.isFinite, shown > 0 else { return nil }
        let center = MapProjection.point(for: mapView.centerCoordinate)
        let probes = MapProjection.probes(around: center, step: min(shown, 1) * MapProjection.probeShare)
        func onScreen(_ point: FlatMapPoint) -> CGPoint {
            mapView.convert(MapProjection.coordinate(for: point), toPointTo: shapesView)
        }
        return MapProjection(center: center, eastProbe: probes.east, southProbe: probes.south,
                             centerOnScreen: onScreen(center), eastOnScreen: onScreen(probes.east),
                             southOnScreen: onScreen(probes.south))
    }

    /// Keeps our drawing just under the view the map holds its markers' views in, so the markers stay above the
    /// night. That view is reached through a marker view's own parent, so no private name is used. Until the map has
    /// made a marker's view there's nothing to go under, and our drawing goes just above the map's own content.
    private func placeShapesView(in mapView: MKMapView) {
        // The map's own content view doesn't resize what's put in it. So on every draw, whatever holds our view, our
        // view is given its size.
        defer {
            if let holder = shapesView.superview, shapesView.frame != holder.bounds {
                shapesView.frame = holder.bounds
                drawnProjection = nil
            }
        }
        if let container = annotationContainer, !container.isDescendant(of: mapView) {
            // The map has thrown that view away. Look again.
            annotationContainer = nil
        }
        if annotationContainer == nil {
            // Only our own markers: MapKit may keep its other annotations, such as the user's location, elsewhere.
            annotationContainer = mapView.annotations.lazy
                .filter { $0 is TripMapAnnotation }
                .compactMap { mapView.view(for: $0)?.superview }
                .first
        }
        if let container = annotationContainer {
            if container !== mapView, let host = container.superview {
                let siblings = host.subviews
                let ours = siblings.firstIndex(of: shapesView)
                if ours == nil || ours.map({ $0 + 1 }) != siblings.firstIndex(of: container) {
                    host.insertSubview(shapesView, belowSubview: container)
                    drawnProjection = nil
                }
                return
            }
            // The markers aren't kept the way this was written for. The night would dim them.
            if !hasLoggedFallback {
                hasLoggedFallback = true
                debugLog("Trip map: no view to put the night under. It's drawn over the markers.")
            }
        }
        if !shapesView.isDescendant(of: mapView) {
            mapView.insertSubview(shapesView, at: min(1, mapView.subviews.count))
            drawnProjection = nil
        }
    }
}
