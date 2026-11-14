//
//  TripReplayClockPaceTests.swift
//  CrewluvTests
//
//  The replay's pace through waits on the ground, with Quick layovers on and off, and the timeline's positions in
//  replay time (activity markers design §3.2, §4.3). Held to the shared cases in Fixtures/TripMap/replay-cases.json.
//

import XCTest
@testable import Crewluv

final class TripReplayClockPaceTests: XCTestCase {

    private let tripStart = TripMapTestLegs.tripStart
    /// The real time play is pressed.
    private let now = Date(timeIntervalSince1970: 1_800_050_000)

    private func hours(_ value: Double) -> Date { tripStart.addingTimeInterval(value * 3600) }

    private func stretch(_ start: Double, _ end: Double) -> TripReplayClock.Stretch {
        TripReplayClock.Stretch(start: hours(start), end: hours(end))
    }

    /// Louisville to Cologne (8 h), a day in Cologne, on to Dubai (6 h), 20 hours there, and home (14 h). At 1x with
    /// Quick layovers on: 16 s, 3 s, 12 s, 3 s and 28 s; off: 16 s, 48 s, 12 s, 40 s and 28 s.
    private func europe(isQuickLayovers: Bool) -> TripReplayClock {
        TripReplayClock(span: DateInterval(start: hours(0), end: hours(72)),
                        legs: [stretch(0, 8), stretch(32, 38), stretch(58, 72)],
                        waits: [stretch(8, 32), stretch(38, 58)], isQuickLayovers: isQuickLayovers)
    }

    private func playing(_ clock: TripReplayClock) -> TripReplayClock {
        var clock = clock
        clock.play(at: now)
        return clock
    }

    private func assertTime(_ clock: TripReplayClock, after seconds: TimeInterval, isHour hour: Double,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(clock.time(at: now.addingTimeInterval(seconds)).timeIntervalSince1970,
                       hours(hour).timeIntervalSince1970, accuracy: 0.01, file: file, line: line)
    }

    // MARK: - Quick layovers

    func test_play_quickLayovers_aDayInCologneTakes3Seconds() {
        let clock = playing(europe(isQuickLayovers: true))
        assertTime(clock, after: 16, isHour: 8)
        assertTime(clock, after: 17.5, isHour: 20)
        assertTime(clock, after: 19, isHour: 32)
    }

    func test_play_quickLayoversOff_aDayInCologneTakes48Seconds() {
        let clock = playing(europe(isQuickLayovers: false))
        assertTime(clock, after: 17.5, isHour: 8.75)
        assertTime(clock, after: 64, isHour: 32)
    }

    func test_play_quickLayovers_aFourDayLayoverTakes4Seconds() {
        let clock = playing(TripReplayClock(span: DateInterval(start: hours(0), end: hours(100)),
                                            legs: [stretch(0, 2), stretch(98, 100)], waits: [stretch(2, 98)],
                                            isQuickLayovers: true))
        assertTime(clock, after: 5, isHour: 26)
        assertTime(clock, after: 8, isHour: 98)
    }

    func test_play_quickLayovers_anHoursTurnKeepsItsNormal2Seconds_andTwoHoursTake3() {
        let clock = playing(TripReplayClock(span: DateInterval(start: hours(0), end: hours(9)),
                                            legs: [stretch(0, 2), stretch(3, 5), stretch(7, 9)],
                                            waits: [stretch(2, 3), stretch(5, 7)], isQuickLayovers: true))
        assertTime(clock, after: 6, isHour: 3)
        assertTime(clock, after: 11.5, isHour: 6)
        assertTime(clock, after: 13, isHour: 7)
    }

    func test_play_quickLayovers_atTenTimes_everyPartTakesATenth() {
        var clock = playing(europe(isQuickLayovers: true))
        clock.setSpeed(.ten, at: now)
        assertTime(clock, after: 1.6, isHour: 8)
        assertTime(clock, after: 1.9, isHour: 32)
    }

    func test_setQuickLayovers_whilePlaying_keepsTheMomentAndChangesThePace() {
        var clock = playing(europe(isQuickLayovers: true))
        let midLayover = now.addingTimeInterval(17.5)
        clock.setQuickLayovers(false, at: midLayover)
        XCTAssertFalse(clock.isQuickLayovers)
        XCTAssertEqual(clock.time(at: midLayover).timeIntervalSince1970, hours(20).timeIntervalSince1970, accuracy: 0.01)
        // The rest of the day in Cologne, 12 hours, at a day in 48 s: 24 s.
        XCTAssertEqual(clock.time(at: midLayover.addingTimeInterval(24)).timeIntervalSince1970,
                       hours(32).timeIntervalSince1970, accuracy: 0.01)
    }

