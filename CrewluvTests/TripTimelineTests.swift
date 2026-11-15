//
//  TripTimelineTests.swift
//  CrewluvTests
//
//  The timeline bar's blocks, in replay time and colored by what the pilot is doing, and the waits' lengths written on
//  them (activity markers design §4.1).
//

import XCTest
@testable import Crewluv

final class TripTimelineTests: XCTestCase {

    private typealias Expected = (kind: TripActivity.Kind, start: Double, end: Double, label: String?)

    private let start = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { start.addingTimeInterval(value * 3600) }

    private func europe() throws -> TripMap {
        try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
    }

    private func clock(for map: TripMap, isQuickLayovers: Bool) -> TripReplayClock {
        TripReplayClock(span: map.span, legs: map.legs.map { .init(start: $0.start, end: $0.end) },
                        waits: map.waits.map { .init(start: $0.start, end: $0.end) }, isQuickLayovers: isQuickLayovers)
    }

    private func assertBlocks(_ blocks: [TripTimeline.Block], are expected: [Expected],
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(blocks.map(\.kind), expected.map { $0.kind }, file: file, line: line)
        for (block, want) in zip(blocks, expected) {
            XCTAssertEqual(block.start, want.start, accuracy: 1e-9, file: file, line: line)
            XCTAssertEqual(block.end, want.end, accuracy: 1e-9, file: file, line: line)
            XCTAssertEqual(block.label, want.label, file: file, line: line)
        }
    }

    // MARK: - Blocks

    func test_blocks_quickLayovers_areTheFlightsAndTwoSmallLayovers() throws {
        let map = try europe()
        // 16 s, 3 s, 12 s, 3 s and 28 s of a 62 s replay.
        assertBlocks(TripTimeline(tripMap: map, clock: clock(for: map, isQuickLayovers: true)).blocks, are: [
            (.flying, 0, 16.0 / 62, nil), (.layover, 16.0 / 62, 19.0 / 62, "24h"), (.flying, 19.0 / 62, 31.0 / 62, nil),
            (.layover, 31.0 / 62, 34.0 / 62, "20h"), (.flying, 34.0 / 62, 1, nil),
        ])
    }

    func test_blocks_quickLayoversOff_theLayoversTakeTheirFullShare() throws {
        let map = try europe()
        // 16 s, 48 s, 12 s, 40 s and 28 s of a 144 s replay.
        assertBlocks(TripTimeline(tripMap: map, clock: clock(for: map, isQuickLayovers: false)).blocks, are: [
            (.flying, 0, 16.0 / 144, nil), (.layover, 16.0 / 144, 64.0 / 144, "24h"), (.flying, 64.0 / 144, 76.0 / 144, nil),
            (.layover, 76.0 / 144, 116.0 / 144, "20h"), (.flying, 116.0 / 144, 1, nil),
        ])
    }

    func test_blocks_aFlightOverlappingADrive_isFlying() throws {
        let legs = [
            TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(0), hours: 1.5),
            TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(1), hours: 8),
        ]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(1)))
        // The drive alone for an hour (2 s), then both, then the flight: 18 s in all.
        assertBlocks(TripTimeline(tripMap: map, clock: clock(for: map, isQuickLayovers: true)).blocks, are: [
            (.driving, 0, 2.0 / 18, nil), (.flying, 2.0 / 18, 1, nil),
        ])
    }

    func test_blocks_aTripWithNoLength_isEmpty() {
        let leg = MapLeg(id: "f", kind: .flight,
                         origin: FactsTestData.mark("A", latitude: 0, longitude: 0),
                         destination: FactsTestData.mark("B", latitude: 0, longitude: 1),
                         start: start, end: start, flightNumber: nil)
        let map = TripMap(mode: .onTrip, legs: [leg], home: nil, span: DateInterval(start: start, end: start), tripDays: nil)
        XCTAssertEqual(TripTimeline(tripMap: map, clock: TripReplayClock(span: map.span)).blocks, [])
    }

    // MARK: - The waits' lengths

    func test_lengthLabel_hoursUnder48_daysFrom48() {
        XCTAssertEqual(TripTimeline.lengthLabel(for: 20 * 3600), "20h")
        XCTAssertEqual(TripTimeline.lengthLabel(for: 47 * 3600), "47h")
        XCTAssertEqual(TripTimeline.lengthLabel(for: 48 * 3600), "2d")
        XCTAssertEqual(TripTimeline.lengthLabel(for: 96 * 3600), "4d")
    }

    func test_lengthLabel_underHalfAnHour_isNil() {
        XCTAssertNil(TripTimeline.lengthLabel(for: 20 * 60))
    }

    func test_lengthLabel_everySharedCase_matches() throws {
        let labels = try TripMapFixtures.replayCases().waitLabels
        XCTAssertFalse(labels.isEmpty)
        for wait in labels {
            XCTAssertEqual(TripTimeline.lengthLabel(for: wait.hours * 3600), wait.label, "\(wait.hours) h: \(wait.note)")
        }
    }
}
