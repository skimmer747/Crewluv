//
//  TripMapCamera.swift
//  CrewLuve
//
//  What the trip map's camera should frame, and whether the family has moved it since (moving map spec §6). The map
//  frames each new request once. A pan, pinch or double tap makes the camera the family's: the recenter button shows,
//  and automatic refits leave it alone until they ask.
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

    init(framing rect: MKMapRect?) {
        self.rect = rect
    }

    /// Frames `rect` afresh, taking the camera back from the family.
    mutating func frame(_ rect: MKMapRect?, animated: Bool) {
        self.rect = rect
        isAnimated = animated
        isPositionedByUser = false
        framingNumber += 1
    }

    /// The family moved the map.
    mutating func markPositionedByUser() {
        isPositionedByUser = true
    }
}
