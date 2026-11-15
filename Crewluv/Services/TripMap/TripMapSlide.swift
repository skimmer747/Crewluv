//
//  TripMapSlide.swift
//  CrewLuve
//
//  How far the trip map slides to keep the pilot's ground marker in view once it has framed (base waits and card
//  framing design §4.2): the least distance along each axis that brings the marker, with room around it, inside the
//  space the map's margins leave. Rectangles only, so it's tested apart from MapKit.
//

import CoreGraphics

nonisolated enum TripMapSlide {
    /// The room kept around the marker, in points.
    static let room: CGFloat = 8

    /// The frame, room included, of a marker of `size` standing on `point`: its bottom edge on the point, as
    /// `TripMapAnnotationView` places the pilot's marker.
    static func markerFrame(standingOn point: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: point.x - size.width / 2, y: point.y - size.height, width: size.width, height: size.height)
            .insetBy(dx: -room, dy: -room)
    }

    /// How far `frame` moves to lie inside `area`: zero when it already does, else the least distance along each axis
    /// on its own. On an axis where `frame` is larger than `area`, it's centered.
    static func offset(moving frame: CGRect, inside area: CGRect) -> CGVector {
        CGVector(dx: offset(of: frame.minX...frame.maxX, inside: area.minX...area.maxX),
                 dy: offset(of: frame.minY...frame.maxY, inside: area.minY...area.maxY))
    }

    private static func offset(of span: ClosedRange<CGFloat>, inside area: ClosedRange<CGFloat>) -> CGFloat {
        let spanLength = span.upperBound - span.lowerBound
        let areaLength = area.upperBound - area.lowerBound
        if spanLength > areaLength {
            return (area.lowerBound + area.upperBound - span.lowerBound - span.upperBound) / 2
        }
        if span.lowerBound < area.lowerBound { return area.lowerBound - span.lowerBound }
        if span.upperBound > area.upperBound { return area.upperBound - span.upperBound }
        return 0
    }
}
