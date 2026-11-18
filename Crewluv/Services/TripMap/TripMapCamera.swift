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
    /// Where the pilot's ground marker stands as the map frames, slid into view if the framing leaves it out (base
    /// waits and card framing design §4.2). Nil in flight, or with no marker to keep.
    private(set) var keptInView: CLLocationCoordinate2D?

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

    /// The family moved the map.
    mutating func markPositionedByUser() {
        isPositionedByUser = true
    }
}
