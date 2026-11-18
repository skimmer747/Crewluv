//
//  TripMapFollow.swift
//  CrewLuve
//
//  Following the plane (follow the plane design §3): the frame that holds a flight's plane, a short tail behind it and
//  everything left to the destination. The map glides toward it (`TripMapGlide`).
//

import MapKit

nonisolated enum TripMapFollow {

    /// The tail behind the plane: this share of the path's whole length, so it's a steady size all flight.
    static let tailShare = 0.1

    /// The frame is never narrower than this across: about 300 miles, in meters, so the end is a regional view.
    static let leastWidth: Double = 300 * GreatCircle.metersPerMile

    /// How many places along the tail and the way ahead the frame is made from.
    private static let placeCount = 33

    /// The frame that follows `leg`'s plane at `date` (§3): the plane where the map draws it, the tail behind it and
    /// the path ahead to the destination, with `MapFit`'s margins, at least `leastWidth` across. Nil where the whole
    /// flight is framed as before: it isn't a flight between its gates, or its plane hasn't left.
    /// - Parameter isReplay: `date` is a moment of the replay, so the real plane is where its record has it.
    static func rect(for leg: MapLeg, at date: Date, isReplay: Bool) -> MKMapRect? {
        guard leg.kind == .flight, leg.isMoving(at: date) else { return nil }
        let plane = leg.plane(at: date, isReplay: isReplay)
        let path = leg.path
        let distance = min(plane.distance, path.length)
        guard distance > 0, path.length > 0 else { return nil }
        let tailStart = max(0, distance - tailShare * path.length)
        let step = (path.length - tailStart) / Double(placeCount - 1)
        let places = (0..<placeCount).map { path.point(atDistance: tailStart + Double($0) * step) } + [plane.coordinate]
        let leastSide = leastWidth * MKMapPointsPerMeterAtLatitude(plane.coordinate.latitude)
        return MapFit.rect(enclosing: places, minimumSide: leastSide)
    }
}
