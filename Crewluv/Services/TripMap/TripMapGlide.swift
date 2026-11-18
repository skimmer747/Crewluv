//
//  TripMapGlide.swift
//  CrewLuve
//
//  The glide toward the frame that follows the plane (follow the plane design §4): on every display frame the map
//  closes part of the gap to the frame it wants, its middle and its zoom together, so it tracks the plane smoothly with
//  no steps, and catches up in about a second.
//

import MapKit

nonisolated enum TripMapGlide {

    /// How quickly the gap closes: it shrinks by e (to 37%) every this long, so it's down to 5% in about a second.
    static let timeConstant: TimeInterval = 0.35

    /// Closer than this share of the frame's size, in its middle and its zoom, the glide has arrived.
    static let arrival = 0.001

    /// The frame `elapsed` seconds on from `current`, gliding toward `target`. Its middle and its zoom (the log of its
    /// size) each close the same share of their gaps, 1 − e^(−elapsed ÷ `timeConstant`), so zooming in and out ease
    /// alike, and a frame across the date line glides the short way round. It's `target` once within `arrival`.
    static func step(from current: MKMapRect, toward target: MKMapRect, over elapsed: TimeInterval) -> MKMapRect {
        guard current.size.width > 0, current.size.height > 0, target.size.width > 0, target.size.height > 0 else { return target }
        let share = elapsed > 0 ? 1 - exp(-elapsed / timeConstant) : 0
        let world = MKMapSize.world.width
        var dx = target.midX - current.midX
        if dx > world / 2 { dx -= world } else if dx < -world / 2 { dx += world }
        let dy = target.midY - current.midY
        let widthRatio = target.size.width / current.size.width
        let heightRatio = target.size.height / current.size.height
        let left = 1 - share
        let isThere = abs(dx * left) < arrival * target.size.width && abs(dy * left) < arrival * target.size.height
            && abs(log(widthRatio) * left) < arrival && abs(log(heightRatio) * left) < arrival
        guard !isThere else { return target }
        let width = current.size.width * pow(widthRatio, share)
        let height = current.size.height * pow(heightRatio, share)
        var midX = current.midX + dx * share
        // A frame is kept starting on the map, running on past its right edge if it must, as `MapFit` keeps it.
        if midX - width / 2 < 0 { midX += world } else if midX - width / 2 >= world { midX -= world }
        return MKMapRect(x: midX - width / 2, y: current.midY + dy * share - height / 2, width: width, height: height)
    }

    /// Whether `current` is close enough to `target` to show `target` at once, with no glide.
    static func isThere(_ current: MKMapRect, at target: MKMapRect) -> Bool {
        MKMapRectEqualToRect(step(from: current, toward: target, over: 0), target)
    }
}
