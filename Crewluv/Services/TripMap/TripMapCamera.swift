//
//  TripMapCamera.swift
//  CrewLuve
//
//  What the trip map's camera should frame, and whether the family has moved it since (moving map spec §6). The map
//  frames each new request once. A pan, pinch or double tap makes the camera the family's: the recenter button shows,
//  and automatic refits leave it alone until they ask. While it follows the plane, it eases in on it in gentle steps
//  (follow the plane design §4).
//

import MapKit

nonisolated struct TripMapCamera {
    /// The flat-map rectangle to frame (`MapFit`), or nil to leave the camera where it is.
    private(set) var rect: MKMapRect?
    /// Whether moving to `rect` animates. A map's first framing never does.
    private(set) var isAnimated = false
    /// True once the family has panned or zoomed since the camera was last framed.
    private(set) var isPositionedByUser = false
    /// Goes up with every framing, so asking for the same rectangle again still moves the map.
    private(set) var framingNumber = 0
    /// Where the pilot's ground marker stands as the map frames, slid into view if the framing leaves it out (base
    /// waits and card framing design §4.2). Nil in flight, or with no marker to keep.
    private(set) var keptInView: CLLocationCoordinate2D?
    /// When the camera last moved to follow the plane. Nil until it has.
    private(set) var followedAt: Date?

    init(framing rect: MKMapRect?, keeping keptInView: CLLocationCoordinate2D? = nil) {
        self.rect = rect
        self.keptInView = keptInView
    }

    /// Frames `rect` afresh, taking the camera back from the family, and keeps `keptInView` in view.
    mutating func frame(_ rect: MKMapRect?, keeping keptInView: CLLocationCoordinate2D? = nil, animated: Bool) {
        self.rect = rect
        self.keptInView = keptInView
        isAnimated = animated
        isPositionedByUser = false
        framingNumber += 1
    }

    /// Whether a follow step could move the camera at `now`: the family hasn't moved it, and `TripMapFollow.mayMove`
    /// says a move could be due. A view asks this on every tick, and makes the frame only when it's true.
    /// - Parameter places: the plane and the destination, which the frame on screen must hold.
    func mayFollow(keeping places: [CLLocationCoordinate2D], at now: Date) -> Bool {
        !isPositionedByUser && TripMapFollow.mayMove(from: rect, keeping: places, lastMove: followedAt, now: now)
    }

    /// Follows the plane: frames `wanted` when `TripMapFollow.shouldMove` says it's time, and leaves a camera the
    /// family moved alone (follow the plane design §4). Returns whether it moved, so a view writes its camera back
    /// only then.
    /// - Parameters:
    ///   - places: the plane and the destination, which the frame on screen must hold.
    ///   - now: the real time, by which the steps are spaced, whether the map is live or a replay.
    @discardableResult
    mutating func follow(_ wanted: MKMapRect, keeping places: [CLLocationCoordinate2D], at now: Date, animated: Bool) -> Bool {
        guard !isPositionedByUser,
              TripMapFollow.shouldMove(from: rect, to: wanted, keeping: places, lastMove: followedAt, now: now) else { return false }
        frame(wanted, animated: animated)
        followedAt = now
        return true
    }

    /// The family moved the map.
    mutating func markPositionedByUser() {
        isPositionedByUser = true
    }
}
