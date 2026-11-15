//
//  FlightRecord.swift
//  CrewLuve
//
//  Where a flight with a real path was at any moment, and when it was any distance along it (Stage 3 spec §7.2).
//  The replay, the facts' times and the estimated plane all read it.
//

import CoreLocation

nonisolated struct FlightRecord: Sendable {
    let path: FlightPath
    let plan: FlightPlan
    /// When it left the ground: the time of the first place it was seen, when that's close enough to the departure
    /// airport to tell (spec §7.1).
    let takeoff: Date?
    /// When it touched down, or is estimated to: the last place it was seen, plus the plan's time for the rest.
    let touchdown: Date

    /// Nil for a path with no place the plane was seen: such a flight has no record.
    init?(path: FlightPath, plan: FlightPlan) {
        guard let first = path.knots.first, let last = path.knots.last else { return nil }
        self.path = path
        self.plan = plan
        takeoff = first.distance <= FlightPath.firstPointRadius ? first.time : nil
        touchdown = path.hasLanded ? last.time : last.time.addingTimeInterval(plan.timeToFly(path.length - last.distance))
    }

    /// How far along its path the plane was at `date`, in meters.
    /// - Before the first place it was seen, it flies there from the departure airport at the plan's speed, and
    ///   waits at the airport before that.
    /// - Among the places it was seen, it's between the two either side of `date`, in proportion to the time.
    /// - After the last, it flies the plan to the arrival airport, and stays there. A flight that landed is there.
    func distance(at date: Date) -> Double {
        let knots = path.knots
        guard let first = knots.first, let last = knots.last else { return 0 }
        if date <= first.time {
            return max(0, first.distance - first.time.timeIntervalSince(date) * plan.speed)
        }
        if date >= last.time {
            guard !path.hasLanded else { return path.length }
            let estimated = path.length - plan.distanceLeft(touchdown.timeIntervalSince(date))
            return min(max(estimated, last.distance), path.length)
        }
        for (earlier, later) in zip(knots, knots.dropFirst()) where date < later.time {
            let share = date.timeIntervalSince(earlier.time) / later.time.timeIntervalSince(earlier.time)
            return earlier.distance + (later.distance - earlier.distance) * share
        }
        return last.distance
    }

    /// Where the plane was at `date`.
    func position(at date: Date) -> CLLocationCoordinate2D {
        path.point(atDistance: distance(at: date))
    }

    /// When the plane was `distance` meters along its path: `distance(at:)` the other way round.
    func time(atDistance distance: Double) -> Date {
        let knots = path.knots
        guard let first = knots.first, let last = knots.last else { return touchdown }
        let far = min(max(distance, 0), path.length)
        if far <= first.distance {
            return first.time.addingTimeInterval(-(first.distance - far) / plan.speed)
        }
        if far >= last.distance {
            return path.hasLanded ? last.time : touchdown.addingTimeInterval(-plan.timeToFly(path.length - far))
        }
        for (earlier, later) in zip(knots, knots.dropFirst()) where far <= later.distance {
            guard later.distance > earlier.distance else { return earlier.time }
            let share = (far - earlier.distance) / (later.distance - earlier.distance)
            return earlier.time.addingTimeInterval(later.time.timeIntervalSince(earlier.time) * share)
        }
        return last.time
    }
}
