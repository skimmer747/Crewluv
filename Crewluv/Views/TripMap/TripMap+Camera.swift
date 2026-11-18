//
//  TripMap+Camera.swift
//  CrewLuve
//
//  Where the trip map's camera looks (moving map spec §6): one leg, or the whole trip and home.
//

import MapKit

nonisolated extension TripMap {
    /// The flat-map rectangle that frames `leg`, or the whole trip and home when there's none (`MapFit`).
    func framingRect(focusingOn leg: MapLeg?) -> MKMapRect? {
        MapFit.rect(enclosing: framingCoordinates(focusingOn: leg))
    }

    /// The frame at `date`: following the plane when `followsPlane` and `leg` is a flight between its gates whose
    /// plane has left (follow the plane design §3), else `framingRect(focusingOn:)` as before.
    /// - Parameter isReplay: `date` is a moment of the replay.
    func framingRect(focusingOn leg: MapLeg?, at date: Date, followsPlane: Bool, isReplay: Bool) -> MKMapRect? {
        if followsPlane, let leg, let rect = TripMapFollow.rect(for: leg, at: date, isReplay: isReplay) { return rect }
        return framingRect(focusingOn: leg)
    }

    /// The frame the camera glides to at `date` while the family follows the plane (follow the plane design §3, §5): the
    /// flight's plane once it has left, the whole flight while it waits to, the next flight on the ground between two,
    /// and otherwise what the map frames without the setting, the leg in motion or the whole trip. The glide makes
    /// every move with this, so no two animations compete as a leg changes.
    /// - Parameter isReplay: `date` is a moment of the replay.
    func followingFrame(at date: Date, isReplay: Bool) -> MKMapRect? {
        if let flight = flightInMotion(at: date) {
            return TripMapFollow.rect(for: flight, at: date, isReplay: isReplay) ?? framingRect(focusingOn: flight)
        }
        let moving = legInMotion(at: date)
        if moving == nil, legs.contains(where: { $0.kind == .flight && $0.end <= date }), let next = nextFlight(after: date) {
            return framingRect(focusingOn: next)
        }
        return framingRect(focusingOn: moving)
    }

    /// `framingRect` as numbers a view can compare, so the card frames the trip again when a real path grows past
    /// what it showed (Stage 3 spec §6.2). Empty when there's nothing to frame.
    func framingKey(focusingOn leg: MapLeg?) -> [Double] {
        guard let rect = framingRect(focusingOn: leg) else { return [] }
        return [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height]
    }
}
