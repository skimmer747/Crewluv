//
//  FlightPath+Drawing.swift
//  CrewLuve
//
//  A flight's path as the trip map draws and frames it (Stage 3 spec §6.2): the places it passes, any part of it
//  between two distances, and the way a plane on it points.
//

import CoreLocation

nonisolated extension FlightPath {

    /// A part of the path that's all one kind, as the places it passes.
    nonisolated struct Run {
        let kind: Kind
        let coordinates: [CLLocationCoordinate2D]
    }

    /// Every place the path passes, from the departure airport to the arrival airport.
    var coordinates: [CLLocationCoordinate2D] {
        stretches.map(\.start) + [destination]
    }

    /// The path between `start` and `end` meters along it, cut wherever its kind changes. Each run begins where the
    /// one before it ended. Empty when `end` isn't past `start`.
    func runs(from start: Double, to end: Double) -> [Run] {
        let from = min(max(start, 0), length)
        let to = min(max(end, 0), length)
        guard to > from else { return [] }
        var runs: [(kind: Kind, coordinates: [CLLocationCoordinate2D])] = []
        for stretch in stretches {
            let stretchEnd = stretch.startDistance + stretch.length
            guard stretchEnd > from, stretch.startDistance < to else { continue }
            let first = stretch.startDistance >= from ? stretch.start : point(atDistance: from)
            let last = stretchEnd <= to ? stretch.end : point(atDistance: to)
            if runs.last?.kind == stretch.kind {
                // Added in place: a real path has hundreds of places, and a replay asks 60 times a second.
                runs[runs.count - 1].coordinates.append(last)
            } else {
                runs.append((stretch.kind, [first, last]))
            }
        }
        return runs.map { Run(kind: $0.kind, coordinates: $0.coordinates) }
    }

    /// The places the path passes between `start` and `end` meters along it, both ends included. Empty when `end`
    /// isn't past `start`.
    func coordinates(from start: Double, to end: Double) -> [CLLocationCoordinate2D] {
        let runs = runs(from: start, to: end)
        guard let first = runs.first else { return [] }
        return runs.dropFirst().reduce(into: first.coordinates) { $0 += $1.coordinates.dropFirst() }
    }

    /// Places all along the path for the camera to frame (spec §6.2): 33 along a great circle, as before, and every
    /// place a real path passes.
    var framingCoordinates: [CLLocationCoordinate2D] {
        guard length > 0 else { return [origin, destination] }
        return stretches.reduce(into: [origin]) { places, stretch in
            let count = max(Int((stretch.length / length * 32).rounded(.up)), 1) + 1
            places += GreatCircle.points(from: stretch.start, to: stretch.end, count: count).dropFirst()
        }
    }

    /// The angle a plane `distance` meters along the path points at, on a map with north up (`PlaneHeading`): along
    /// the path just ahead of it, or along the last of the path at its end. Nil for a path with no length, and where
    /// the two places it's aimed between are one.
    func heading(atDistance distance: Double) -> Double? {
        let look = PlaneHeading.lookAhead * length
        guard look > 0 else { return nil }
        let from = min(min(max(distance, 0), length), length - look)
        return PlaneHeading.flatMapAngle(from: point(atDistance: from), to: point(atDistance: from + look))
    }
}
