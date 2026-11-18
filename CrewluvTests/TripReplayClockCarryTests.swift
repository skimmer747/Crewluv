//
//  TripReplayClockCarryTests.swift
//  CrewluvTests
//
//  The full-screen map's clock when the trip's times change under it, as they do with each new landing estimate
//  of the real plane (Stage 3 spec §7.3): the replay carries on from the same moment.
//

import XCTest
@testable import Crewluv

final class TripReplayClockCarryTests: XCTestCase {

    private let span = DateInterval(start: Date(timeIntervalSince1970: 1_800_000_000), duration: 2 * 86_400)
    private let now = Date(timeIntervalSince1970: 1_800_050_000)
    /// The same trip, ending 20 minutes sooner.
    private var sooner: DateInterval { DateInterval(start: span.start, end: span.end.addingTimeInterval(-1200)) }

    func test_carried_aLiveClock_staysLive() {
        let clock = TripReplayClock(span: span).carried(to: sooner, legs: [], waits: [], at: now)
        XCTAssertTrue(clock.isLive)
        XCTAssertEqual(clock.span, sooner)
        XCTAssertEqual(clock.time(at: now), now)
    }

    func test_carried_aPausedClock_staysAtItsMoment() {
        var clock = TripReplayClock(span: span)
        let moment = span.start.addingTimeInterval(30_000)
        clock.scrub(to: moment)

        let carried = clock.carried(to: sooner, legs: [], waits: [], at: now)

        XCTAssertFalse(carried.isLive)
        XCTAssertFalse(carried.isPlaying)
        XCTAssertEqual(carried.time(at: now), moment)
        XCTAssertEqual(carried.time(at: now.addingTimeInterval(60)), moment, "and stays paused")
    }

    func test_carried_aPlayingClock_playsOnFromTheSameMoment_atTheSameSpeed() {
        var clock = TripReplayClock(span: span)
        clock.play(at: now)
        clock.setSpeed(.five, at: now)
        let later = now.addingTimeInterval(10)
        let moment = clock.time(at: later)

        let carried = clock.carried(to: sooner, legs: [], waits: [], at: later)

        XCTAssertTrue(carried.isPlaying)
        XCTAssertEqual(carried.speed, .five)
        XCTAssertEqual(carried.time(at: later), moment)
        XCTAssertEqual(carried.time(at: later.addingTimeInterval(2)), moment.addingTimeInterval(2 * 5 * TripReplayClock.baseRate))
    }

    func test_carried_aMomentPastTheNewEnd_isHeldToIt() {
        var clock = TripReplayClock(span: span)
        clock.scrub(to: span.end)
        XCTAssertEqual(clock.carried(to: sooner, legs: [], waits: [], at: now).time(at: now), sooner.end)
    }

    func test_carried_aClockAtTheOldEnd_isAtTheNewEnd_whenTheTripGrows() {
        // The landing estimate slipped 20 minutes later while a finished replay sat at the trip's end.
        let later = DateInterval(start: span.start, end: span.end.addingTimeInterval(1200))
        var clock = TripReplayClock(span: span)
        clock.scrub(to: span.end)

        let carried = clock.carried(to: later, legs: [], waits: [], at: now)

        XCTAssertEqual(carried.time(at: now), later.end, "still at the end, not 20 minutes short of it")
        XCTAssertFalse(carried.isPlaying)
    }

    func test_carried_aClockAtTheOldStart_isAtTheNewStart_whenTheTripStartsEarlier() {
        // A recap waits at its trip's start. The first flight turned out to have left 10 minutes early.
        let earlier = DateInterval(start: span.start.addingTimeInterval(-600), end: span.end)
        let recap = TripReplayClock(span: span, pausedAt: span.start)

        let carried = recap.carried(to: earlier, legs: [], waits: [], at: now)

        XCTAssertEqual(carried.time(at: now), earlier.start)
        XCTAssertFalse(carried.isLive)
    }

    func test_carried_aFinishedReplay_staysAtTheEnd_paused() {
        var clock = TripReplayClock(span: span)
        clock.scrub(to: span.end.addingTimeInterval(-TripReplayClock.baseRate))
        clock.play(at: now)
        let after = now.addingTimeInterval(5)
        XCTAssertTrue(clock.hasFinished(at: after))

        let carried = clock.carried(to: span, legs: [], waits: [], at: after)

        XCTAssertFalse(carried.isPlaying, "it doesn't start over by itself")
        XCTAssertEqual(carried.time(at: after), span.end)
    }

    func test_carried_keepsQuickLayovers_andTakesTheNewLegsPace() {
        let wait = TripReplayClock.Stretch(start: span.start.addingTimeInterval(3600), end: span.end.addingTimeInterval(-3600))
        let flight = TripReplayClock.Stretch(start: span.start, end: wait.start)
        var clock = TripReplayClock(span: span, isQuickLayovers: true)
        clock.scrub(to: span.start)

        let carried = clock.carried(to: span, legs: [flight], waits: [wait], at: now)

        XCTAssertTrue(carried.isQuickLayovers)
        XCTAssertLessThan(carried.replayDuration, clock.replayDuration, "the new clock hurries through the wait")
    }
}
