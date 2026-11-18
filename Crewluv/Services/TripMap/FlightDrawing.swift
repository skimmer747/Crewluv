//
//  FlightDrawing.swift
//  CrewLuve
//
//  What one flight draws at a moment (moving map spec §7.1, §7.2; Stage 3 spec §5.1, §6.2, §7.3): its lines and
//  its planes. A flight with a real plane draws its real path, solid where the plane was seen and dotted where it
//  wasn't, with the real plane on it and the schedule's ghost beside it. Any other flight draws the great circle
//  and the schedule's plane, as before.
//

import CoreLocation

nonisolated struct FlightDrawing {
    let segments: [RouteSegment]
    /// The schedule's plane, alone: the flight has no real plane at this moment.
    let plane: PlaneMark?
    let realPlane: RealPlaneMark?
    /// Where an on-schedule plane would be, beside the real one. Now only: a replay has none.
    let ghost: PlaneMark?

    /// - Parameters:
    ///   - date: the moment: now by this device's clock, or a moment of the replay.
    ///   - isReplay: `date` is a moment of the replay, not now. The real plane then flies its record, alone.
    init(leg: MapLeg, at date: Date, isReplay: Bool) {
        let path = leg.flight?.path
        let wholePath = path?.coordinates ?? [leg.origin.coordinate, leg.destination.coordinate]
        if date >= leg.end {
            segments = [RouteSegment(id: "\(leg.id)-flown", coordinates: wholePath, style: .flown)]
            (plane, realPlane, ghost) = (nil, nil, nil)
        } else if !leg.isMoving(at: date) {
            segments = [RouteSegment(id: "\(leg.id)-upcoming", coordinates: wholePath, style: .upcoming)]
            (plane, realPlane, ghost) = (nil, nil, nil)
        } else if let path, let sighting = leg.flight.flatMap({ Self.sighting(of: $0, at: date, isReplay: isReplay) }) {
            segments = Self.segments(of: leg.id, along: path, flownTo: sighting.distance)
            (plane, realPlane, ghost) = (nil, sighting.plane, sighting.ghost)
        } else {
            // The schedule's plane on the great circle, as before Stage 3.
            let fraction = leg.progress(at: date)
            let here = leg.position(atFraction: fraction)
            var segments: [RouteSegment] = []
            if fraction > 0 {
                segments.append(RouteSegment(id: "\(leg.id)-flying", coordinates: [leg.origin.coordinate, here], style: .flying))
            }
            if fraction < 1 {
                segments.append(RouteSegment(id: "\(leg.id)-upcoming", coordinates: [here, leg.destination.coordinate], style: .upcoming))
            }
            self.segments = segments
            (plane, realPlane, ghost) = (PlaneMark(coordinate: here, angle: leg.heading(at: date) ?? 0), nil, nil)
        }
    }

    // MARK: - Private

    /// The real plane of a flight between its gates.
    private struct Sighting {
        /// How far along the path the lines turn from flown to still to come.
        let distance: Double
        let plane: RealPlaneMark
        let ghost: PlaneMark?
    }

    /// The real plane at `date`, or nil when the schedule's plane shows instead: the flight isn't live now, or has
    /// no record to replay.
    private static func sighting(of flight: MapFlight, at date: Date, isReplay: Bool) -> Sighting? {
        let path = flight.path
        if isReplay {
            guard let record = flight.record else { return nil }
            let distance = record.distance(at: date)
            // Past the last place it was seen, the record flies the plan: an estimate, drawn as one.
            let isEstimated = !path.hasLanded && distance > path.flownLength
            let plane = RealPlaneMark(coordinate: path.point(atDistance: distance),
                                      angle: path.heading(atDistance: distance) ?? 0, isEstimated: isEstimated)
            return Sighting(distance: distance, plane: plane, ghost: nil)
        }
        let progress = flight.progress(at: date)
        guard let place = progress.plane else { return nil }
        // A plane on the ground somewhere else isn't on the path: the lines stay as it was last seen flying them.
        let distance = progress.planeDistance ?? path.flownLength
        // In the air the plane points the way it's really going, and otherwise along its path.
        let track = progress.phase == .inAir ? flight.live?.fix?.trackDegrees : nil
        let angle = track.map { ($0 - 90) * .pi / 180 } ?? path.heading(atDistance: distance) ?? 0
        let ghost = progress.ghostDistance.map {
            PlaneMark(coordinate: path.point(atDistance: $0), angle: path.heading(atDistance: $0) ?? 0)
        }
        let plane = RealPlaneMark(coordinate: place, angle: angle, isEstimated: progress.phase == .estimated)
        return Sighting(distance: distance, plane: plane, ghost: ghost)
    }

    /// The path's lines with the plane `distance` meters along it (spec §6.2). Behind the plane the path is flown:
    /// solid where the plane was seen, and dotted where nobody saw it, which is also the plan's line behind a plane
    /// that's only estimated to have flown it. Ahead of the plane it's still to come.
    ///
    /// The map lays a dashed or dotted line from its last place, so that place mustn't move, or the pattern slides
    /// along the line. The line still to come is written from the plane on to the airport. A dotted line can end at
    /// an estimated plane, so it's written the other way, from the plane's side back.
    private static func segments(of legID: String, along path: FlightPath, flownTo distance: Double) -> [RouteSegment] {
        var segments: [RouteSegment] = []
        for run in path.runs(from: 0, to: distance) {
            let style: RouteSegment.Style = run.kind == .seen ? .seen : .unseen
            if let last = segments.last, last.style == style {
                // Two runs drawn the same way are one line, so its dots don't start again where they meet.
                segments[segments.count - 1] = RouteSegment(id: last.id, coordinates: last.coordinates + run.coordinates.dropFirst(),
                                                            style: style)
            } else {
                segments.append(RouteSegment(id: "\(legID)-\(style == .seen ? "seen" : "unseen")-\(segments.count)",
                                             coordinates: run.coordinates, style: style))
            }
        }
        segments = segments.map {
            $0.style == .unseen ? RouteSegment(id: $0.id, coordinates: $0.coordinates.reversed(), style: .unseen) : $0
        }
        let ahead = path.coordinates(from: distance, to: path.length)
        if !ahead.isEmpty {
            segments.append(RouteSegment(id: "\(legID)-upcoming", coordinates: ahead, style: .upcoming))
        }
        return segments
    }
}
