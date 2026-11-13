//
//  TripReplayClock.swift
//  CrewLuve
//
//  The full-screen map's time (moving map spec §6): now, a moment dragged to, or a replay running at 1x to 10x.
//  A value: the screen keeps it in `@State` and reads `time(at:)` on each tick, so nothing mutates per frame.
//

import Foundation

nonisolated struct TripReplayClock {

    nonisolated enum Speed: Int, CaseIterable, Identifiable {
        case one = 1, two = 2, five = 5, ten = 10
        var id: Int { rawValue }
    }

    /// Seconds of trip per second of replay at 1x: a day in 48 seconds, as on CrewLu's moving map.
    static let baseRate: Double = 1_800

    let span: DateInterval
    private(set) var speed: Speed = .one

    /// Nil while live. Otherwise the trip time it was set to, and when it started playing from there.
    private var anchor: (tripTime: Date, playingSince: Date?)?

    init(span: DateInterval) {
        self.span = span
    }

    var isLive: Bool { anchor == nil }

    /// Whether a replay is running. It stays true once the replay reaches the trip's end, so the UI checks
    /// `hasFinished(at:)` to show Play again.
    var isPlaying: Bool { anchor?.playingSince != nil }

    /// The trip time to show at the real time `now`.
    func time(at now: Date) -> Date {
        guard let anchor else { return now }
        guard let playingSince = anchor.playingSince else { return anchor.tripTime }
        let elapsed = max(now.timeIntervalSince(playingSince), 0) * Self.baseRate * Double(speed.rawValue)
        return min(anchor.tripTime.addingTimeInterval(elapsed), span.end)
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
