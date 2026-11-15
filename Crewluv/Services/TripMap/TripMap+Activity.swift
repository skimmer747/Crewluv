//
//  TripMap+Activity.swift
//  CrewLuve
//
//  What the pilot is doing at any moment of the trip map (activity markers design §2.2), for the pilot's marker, the
//  timeline's colors and the words under it. The shared cases are in CrewluvTests/Fixtures/TripMap/activity-cases.json.
//

import Foundation

nonisolated extension TripMap {

    /// Every stretch of the span with no leg moving, earliest first, each named by CrewLu's ground legs. A leg with no
    /// length never moves.
    var waits: [TripWait] {
        var waits: [TripWait] = []
        var movingUntil = span.start
        for leg in legs.sorted(by: { $0.start < $1.start }) where leg.end > leg.start {
            if leg.start > movingUntil {
                waits.append(makeWait(from: movingUntil, to: leg.start))
            }
            movingUntil = max(movingUntil, leg.end)
        }
        if span.end > movingUntil {
            waits.append(makeWait(from: movingUntil, to: span.end))
        }
        return waits
    }

    /// What the pilot is doing at `date`, and where. A flight wins over a drive that overlaps it. Nil only for a map
    /// with no legs, which `make` never returns.
    func activity(at date: Date) -> TripActivity? {
        let moving = legs.first { $0.kind == .flight && $0.isMoving(at: date) } ?? legInMotion(at: date)
        if let moving {
            return TripActivity(kind: moving.kind == .flight ? .flying : .driving, place: moving.destination)
        }
        guard let place = pilotLocation(at: date) else { return nil }
        return TripActivity(kind: groundKind(at: date, place: place), place: place)
    }

    // MARK: - On the ground

    /// Before the first departure, home for a next trip, or base while the pilot waits there, else home or base by
    /// where the trip starts. From the last arrival on, home for a recap, else home or base by where it ends. In
    /// between, the wait's kind.
    private func groundKind(at date: Date, place: AirportMark) -> TripActivity.Kind {
        let isHomeAirport = place.code == home?.code
        if date < span.start, mode == .nextTrip { return isWaitingAtBase && !isHomeAirport ? .base : .home }
        if date < span.start { return isHomeAirport ? .home : .base }
        if date >= span.end { return (mode == .recap || isHomeAirport) ? .home : .base }
        // Inside the span with nothing moving, one of the waits holds `date`.
        return waits.first { $0.start <= date && date < $0.end }?.kind ?? .turn
    }

    /// The wait from `start` to `end`, named by the ground stop that overlaps it most, the earlier on a tie; with none,
    /// by where it is, then by its length (base waits design §2).
    private func makeWait(from start: Date, to end: Date) -> TripWait {
        var best: (kind: TripActivity.Kind, overlap: TimeInterval, start: Date)?
        for stop in groundStops {
            let overlap = min(stop.end, end).timeIntervalSince(max(stop.start, start))
            guard overlap > 0 else { continue }
            if let current = best, overlap < current.overlap || (overlap == current.overlap && stop.start >= current.start) {
                continue
            }
            best = (stop.kind, overlap, stop.start)
        }
        let kind = best?.kind ?? unnamedKind(from: start, to: end)
        return TripWait(start: start, end: end, kind: kind)
    }

    /// A wait CrewLu doesn't name: home at the home airport, base at the base airport, else a layover from 8 hours and
    /// a turn under. It's where the pilot's marker stands as it starts.
    private func unnamedKind(from start: Date, to end: Date) -> TripActivity.Kind {
        switch pilotLocation(at: start)?.code {
        case let code? where code == home?.code: .home
        case let code? where code == base?.code: .base
        default: end.timeIntervalSince(start) >= TripWait.shortestLayover ? .layover : .turn
        }
    }
}
