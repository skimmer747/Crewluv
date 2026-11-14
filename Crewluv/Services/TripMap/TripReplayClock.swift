//
//  TripReplayClock.swift
//  CrewLuve
//
//  The full-screen map's time (moving map spec §6): now, a moment dragged to, or a replay running at 1x to 10x.
//  A value: the screen keeps it in `@State` and reads `time(at:)` on each tick, so nothing mutates per frame.
//  A leg in motion that would pass in under 3 s at 1x slows so it takes 3 s, as on the website
//  (Crewluve Website docs/superpowers/specs/2026-11-13-replay-short-legs-design.md).
//

import Foundation

nonisolated struct TripReplayClock {

    nonisolated enum Speed: Int, CaseIterable, Identifiable {
        case one = 1, two = 2, five = 5, ten = 10
        var id: Int { rawValue }
    }

    /// A leg's stretch of trip time, from its start to its end.
    nonisolated struct Stretch: Equatable {
        let start: Date
        let end: Date
    }

    /// Seconds of trip per second of replay at 1x: a day in 48 seconds, as on CrewLu's moving map.
    static let baseRate: Double = 1_800
    /// The least replay time, in seconds at 1x, that a leg in motion takes, so a drive to work can be seen.
    static let legMinimumReplay: TimeInterval = 3

    let span: DateInterval
    private(set) var speed: Speed = .one

    /// The span cut at every leg's start and end, each piece with its rate: trip seconds per replay second at 1x.
    private let pieces: [Piece]

    /// Nil while live. Otherwise the trip time it was set to, and when it started playing from there.
    private var anchor: (tripTime: Date, playingSince: Date?)?

    /// - Parameter legs: the trip's drives and flights. A short one slows the replay while it moves.
    init(span: DateInterval, legs: [Stretch] = []) {
        self.span = span
        pieces = Self.pace(span: span, legs: legs)
    }

    /// Paused at `date`: the recap opens at its trip's start, ready to play (Stage 2 spec §6.5).
    init(span: DateInterval, legs: [Stretch] = [], pausedAt date: Date) {
        self.init(span: span, legs: legs)
        scrub(to: date)
    }

    var isLive: Bool { anchor == nil }

    /// Whether a replay is running. It stays true once the replay reaches the trip's end, so the UI checks
    /// `hasFinished(at:)` to show Play again.
    var isPlaying: Bool { anchor?.playingSince != nil }

    /// The trip time to show at the real time `now`.
    func time(at now: Date) -> Date {
        guard let anchor else { return now }
        guard let playingSince = anchor.playingSince else { return anchor.tripTime }
        let replay = replayTime(at: anchor.tripTime) + max(now.timeIntervalSince(playingSince), 0) * Double(speed.rawValue)
        return replay >= replayTime(at: span.end) ? span.end : tripTime(atReplay: replay)
    }

    /// True once a replay has run to the trip's end.
    func hasFinished(at now: Date) -> Bool {
        isPlaying && time(at: now) >= span.end
    }

    mutating func scrub(to date: Date) {
        anchor = (min(max(date, span.start), span.end), nil)
    }

    /// Plays from where it is, from the start when live, and again from the start once it has finished.
    mutating func play(at now: Date) {
        let current = isLive ? span.start : time(at: now)
        anchor = (current >= span.end ? span.start : current, now)
    }

    mutating func pause(at now: Date) {
        guard isPlaying else { return }
        anchor = (time(at: now), nil)
    }

    mutating func setSpeed(_ newSpeed: Speed, at now: Date) {
        if isPlaying { anchor = (time(at: now), now) }
        speed = newSpeed
    }

    mutating func goLive() {
        anchor = nil
    }
}

// MARK: - The pace

nonisolated extension TripReplayClock {

    /// A stretch of the trip played at one rate.
    private nonisolated struct Piece {
        let start: Date
        let end: Date
        let rate: Double
    }

    /// Each piece plays at the normal rate or, while legs move through it, at the slowest of their rates: a leg's
    /// length over 3 s. A leg with no length covers no piece, so it adds no time.
    private static func pace(span: DateInterval, legs: [Stretch]) -> [Piece] {
        let cuts = ([span.start, span.end] + legs.flatMap { [$0.start, $0.end] }).filter { span.start <= $0 && $0 <= span.end }
        let times = Set(cuts).sorted()
        return zip(times, times.dropFirst()).map { from, to in
            let rate = legs
                .filter { $0.start <= from && to <= $0.end }
                .map { $0.end.timeIntervalSince($0.start) / legMinimumReplay }
                .reduce(baseRate, min)
            return Piece(start: from, end: to, rate: rate)
        }
    }

    /// The replay time at 1x from the span's start to the trip time `date`.
    private func replayTime(at date: Date) -> TimeInterval {
        pieces.reduce(0) { sum, piece in sum + max(0, min(date, piece.end).timeIntervalSince(piece.start)) / piece.rate }
    }

    /// The trip time `replay` seconds after the span's start at 1x, short of the end.
    private func tripTime(atReplay replay: TimeInterval) -> Date {
        var left = replay
        for piece in pieces {
            let length = piece.end.timeIntervalSince(piece.start) / piece.rate
            if left < length { return piece.start.addingTimeInterval(left * piece.rate) }
            left -= length
        }
        return span.end
    }
}
