//
//  PlanePopupPlacement.swift
//  CrewLuve
//
//  Where a plane's popup goes on the full-screen map (which plane design §3): just above the plane's mark, or under it
//  where there's no room above, and slid sideways to stay inside the part of the map that's clear. Rectangles only, so
//  it's tested apart from MapKit.
//

import CoreGraphics

nonisolated enum PlanePopupPlacement {
    /// The gap between a plane's centre and its popup: the plane's radius, and a little more.
    static let gap: CGFloat = 18

    /// The popup's frame, `size` large, for a plane at `plane`, inside `area`: the map less its margins, which keep
    /// clear of the top bar, the banner and the key, and the facts sheet or panel.
    static func frame(of size: CGSize, over plane: CGPoint, inside area: CGRect) -> CGRect {
        let above = plane.y - gap - size.height
        let y = above >= area.minY ? above : plane.y + gap
        // A popup wider than the area is centred on it. Otherwise it's centred on the plane, slid in from either side.
        let x = size.width > area.width
            ? area.midX - size.width / 2
            : min(max(plane.x - size.width / 2, area.minX), area.maxX - size.width)
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}
