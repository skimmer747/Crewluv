//
//  TripTimeline.swift
//  CrewLuve
//
//  The timeline bar's blocks (activity markers design §4.1): the trip's span in replay time at 1x, at the clock's pace,
//  each part colored by what the pilot is doing. A flight that overlaps a drive is flying. Each wait carries its real
//  length, "20h" or "4d", which the bar writes on it when it fits.
//

import Foundation

nonisolated struct TripTimeline {

    nonisolated struct Block: Equatable {
        let kind: TripActivity.Kind
        /// Where it starts and ends along the bar, 0...1: its replay time at 1x over the whole replay's.
        let start: Double
        let end: Double
        /// A wait's real length; nil for a flight or a drive, and for a wait under half an hour.
        let label: String?
    }

    /// Earliest first, end to end from 0 to 1. Empty for a trip with no length.
    let blocks: [Block]

    init(tripMap: TripMap, clock: TripReplayClock) {
        guard clock.replayDuration > 0 else {
            blocks = []
            return
        }
        let span = tripMap.span
        let moving = tripMap.legs.filter { $0.end > $0.start }
        let waits = tripMap.waits
        let cuts = Set(([span.start, span.end] + moving.flatMap { [$0.start, $0.end] })
            .filter { span.start <= $0 && $0 <= span.end }).sorted()
        var parts: [(kind: TripActivity.Kind, start: Date, end: Date)] = []
        for (from, to) in zip(cuts, cuts.dropFirst()) {
            let kind = Self.kind(from: from, to: to, moving: moving, waits: waits)
            if let last = parts.last, last.kind == kind {
                parts[parts.count - 1].end = to
            } else {
                parts.append((kind, from, to))
            }
        }
        blocks = parts.map { part in
            Block(kind: part.kind, start: clock.progress(at: part.start), end: clock.progress(at: part.end),
                  label: part.kind.isMoving ? nil : Self.lengthLabel(for: part.end.timeIntervalSince(part.start)))
        }
    }

    /// A wait's length on its block (design §4.1): whole hours under 48, whole days from 48, each to the nearest, halves
    /// up; nil when it rounds to no hours. The shared cases are `waitLabels` in
    /// CrewluvTests/Fixtures/TripMap/replay-cases.json.
    static func lengthLabel(for duration: TimeInterval) -> String? {
        let hours = Int((duration / 3600).rounded())
        guard hours > 0 else { return nil }
        guard hours >= 48 else { return "\(hours)h" }
        return "\(Int((duration / 86_400).rounded()))d"
    }

    /// Flying where any flight moves, else driving where a drive does, else the wait's kind.
    private static func kind(from: Date, to: Date, moving: [MapLeg], waits: [TripWait]) -> TripActivity.Kind {
        let covering = moving.filter { $0.start <= from && to <= $0.end }
        if covering.contains(where: { $0.kind == .flight }) { return .flying }
        if !covering.isEmpty { return .driving }
        // A stretch no moving leg covers is inside one of the map's waits.
        return waits.first { $0.start <= from && to <= $0.end }?.kind ?? .turn
    }
}
