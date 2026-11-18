//
//  TripReplayClockTests.swift
//  CrewluvTests
//
//  The full-screen map's timeline (moving map spec §6): live, scrubbed, or playing at 1x to 10x.
//

import XCTest
@testable import Crewluv

final class TripReplayClockTests: XCTestCase {

    private let span = DateInterval(start: Date(timeIntervalSince1970: 1_800_000_000), duration: 2 * 86_400)
    private let now = Date(timeIntervalSince1970: 1_800_050_000)

    func test_time_whenLive_isNow() {
        let clock = TripReplayClock(span: span)
        XCTAssertTrue(clock.isLive)
        XCTAssertFalse(clock.isPlaying)
        XCTAssertEqual(clock.time(at: now), now)
    }

    func test_scrub_outsideTheTrip_isHeldToItsEnds() {
        var clock = TripReplayClock(span: span)
        clock.scrub(to: span.start.addingTimeInterval(-3600))
        XCTAssertEqual(clock.time(at: now), span.start)
        clock.scrub(to: span.end.addingTimeInterval(3600))
        XCTAssertEqual(clock.time(at: now), span.end)
        XCTAssertFalse(clock.isLive)
        XCTAssertFalse(clock.isPlaying)
    }

    func test_play_fromLive_startsAtTheTripsStart_atADayIn96Seconds() {
        var clock = TripReplayClock(span: span)
        clock.play(at: now)
        XCTAssertTrue(clock.isPlaying)
        XCTAssertEqual(clock.time(at: now), span.start)
        XCTAssertEqual(clock.time(at: now.addingTimeInterval(96)), span.start.addingTimeInterval(86_400))
    }

    func test_setSpeed_whilePlaying_keepsThePlaceAndGoesFaster() {
        var clock = TripReplayClock(span: span)
        clock.play(at: now)
        let later = now.addingTimeInterval(10)
        let before = clock.time(at: later)
        clock.setSpeed(.ten, at: later)
        XCTAssertEqual(clock.time(at: later), before)
        XCTAssertEqual(clock.time(at: later.addingTimeInterval(1)), before.addingTimeInterval(9_000))
    }

    func test_play_pastTheEnd_stopsThere_andPlayingAgainStartsOver() {
        var clock = TripReplayClock(span: span)
        clock.play(at: now)
        let afterTheEnd = now.addingTimeInterval(500)
        XCTAssertEqual(clock.time(at: afterTheEnd), span.end)
        XCTAssertTrue(clock.hasFinished(at: afterTheEnd))
        clock.play(at: afterTheEnd)
        XCTAssertEqual(clock.time(at: afterTheEnd), span.start)
    }

    func test_pause_holdsTheTime() {
        var clock = TripReplayClock(span: span)
        clock.play(at: now)
        clock.pause(at: now.addingTimeInterval(5))
        XCTAssertFalse(clock.isPlaying)
        XCTAssertEqual(clock.time(at: now.addingTimeInterval(60)), span.start.addingTimeInterval(5 * 900))
    }

    func test_goLive_returnsToNow() {
        var clock = TripReplayClock(span: span)
        clock.scrub(to: span.start)
        clock.goLive()
        XCTAssertTrue(clock.isLive)
        XCTAssertEqual(clock.time(at: now), now)
    }

    func test_initPausedAt_isPausedThere() {
        let clock = TripReplayClock(span: span, pausedAt: span.start)
        XCTAssertFalse(clock.isLive)
        XCTAssertFalse(clock.isPlaying)
        XCTAssertEqual(clock.time(at: now), span.start)
    }

    // MARK: - Short legs take at least 6 s at 1x, as on the website (replay short legs design, 2026-11-13, at half its pace since 17 Nov 2026)

    private let tripStart = Date(timeIntervalSince1970: 1_800_000_000)

    private func minutes(_ minutes: Double) -> Date {
        tripStart.addingTimeInterval(minutes * 60)
    }

    private func leg(_ start: Double, _ end: Double) -> TripReplayClock.Stretch {
        TripReplayClock.Stretch(start: minutes(start), end: minutes(end))
    }

