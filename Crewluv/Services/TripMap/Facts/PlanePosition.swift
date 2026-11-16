//
//  PlanePosition.swift
//  CrewLuve
//
//  Where the facts have a flight's plane at a moment (Stage 3 spec §8): the real plane wherever the map draws one,
//  placed as `FlightDrawing` places it so the two agree, and otherwise the schedule's.
//

import CoreLocation

nonisolated struct PlanePosition: Sendable {
    /// How far along the leg's path, in meters.
    let distance: Double
    let coordinate: CLLocationCoordinate2D
    /// Set while the real plane is an estimate: how long ago it was last seen. It's where the plan has it by now.
    let unseenFor: TimeInterval?
    /// The real plane, seen in the air just now. Never in a replay: what only the newest fix tells, its height and
    /// its speed, is for now only.
    let isSeenInAir: Bool

    var isEstimated: Bool { unseenFor != nil }
}

nonisolated extension MapFlight {

    /// The real plane at `date`, or nil where the schedule's plane shows instead: the flight isn't live now, or has
    /// no record to replay.
    /// - Parameters:
    ///   - date: now by this device's clock, or a moment of the replay.
    ///   - isReplay: `date` is a moment of the replay, not now. The plane is then where its record has it.
    func plane(at date: Date, isReplay: Bool) -> PlanePosition? {
        if isReplay {
            guard let record, let lastSeen = path.knots.last else { return nil }
            let distance = record.distance(at: date)
            // Past the last place it was seen, the record flies the plan: an estimate.
            let isEstimated = !path.hasLanded && distance > path.flownLength
            return PlanePosition(distance: distance, coordinate: path.point(atDistance: distance),
                                 unseenFor: isEstimated ? max(0, date.timeIntervalSince(lastSeen.time)) : nil,
                                 isSeenInAir: false)
        }
        let progress = progress(at: date)
        guard let place = progress.plane else { return nil }
        // Crewlu Cloud's clock ages the fix, as it decides the phase.
        let unseenFor = progress.phase == .estimated
            ? live?.fix.map { max(0, date.addingTimeInterval(clockOffset).timeIntervalSince($0.seenAt)) }
            : nil
        // A plane on the ground somewhere else isn't on the path: it counts as far as it was last seen flying.
        return PlanePosition(distance: progress.planeDistance ?? path.flownLength, coordinate: place,
                             unseenFor: unseenFor, isSeenInAir: progress.phase == .inAir)
    }
}

nonisolated extension MapLeg {

    /// Where the plane is at `date`: the real one where the map draws it, and otherwise the schedule's, where the
    /// map draws that. The schedule's plane counts as far along the leg's path as the schedule has it along the
    /// great circle, which without a real path is the same thing.
    func plane(at date: Date, isReplay: Bool) -> PlanePosition {
        if let real = flight?.plane(at: date, isReplay: isReplay) { return real }
        let fraction = progress(at: date)
        return PlanePosition(distance: fraction * pathLength, coordinate: position(atFraction: fraction),
                             unseenFor: nil, isSeenInAir: false)
    }
}
