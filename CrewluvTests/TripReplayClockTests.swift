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

    func test_play_fromLive_startsAtTheTripsStart_atADayIn48Seconds() {
        var clock = TripReplayClock(span: span)
        clock.play(at: now)
        XCTAssertTrue(clock.isPlaying)
        XCTAssertEqual(clock.time(at: now), span.start)
        XCTAssertEqual(clock.time(at: now.addingTimeInterval(48)), span.start.addingTimeInterval(86_400))
    }

    func test_setSpeed_whilePlaying_keepsThePlaceAndGoesFaster() {
        var clock = TripReplayClock(span: span)
        clock.play(at: now)
        let later = now.addingTimeInterval(10)
        let before = clock.time(at: later)
        clock.setSpeed(.ten, at: later)
        XCTAssertEqual(clock.time(at: later), before)
        XCTAssertEqual(clock.time(at: later.addingTimeInterval(1)), before.addingTimeInterval(18_000))
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
        XCTAssertEqual(clock.time(at: now.addingTimeInterval(60)), span.start.addingTimeInterval(5 * 1_800))
    }

    func test_goLive_returnsToNow() {
        var clock = TripReplayClock(span: span)
        clock.scrub(to: span.start)
        clock.goLive()
        XCTAssertTrue(clock.isLive)
        XCTAssertEqual(clock.time(at: now), now)
    }
}
