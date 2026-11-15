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

    /// `framingRect` as numbers a view can compare, so the card frames the trip again when a real path grows past
    /// what it showed (Stage 3 spec §6.2). Empty when there's nothing to frame.
    func framingKey(focusingOn leg: MapLeg?) -> [Double] {
        guard let rect = framingRect(focusingOn: leg) else { return [] }
        return [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height]
    }
}
