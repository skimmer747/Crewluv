//
//  LiveLabelTests.swift
//  CrewluvTests
//
//  Ahead of the schedule or behind it, and its words (Stage 3 spec §5.3), held to the shared cases in Fixtures/TripMap.
//

import XCTest
@testable import Crewluv

final class LiveLabelTests: XCTestCase {

    func test_constants_matchTheSharedCases() throws {
        XCTAssertEqual(LiveLabel.onScheduleWithin, try TripMapFixtures.liveCases().constants.onScheduleMinutes)
    }

    func test_labels_everySharedCase_matches() throws {
        let labels = try TripMapFixtures.liveCases().labels
        XCTAssertFalse(labels.isEmpty)
        for labelCase in labels {
            let phase = try XCTUnwrap(LiveProgress.Phase(rawValue: labelCase.phase), labelCase.phase)
            let label = LiveLabel(phase: phase, gapMinutes: labelCase.gapMinutes)
            XCTAssertEqual(label.map(TripMapWording.liveLabel), labelCase.label,
                           "\(labelCase.phase), \(labelCase.gapMinutes.map(String.init) ?? "no gap")")
        }
    }

    func test_init_inTheAir_sixMinutesEitherWay_isAheadOrBehind() {
        XCTAssertEqual(LiveLabel(phase: .inAir, gapMinutes: 6), .ahead(minutes: 6, isEstimated: false))
        XCTAssertEqual(LiveLabel(phase: .inAir, gapMinutes: -6), .behind(minutes: 6, isEstimated: false))
        XCTAssertEqual(LiveLabel(phase: .estimated, gapMinutes: -6), .behind(minutes: 6, isEstimated: true))
    }

    func test_init_withinFiveMinutes_isOnSchedule() {
        XCTAssertEqual(LiveLabel(phase: .inAir, gapMinutes: 5), .onSchedule)
        XCTAssertEqual(LiveLabel(phase: .estimated, gapMinutes: -5), .onSchedule)
        XCTAssertEqual(LiveLabel(phase: .landed, gapMinutes: -5), .landedOnTime)
        XCTAssertEqual(LiveLabel(phase: .onGround, gapMinutes: -5), .stillOnGround(minutesBehind: nil))
    }

    func test_init_noGap_orNotOnTheMap_isNil() {
        XCTAssertNil(LiveLabel(phase: .inAir, gapMinutes: nil))
        XCTAssertNil(LiveLabel(phase: .onGround, gapMinutes: nil))
        XCTAssertNil(LiveLabel(phase: .notLive, gapMinutes: 12))
        XCTAssertNil(LiveLabel(phase: .elsewhere, gapMinutes: 12))
    }

    func test_minutesText_writesHoursAsTheCountdownDoes() {
        XCTAssertEqual(TripMapWording.minutesText(45), "45 min")
        XCTAssertEqual(TripMapWording.minutesText(120), "2 h")
        XCTAssertEqual(TripMapWording.minutesText(130), "2 h 10 min")
    }
}