    func test_setQuickLayovers_whilePaused_keepsTheMoment() {
        var clock = europe(isQuickLayovers: false)
        clock.scrub(to: hours(20))
        clock.setQuickLayovers(true, at: now)
        XCTAssertFalse(clock.isPlaying)
        XCTAssertEqual(clock.time(at: now.addingTimeInterval(60)), hours(20))
    }

    func test_pause_afterTheEnd_holdsTheEnd_andPlayStartsOver() {
        var clock = playing(europe(isQuickLayovers: true))
        let afterTheEnd = now.addingTimeInterval(70)
        clock.pause(at: afterTheEnd)
        XCTAssertEqual(clock.time(at: afterTheEnd), hours(72))
        XCTAssertFalse(clock.hasFinished(at: afterTheEnd), "paused, the replay isn't running")
        clock.play(at: afterTheEnd)
        XCTAssertEqual(clock.time(at: afterTheEnd), hours(0))
    }

    // MARK: - Positions in replay time

    func test_replayDuration_isTheWholeReplayAt1x_atEachPace() {
        XCTAssertEqual(europe(isQuickLayovers: true).replayDuration, 62, accuracy: 1e-9)
        XCTAssertEqual(europe(isQuickLayovers: false).replayDuration, 144, accuracy: 1e-9)
    }

    func test_replayOffset_andTripTimeAtReplayOffset_areInverses() {
        let clock = europe(isQuickLayovers: true)
        XCTAssertEqual(clock.replayOffset(of: hours(20)), 17.5, accuracy: 1e-9)
        XCTAssertEqual(clock.tripTime(atReplayOffset: 17.5).timeIntervalSince1970, hours(20).timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(clock.tripTime(atReplayOffset: 100), hours(72), "past the whole replay, the end")
    }

    func test_progress_isReplayTimeOverTheWhole_andIsHeldToTheEnds() {
        let clock = europe(isQuickLayovers: true)
        XCTAssertEqual(clock.progress(at: hours(8)), 16.0 / 62, accuracy: 1e-9)
        XCTAssertEqual(clock.progress(at: hours(-5)), 0)
        XCTAssertEqual(clock.progress(at: hours(99)), 1)
        XCTAssertEqual(clock.tripTime(atProgress: 31.0 / 62).timeIntervalSince1970, hours(38).timeIntervalSince1970, accuracy: 0.001)
    }

    func test_progress_aTripWithNoLength_isZero() {
        let clock = TripReplayClock(span: DateInterval(start: hours(0), end: hours(0)))
        XCTAssertEqual(clock.progress(at: hours(0)), 0)
    }

    // MARK: - The shared cases

    func test_constants_matchTheSharedCases() throws {
        let constants = try TripMapFixtures.replayCases().constants
        XCTAssertEqual(TripReplayClock.baseRate, constants.baseRate)
        XCTAssertEqual(TripReplayClock.legMinimumReplay, constants.legMinimumSeconds)
        XCTAssertEqual(TripReplayClock.waitMinimumReplay, constants.waitMinimumSeconds)
        XCTAssertEqual(TripReplayClock.quickWaitRate, constants.quickWaitRate)
    }

    func test_play_everySharedCase_matches() throws {
        let cases = try TripMapFixtures.replayCases().cases
        XCTAssertFalse(cases.isEmpty)
        for replayCase in cases {
            let speed = try XCTUnwrap(TripReplayClock.Speed(rawValue: replayCase.speed), replayCase.name)
            var clock = TripReplayClock(span: DateInterval(start: replayCase.span.start, end: replayCase.span.end),
                                        legs: replayCase.legs.map(\.clockStretch), waits: replayCase.waits.map(\.clockStretch),
                                        isQuickLayovers: replayCase.quickLayovers)
            XCTAssertEqual(clock.replayDuration, replayCase.replayLength, accuracy: 1e-6, replayCase.name)
            clock.play(at: now)
            clock.setSpeed(speed, at: now)
            for check in replayCase.checks {
                XCTAssertEqual(clock.time(at: now.addingTimeInterval(check.seconds)).timeIntervalSince1970,
                               check.at.timeIntervalSince1970, accuracy: 0.01, "\(replayCase.name), at \(check.seconds) s")
            }
        }
    }
}
