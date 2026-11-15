//
//  TripReplayClock.swift
//  CrewLuve
//
//  The full-screen map's time (moving map spec §6): now, a moment dragged to, or a replay running at 1x to 10x.
//  A value: the screen keeps it in `@State` and reads `time(at:)` on each tick, so nothing mutates per frame.
//  The pace (activity markers design §3.2) is a day in 48 s. A leg in motion that would pass in under 3 s at 1x slows
//  so it takes 3 s, as on the website (Crewluve Website docs/superpowers/specs/2026-11-13-replay-short-legs-design.md).
//  With Quick layovers on, a wait on the ground takes a second a day, never under 3 s and never slower than a day in
//  48 s. The clock also places any moment along the timeline in replay time (§4.3). The shared cases are in
//  CrewluvTests/Fixtures/TripMap/replay-cases.json.
//

import Foundation

nonisolated struct TripReplayClock {

    nonisolated enum Speed: Int, CaseIterable, Identifiable {
        case one = 1, two = 2, five = 5, ten = 10
        var id: Int { rawValue }
    }

    /// A leg's or a wait's stretch of trip time, from its start to its end.
    nonisolated struct Stretch: Equatable {
        let start: Date
        let end: Date

        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    /// Seconds of trip per second of replay at 1x: a day in 48 seconds, as on CrewLu's moving map.
    static let baseRate: Double = 1_800
    /// The least replay time, in seconds at 1x, that a leg in motion takes, so a drive to work can be seen.
    static let legMinimumReplay: TimeInterval = 3
    /// The least replay time, in seconds at 1x, that a wait takes with Quick layovers on.
    static let waitMinimumReplay: TimeInterval = 3
    /// Seconds of trip per second of replay at 1x through a long wait with Quick layovers on: a day a second.
    static let quickWaitRate: Double = 86_400

    let span: DateInterval
    private(set) var speed: Speed = .one
    /// Whether waits on the ground hurry by (activity markers design §3.1).
    private(set) var isQuickLayovers: Bool

    /// The span cut at every leg's and wait's start and end, each piece with its rate, at the normal pace and with
    /// Quick layovers on. Both are worked out here, so switching costs nothing.
    private let normalPieces: [Piece]
    private let quickPieces: [Piece]

    /// Nil while live. Otherwise the trip time it was set to, and when it started playing from there.
    private var anchor: (tripTime: Date, playingSince: Date?)?

    /// - Parameters:
    ///   - legs: the trip's drives and flights. A short one slows the replay while it moves.
    ///   - waits: the stretches with no leg moving, which Quick layovers hurries through.
    ///   - isQuickLayovers: off unless asked, so a clock made as before plays as before.
    init(span: DateInterval, legs: [Stretch] = [], waits: [Stretch] = [], isQuickLayovers: Bool = false) {
        self.span = span
        self.isQuickLayovers = isQuickLayovers
        normalPieces = Self.pace(span: span, legs: legs, waits: waits, isQuickLayovers: false)
        quickPieces = Self.pace(span: span, legs: legs, waits: waits, isQuickLayovers: true)
    }

    /// Paused at `date`: the recap opens at its trip's start, ready to play (Stage 2 spec §6.5).
    init(span: DateInterval, legs: [Stretch] = [], waits: [Stretch] = [], isQuickLayovers: Bool = false,
         pausedAt date: Date) {
        self.init(span: span, legs: legs, waits: waits, isQuickLayovers: isQuickLayovers)
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
        let elapsed = max(now.timeIntervalSince(playingSince), 0) * Double(speed.rawValue)
        return tripTime(atReplayOffset: replayOffset(of: anchor.tripTime) + elapsed)
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

    /// Hurries through waits, or plays them at the normal rate, from the moment on screen (activity markers design
    /// §3.1). A replay carries on from there at the new pace.
    mutating func setQuickLayovers(_ isOn: Bool, at now: Date) {
        if isPlaying { anchor = (time(at: now), now) }
        isQuickLayovers = isOn
    }

    mutating func goLive() {
        anchor = nil
    }
}

// MARK: - Positions along the timeline (activity markers design §4.3)

nonisolated extension TripReplayClock {

    /// The whole replay at 1x, in seconds, at the current pace.
    var replayDuration: TimeInterval { replayOffset(of: span.end) }

    /// The replay seconds at 1x from the span's start to the trip time `date`, at the current pace.
    func replayOffset(of date: Date) -> TimeInterval {
        pieces.reduce(0) { sum, piece in sum + max(0, min(date, piece.end).timeIntervalSince(piece.start)) / piece.rate }
    }

    /// The trip time `offset` replay seconds at 1x after the span's start, at the current pace: the span's end once
    /// the whole replay has played.
    func tripTime(atReplayOffset offset: TimeInterval) -> Date {
        var left = offset
        for piece in pieces {
            let length = piece.end.timeIntervalSince(piece.start) / piece.rate
            if left < length { return piece.start.addingTimeInterval(max(left, 0) * piece.rate) }
            left -= length
        }
        return span.end
    }

    /// Where `date` sits along the timeline, 0 at the span's start and 1 at its end, in replay time at 1x. The bar's
    /// thumb and blocks are placed by it.
    func progress(at date: Date) -> Double {
        let duration = replayDuration
        guard duration > 0 else { return 0 }
        return min(max(replayOffset(of: date) / duration, 0), 1)
    }

    /// The trip time at `progress`, 0...1, along the timeline.
    func tripTime(atProgress progress: Double) -> Date {
        tripTime(atReplayOffset: min(max(progress, 0), 1) * replayDuration)
    }
}

// MARK: - The pace

nonisolated extension TripReplayClock {

    /// A stretch of the trip played at one rate: trip seconds per replay second at 1x.
    private nonisolated struct Piece {
        let start: Date
        let end: Date
        let rate: Double
    }

    /// The pieces at the pace in use.
    private var pieces: [Piece] { isQuickLayovers ? quickPieces : normalPieces }

    /// Each piece plays at the normal rate. While legs move through it, it plays at the slowest of their rates, a
    /// leg's length over 3 s; a leg with no length covers no piece, so it adds no time. Through a wait with Quick
    /// layovers on, it plays at the whole wait's quick rate.
    private static func pace(span: DateInterval, legs: [Stretch], waits: [Stretch], isQuickLayovers: Bool) -> [Piece] {
        let cuts = ([span.start, span.end] + (legs + waits).flatMap { [$0.start, $0.end] })
            .filter { span.start <= $0 && $0 <= span.end }
        let times = Set(cuts).sorted()
        return zip(times, times.dropFirst()).map { from, to in
            let moving = legs.filter { $0.start <= from && to <= $0.end }
            if !moving.isEmpty {
                return Piece(start: from, end: to, rate: moving.map { $0.duration / legMinimumReplay }.reduce(baseRate, min))
            }
            let wait = isQuickLayovers ? waits.first(where: { $0.start <= from && to <= $0.end }) : nil
            return Piece(start: from, end: to, rate: wait.map { quickRate(forWaitOf: $0.duration) } ?? baseRate)
        }
    }

    /// A wait of `length` trip seconds plays in min(length / 1,800, max(3, length / 86,400)) replay seconds at 1x: a
    /// second a day, never under 3 s, and never slower than the normal rate. As a rate, that's the wait's length over
    /// those seconds.
    private static func quickRate(forWaitOf length: TimeInterval) -> Double {
        max(baseRate, min(length / waitMinimumReplay, quickWaitRate))
    }
}