    /// A 25-minute drive, a 30-minute gap, a 50-minute hop, an hour's gap and an 8-hour flight. At 1x: 6 s, 2 s, 6 s,
    /// 4 s and 32 s, 50 s in all.
    private func playingShortLegs(alsoWith extra: [TripReplayClock.Stretch] = []) -> TripReplayClock {
        var clock = TripReplayClock(span: DateInterval(start: minutes(0), end: minutes(645)),
                                    legs: [leg(0, 25), leg(55, 105), leg(165, 645)] + extra)
        clock.play(at: now)
        return clock
    }

    private func assertTime(_ clock: TripReplayClock, after seconds: TimeInterval, isMinute minute: Double,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(clock.time(at: now.addingTimeInterval(seconds)).timeIntervalSince1970,
                       minutes(minute).timeIntervalSince1970, accuracy: 0.01, file: file, line: line)
    }

    func test_play_aShortDrive_takes6SecondsAt1x_andHalfThatAt2x() {
        assertTime(playingShortLegs(), after: 3, isMinute: 12.5)
        assertTime(playingShortLegs(), after: 6, isMinute: 25)
        var faster = playingShortLegs()
        faster.setSpeed(.two, at: now)
        assertTime(faster, after: 3, isMinute: 25)
    }

    func test_play_aShortFlight_takes6Seconds_andTheGapsPlayAtADayIn96Seconds() {
        assertTime(playingShortLegs(), after: 8, isMinute: 55)
        assertTime(playingShortLegs(), after: 14, isMinute: 105)
        assertTime(playingShortLegs(), after: 18, isMinute: 165)
    }

    func test_play_aLegOf90MinutesOrMore_playsAsBefore() {
        assertTime(playingShortLegs(), after: 34, isMinute: 405)
        assertTime(playingShortLegs(), after: 50, isMinute: 645)
    }

    func test_hasFinished_aSlowedReplay_atItsEnd_atAnySpeed() {
        let clock = playingShortLegs()
        XCTAssertFalse(clock.hasFinished(at: now.addingTimeInterval(49.9)))
        XCTAssertTrue(clock.hasFinished(at: now.addingTimeInterval(50.001)))
        var faster = playingShortLegs()
        faster.setSpeed(.two, at: now)
        XCTAssertFalse(faster.hasFinished(at: now.addingTimeInterval(24.9)))
        XCTAssertTrue(faster.hasFinished(at: now.addingTimeInterval(25.001)))
    }

    func test_pauseOrSetSpeed_inTheMiddleOfASlowedLeg_keepsTheMoment() {
        var paused = playingShortLegs()
        paused.pause(at: now.addingTimeInterval(3))
        assertTime(paused, after: 60, isMinute: 12.5)
        var faster = playingShortLegs()
        faster.setSpeed(.five, at: now.addingTimeInterval(3))
        assertTime(faster, after: 3, isMinute: 12.5)
        assertTime(faster, after: 3.6, isMinute: 25)
    }

    func test_play_fromPartwayThroughASlowedLeg_takesOnlyTheRestOfIts6Seconds() {
        var clock = TripReplayClock(span: DateInterval(start: minutes(0), end: minutes(645)),
                                    legs: [leg(0, 25), leg(55, 105), leg(165, 645)])
        clock.scrub(to: minutes(12.5))
        clock.play(at: now)
        assertTime(clock, after: 3, isMinute: 25)
    }

    func test_play_twoOverlappingLegs_takeTheSlowerRateWhileBothMove() {
        // An hour's leg (6 s would be 600x) with a 15-minute one inside it (150x): 3 s, then 6 s, then 1.5 s.
        var clock = TripReplayClock(span: DateInterval(start: minutes(0), end: minutes(60)), legs: [leg(0, 60), leg(30, 45)])
        clock.play(at: now)
        assertTime(clock, after: 3, isMinute: 30)
        assertTime(clock, after: 9, isMinute: 45)
        XCTAssertFalse(clock.hasFinished(at: now.addingTimeInterval(10.4)))
        XCTAssertTrue(clock.hasFinished(at: now.addingTimeInterval(10.501)))
    }

    func test_play_aLegWithNoLength_addsNoTime() {
        let clock = playingShortLegs(alsoWith: [leg(40, 40)])
        assertTime(clock, after: 8, isMinute: 55)
        XCTAssertFalse(clock.hasFinished(at: now.addingTimeInterval(49.9)))
        XCTAssertTrue(clock.hasFinished(at: now.addingTimeInterval(50.001)))
    }
}
