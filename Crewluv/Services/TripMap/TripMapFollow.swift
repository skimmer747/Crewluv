//
//  TripMapFollow.swift
//  CrewLuve
//
//  Following the plane (follow the plane design §3, §4): the frame that holds a flight's plane, a tail behind it and
//  everything left to the destination, and when the camera moves to it, in gentle steps in and at once out.
//

import MapKit

nonisolated enum TripMapFollow {

    /// The tail behind the plane: this share of the path's whole length, so it's a steady size all flight.
    static let tailShare = 0.2

    /// The frame is never narrower than this across: about 300 miles, in meters, so the end is a regional view.
    static let leastWidth: Double = 300 * GreatCircle.metersPerMile

    /// The camera eases in once the frame it wants is this share of the one it shows, or less, across.
    static let stepShare = 0.85

    /// And no sooner than this after its last move: 5 seconds.
    static let stepInterval: TimeInterval = 5

    /// How many places along the tail and the way ahead the frame is made from.
    private static let placeCount = 33

    /// The frame that follows `leg`'s plane at `date` (§3): the plane where the map draws it, the tail behind it and
    /// the path ahead, with `MapFit`'s margins, at least `leastWidth` across. Nil where the whole flight is framed as
    /// before: it isn't a flight between its gates, or its plane hasn't left.
    /// - Parameter isReplay: `date` is a moment of the replay, so the real plane is where its record has it.
    static func rect(for leg: MapLeg, at date: Date, isReplay: Bool) -> MKMapRect? {
        guard leg.kind == .flight, leg.isMoving(at: date) else { return nil }
        return rect(for: leg, plane: leg.plane(at: date, isReplay: isReplay))
    }

    /// `rect(for:at:isReplay:)` for `leg`'s plane at `plane`, already placed, for a leg between its gates.
    static func rect(for leg: MapLeg, plane: PlanePosition) -> MKMapRect? {
        let path = leg.path
        let distance = min(plane.distance, path.length)
        guard distance > 0, path.length > 0 else { return nil }
        let tailStart = max(0, distance - tailShare * path.length)
        let step = (path.length - tailStart) / Double(placeCount - 1)
        let places = (0..<placeCount).map { path.point(atDistance: tailStart + Double($0) * step) } + [plane.coordinate]
        let leastSide = leastWidth * MKMapPointsPerMeterAtLatitude(plane.coordinate.latitude)
        return MapFit.rect(enclosing: places, minimumSide: leastSide)
    }

    /// The places the frame on screen must always hold while it follows `leg` at `date` (§4): its plane, where the
    /// map draws it, and its destination.
    static func places(for leg: MapLeg, at date: Date, isReplay: Bool) -> [CLLocationCoordinate2D] {
        [leg.plane(at: date, isReplay: isReplay).coordinate, leg.destination.coordinate]
    }

    /// Whether a camera showing `shown`, last moved at `lastMove`, may move at `now` at all: one of `places` is outside
    /// `shown`, or `stepInterval` has gone by. Cheap, so the frame is made only when a move could be due.
    static func mayMove(from shown: MKMapRect?, keeping places: [CLLocationCoordinate2D], lastMove: Date?, now: Date) -> Bool {
        guard let shown, shown.size.width > 0, shown.size.height > 0 else { return true }
        if places.contains(where: { !contains(shown, MKMapPoint($0)) }) { return true }
        return lastMove.map { now.timeIntervalSince($0) >= stepInterval } ?? true
    }

    /// Whether a camera showing `shown`, last moved at `lastMove`, moves to `wanted` at `now` (§4): at once when one of
    /// `places` (the plane and the destination) is outside `shown`; otherwise only when `wanted` is `stepShare` of
    /// `shown` across or less, and `stepInterval` or more has gone by since the last move.
    ///
    /// `shown` is the frame the camera last asked for. MapKit shows it grown to the map's shape, so a place inside it
    /// is on screen, except on a flight wider than MapKit will zoom out to, as the whole flight's frame can be today.
    static func shouldMove(from shown: MKMapRect?, to wanted: MKMapRect, keeping places: [CLLocationCoordinate2D],
                           lastMove: Date?, now: Date) -> Bool {
        guard let shown, shown.size.width > 0, shown.size.height > 0 else { return true }
        if places.contains(where: { !contains(shown, MKMapPoint($0)) }) { return true }
        if let lastMove, now.timeIntervalSince(lastMove) < stepInterval { return false }
        return max(wanted.size.width / shown.size.width, wanted.size.height / shown.size.height) <= stepShare
    }

    /// Whether `rect` holds `point`, on the map or a world east, since a rectangle across the date line runs on past
    /// the map's right edge (`MapFit`).
    private static func contains(_ rect: MKMapRect, _ point: MKMapPoint) -> Bool {
        let world = MKMapSize.world.width
        let isAcross = [point.x, point.x + world].contains { rect.minX <= $0 && $0 <= rect.maxX }
        return isAcross && rect.minY <= point.y && point.y <= rect.maxY
    }
}
