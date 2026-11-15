//
//  MapProjection.swift
//  CrewLuve
//
//  Where places on the flat map are on screen, for the trip map's own drawing of the night and the routes (moving
//  map spec §10). Ported from CrewLu's moving map (Duty/Duty/Views/Map/FlatMapFit.swift) and renamed, because
//  Crewluve's `MapFit` is already the camera's rectangle. The members keep CrewLu's names, so the two files still
//  read side by side. The route lines' half is in `MapProjection+Lines.swift`.
//
//  Pure: no MapKit and no views. `TripMapShapesController` asks the map where three places near the middle of the
//  screen are, and this works out where every other place is from those three. A flat map seen from straight
//  above is only ever slid, scaled and turned, so three places fix all the others. That isn't true of a tilted
//  map, which is why the trip map never tilts.
//

import CoreGraphics
import CoreLocation
import Foundation

nonisolated struct MapProjection: Equatable {
    /// How far from the centre the other two places are asked for, as a share of the width the screen shows.
    static let probeShare: Double = 0.25

    /// The most copies of the world drawn either side of the one the projection was made on.
    static let copiesEachSide = 3

    /// The place the projection was made around.
    let center: FlatMapPoint
    /// Where `center` is on screen.
    private let originX: Double
    private let originY: Double
    /// How far a place moves on screen for one whole world to the east.
    private let eastX: Double
    private let eastY: Double
    /// How far a place moves on screen for one whole world to the south.
    private let southX: Double
    private let southY: Double

    // MARK: - Places

    /// Where a coordinate is on the flat map. A latitude beyond the map's top or bottom edge is held at that edge.
    static func point(for coordinate: CLLocationCoordinate2D) -> FlatMapPoint {
        let latitude = min(max(coordinate.latitude, -NightShade.maxLatitude), NightShade.maxLatitude)
        let y = 0.5 - log(tan(.pi / 4 + latitude * .pi / 360)) / (2 * .pi)
        return FlatMapPoint(x: coordinate.longitude / 360 + 0.5, y: y)
    }

    /// The coordinate of a place on the flat map.
    static func coordinate(for point: FlatMapPoint) -> CLLocationCoordinate2D {
        let latitude = (2 * atan(exp((0.5 - point.y) * 2 * .pi)) - .pi / 2) * 180 / .pi
        return CLLocationCoordinate2D(latitude: latitude, longitude: (point.x - 0.5) * 360)
    }

    /// The two other places to ask the map about: one `step` to the east of `center` and one `step` to the south
    /// of it. Near the map's right or bottom edge the step is taken the other way, so neither place is ever
    /// across the date line from the centre or off the map.
    static func probes(around center: FlatMapPoint, step: Double) -> (east: FlatMapPoint, south: FlatMapPoint) {
        let dx = center.x + step < 1 ? step : -step
        let dy = center.y + step < 1 ? step : -step
        return (FlatMapPoint(x: center.x + dx, y: center.y), FlatMapPoint(x: center.x, y: center.y + dy))
    }

    // MARK: - The projection

    /// The projection for a map that shows `center` at `centerOnScreen` and the two other places where the map
    /// said they are. Nil when the three don't fix a map: a number that isn't a number, or all three on one line,
    /// as when the map has no size yet.
    init?(center: FlatMapPoint, eastProbe: FlatMapPoint, southProbe: FlatMapPoint,
          centerOnScreen: CGPoint, eastOnScreen: CGPoint, southOnScreen: CGPoint) {
        let dx = eastProbe.x - center.x
        let dy = southProbe.y - center.y
        guard dx != 0, dy != 0 else { return nil }
        self.center = center
        originX = Double(centerOnScreen.x)
        originY = Double(centerOnScreen.y)
        eastX = Double(eastOnScreen.x - centerOnScreen.x) / dx
        eastY = Double(eastOnScreen.y - centerOnScreen.y) / dx
        southX = Double(southOnScreen.x - centerOnScreen.x) / dy
        southY = Double(southOnScreen.y - centerOnScreen.y) / dy
        let numbers = [center.x, center.y, originX, originY, eastX, eastY, southX, southY]
        // A whole world smaller than one square point is no map at all, and neither is one too big to measure.
        guard numbers.allSatisfy({ $0.isFinite }), worldArea.isFinite, abs(worldArea) >= 1 else { return nil }
    }

    /// The area one whole world covers on screen, in square points. Negative when the map is mirrored, which a
    /// real map never is.
    private var worldArea: Double { eastX * southY - eastY * southX }

    /// Where a place is on screen, on the copy of the world `copy` worlds to the east of the one the projection was
    /// made on.
    func screenPoint(for point: FlatMapPoint, copy: Int = 0) -> CGPoint {
        let dx = point.x + Double(copy) - center.x
        let dy = point.y - center.y
        return CGPoint(x: originX + dx * eastX + dy * southX, y: originY + dx * eastY + dy * southY)
    }

    /// The place on the flat map that is at a screen point. Its `x` isn't brought back into 0...1: the whole
    /// number part says which copy of the world the point is on.
    func flatPoint(at screenPoint: CGPoint) -> FlatMapPoint {
        let sx = Double(screenPoint.x) - originX
        let sy = Double(screenPoint.y) - originY
        return FlatMapPoint(x: center.x + (sx * southY - sy * southX) / worldArea,
                            y: center.y + (sy * eastX - sx * eastY) / worldArea)
    }

    /// The copies of the world that can show inside `rect`. 0 is the copy the projection was made on, 1 the next
    /// one to the east. `margin` adds that many copies each side, for a route line laid out past the edge of its
    /// own copy. Never more than `copiesEachSide` either side of the centre's copy, margin included.
    func copies(touching rect: CGRect, margin: Int = 0) -> ClosedRange<Int> {
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                       CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)]
        let xs = corners.map { flatPoint(at: $0).x }
        let home = center.x.rounded(.down)
        let limit = Double(Self.copiesEachSide)
        guard let west = xs.min(), let east = xs.max(), west.isFinite, east.isFinite else { return 0...0 }
        let lowest = min(max(west.rounded(.down) - Double(margin), home - limit), home + limit)
        let highest = max(min(east.rounded(.down) + Double(margin), home + limit), lowest)
        return Int(lowest)...Int(highest)
    }

    /// A closed shape on the map as the outlines to fill on screen: one for each copy of the world that shows
    /// inside `rect`, each cut off at `rect`. Copies that don't show give nothing.
    func outlines(of polygon: [FlatMapPoint], in rect: CGRect) -> [[CGPoint]] {
        guard polygon.count >= 3 else { return [] }
        var outlines: [[CGPoint]] = []
        for copy in copies(touching: rect) {
            let outline = Self.clipped(polygon: polygon.map { screenPoint(for: $0, copy: copy) }, to: rect)
            if !outline.isEmpty { outlines.append(outline) }
        }
        return outlines
    }

    // MARK: - Across the date line

    /// Lays a line out in one piece: each point is moved by a whole world, if need be, to be within half a world
    /// of the point before it. So a leg across the date line runs on past the map's edge, and doesn't jump back
    /// across the whole map. Every `x` given must be within 0...1.
    static func unwrapped(_ points: [FlatMapPoint]) -> [FlatMapPoint] {
        var result: [FlatMapPoint] = []
        result.reserveCapacity(points.count)
        var shift = 0.0
        for point in points {
            if let previous = result.last {
                // Two points within 0...1 are never more than one world apart, so one step is always enough.
                let gap = point.x + shift - previous.x
                if gap > 0.5 { shift -= 1 } else if gap < -0.5 { shift += 1 }
            }
            result.append(FlatMapPoint(x: point.x + shift, y: point.y))
        }
        return result
    }

    // MARK: - Cutting a shape off at the edge of the view

    /// The part of a closed shape that lies inside `rect`. Zoomed far in, a shape's corners can be millions of
    /// points off screen; what comes back never leaves `rect`. Where a dented shape is cut into separate parts,
    /// they come back joined by edges that run along the sides of `rect`. Filled, those edges add nothing.
    static func clipped(polygon: [CGPoint], to rect: CGRect) -> [CGPoint] {
        guard polygon.count >= 3 else { return [] }
        var allInside = true
        var allLeft = true, allRight = true, allAbove = true, allBelow = true
        for point in polygon {
            if point.x >= rect.minX { allLeft = false } else { allInside = false }
            if point.x <= rect.maxX { allRight = false } else { allInside = false }
            if point.y >= rect.minY { allAbove = false } else { allInside = false }
            if point.y <= rect.maxY { allBelow = false } else { allInside = false }
        }
        if allInside { return polygon }
        if allLeft || allRight || allAbove || allBelow { return [] }

        // One pass for each side of the rectangle: keep what's on the inner side of it, and add a corner
        // wherever an edge crosses it.
        var points = polygon
        for side in RectSide.allCases {
            guard var previous = points.last else { return [] }
            var previousInside = side.keeps(previous, in: rect)
            var kept: [CGPoint] = []
            kept.reserveCapacity(points.count + 4)
            for point in points {
                let inside = side.keeps(point, in: rect)
                if inside != previousInside { kept.append(side.crossing(from: previous, to: point, in: rect)) }
                if inside { kept.append(point) }
                previous = point
                previousInside = inside
            }
            points = kept
        }
        return points.count >= 3 ? points : []
    }

    private nonisolated enum RectSide: CaseIterable {
        case left, right, top, bottom

        func keeps(_ point: CGPoint, in rect: CGRect) -> Bool {
            switch self {
            case .left: return point.x >= rect.minX
            case .right: return point.x <= rect.maxX
            case .top: return point.y >= rect.minY
            case .bottom: return point.y <= rect.maxY
            }
        }

        /// Where the stretch from `a` to `b` crosses this side. The point is put exactly on the side.
        func crossing(from a: CGPoint, to b: CGPoint, in rect: CGRect) -> CGPoint {
            switch self {
            case .left: return CGPoint(x: rect.minX, y: a.y + (rect.minX - a.x) / (b.x - a.x) * (b.y - a.y))
            case .right: return CGPoint(x: rect.maxX, y: a.y + (rect.maxX - a.x) / (b.x - a.x) * (b.y - a.y))
            case .top: return CGPoint(x: a.x + (rect.minY - a.y) / (b.y - a.y) * (b.x - a.x), y: rect.minY)
            case .bottom: return CGPoint(x: a.x + (rect.maxY - a.y) / (b.y - a.y) * (b.x - a.x), y: rect.maxY)
            }
        }
    }
}
