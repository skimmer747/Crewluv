//
//  MapFit.swift
//  CrewLuve
//
//  The flat-map rectangle the trip map's camera shows (moving map spec §6, §12). A trip across the date line is
//  laid out in one piece, so Anchorage to Tokyo frames the North Pacific, not the whole world.
//

import MapKit

nonisolated enum MapFit {

    /// The smallest rectangle on the flat map that holds every coordinate, taken the short way round the world.
    /// It's grown by `padding` (a share of its width and height, on each side) and made at least `minimumSide`
    /// map points on each side. Nil for no coordinates.
    static func rect(enclosing coordinates: [CLLocationCoordinate2D], padding: Double = 0.2, minimumSide: Double = 400_000) -> MKMapRect? {
        let points = coordinates.map(MKMapPoint.init)
        let xs = points.map(\.x).sorted()
        guard let westmost = xs.first, let eastmost = xs.last,
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else { return nil }
        let world = MKMapSize.world.width

        // The widest empty stretch of longitude is left out of the rectangle. When it's the stretch across the date
        // line, the rectangle sits inside one copy of the world; otherwise it runs on past the map's right edge,
        // which MapKit shows as one piece.
        var gapAfter = xs.count - 1
        var widestGap = world - eastmost + westmost
        for index in 0..<(xs.count - 1) where xs[index + 1] - xs[index] > widestGap {
            widestGap = xs[index + 1] - xs[index]
            gapAfter = index
        }
        let minX = gapAfter == xs.count - 1 ? westmost : xs[gapAfter + 1]
        let maxX = gapAfter == xs.count - 1 ? eastmost : xs[gapAfter] + world

        let width = max((maxX - minX) * (1 + 2 * padding), minimumSide)
        let height = max((maxY - minY) * (1 + 2 * padding), minimumSide)
        var originX = (minX + maxX) / 2 - width / 2
        // MapKit runs a rectangle on past the right edge, not the left, so one that starts left of the date line
        // is moved a whole world east.
        if originX < 0 { originX += world }
        return MKMapRect(x: originX, y: (minY + maxY) / 2 - height / 2, width: width, height: height)
    }
}
