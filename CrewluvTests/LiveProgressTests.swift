//
//  LiveProgressTests.swift
//  CrewluvTests
//
//  The real plane at a moment (Stage 3 spec §5, §7.1), held to the shared cases in Fixtures/TripMap.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LiveProgressTests: XCTestCase {

    private let nauticalMile = TripMapFixtures.nauticalMile

    private func assertEqual(_ date: Date?, _ expected: Date?, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let date, let expected else {
            XCTAssertEqual(date == nil, expected == nil, name, file: file, line: line)
            return
        }
        XCTAssertEqual(date.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.05, name, file: file, line: line)
    }

    private func assertEqual(_ distance: Double?, nauticalMiles expected: Double?, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let distance, let expected else {
            XCTAssertEqual(distance == nil, expected == nil, name, file: file, line: line)
            return
        }
        XCTAssertEqual(distance / nauticalMile, expected, accuracy: 0.01, name, file: file, line: line)
    }

    private func assertEqual(_ place: CLLocationCoordinate2D?, _ expected: [Double]?, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let place, let expected else {
            XCTAssertEqual(place == nil, expected == nil, name, file: file, line: line)
            return
        }
        XCTAssertEqual(place.latitude, expected[0], accuracy: 0.0001, name, file: file, line: line)
        XCTAssertEqual(place.longitude, expected[1], accuracy: 0.0001, name, file: file, line: line)
    }

    func test_constants_matchTheSharedCases() throws {
        let constants = try TripMapFixtures.liveCases().constants
        XCTAssertEqual(LiveProgress.freshFor, constants.freshSeconds)
        XCTAssertEqual(LiveProgress.airportRadius, constants.airportRadiusNm * nauticalMile)
    }

    func test_moments_everySharedCase_matches() throws {
        let cases = try TripMapFixtures.liveCases()
        XCTAssertFalse(cases.flights.isEmpty)
        for flightCase in cases.flights {
            let made = try cases.made(flightCase)
            XCTAssertFalse(flightCase.moments.isEmpty, flightCase.name)
            for moment in flightCase.moments {
                let name = "\(flightCase.name) at \(moment.at)"
                let progress = LiveProgress(plan: made.plan, path: made.path, record: made.record, flight: made.flight, at: moment.at)
                XCTAssertEqual(progress.phase.rawValue, moment.phase, name)
                assertEqual(progress.touchdown, moment.touchdown, name)
                assertEqual(progress.liveArrival, moment.liveArrival, name)
                XCTAssertEqual(progress.gapMinutes, moment.gapMinutes, name)
                XCTAssertEqual(progress.label.map(TripMapWording.liveLabel), moment.label, name)
                assertEqual(progress.planeDistance, nauticalMiles: moment.planeAlongNm, name)
                assertEqual(progress.plane, moment.plane, name)
                assertEqual(progress.ghostDistance, nauticalMiles: moment.ghostAlongNm, name)
                assertEqual(progress.ghostDistance.map(made.path.point(atDistance:)), moment.ghost, name)
                assertEqual(progress.start, moment.start, name)
                assertEqual(progress.end, moment.end, name)
            }
        }
    }

    func test_gapMinutes_everySharedCase_roundsHalvesAwayFromZero() throws {
        let gaps = try TripMapFixtures.liveCases().gaps
        XCTAssertFalse(gaps.isEmpty)
        for gap in gaps {
            XCTAssertEqual(LiveProgress.gapMinutes(aheadBy: gap.aheadSeconds), gap.gapMinutes, "\(gap.aheadSeconds) s")
        }
    }

    func test_gapMinutes_aTimeThatCantBeRight_isHeldToAYear_andDoesntOverflow() {
        XCTAssertEqual(LiveProgress.gapMinutes(aheadBy: 1e30), 525_600)
        XCTAssertEqual(LiveProgress.gapMinutes(aheadBy: -1e30), -525_600)
        XCTAssertEqual(LiveProgress.gapMinutes(aheadBy: .infinity), 525_600)
        XCTAssertEqual(LiveProgress.gapMinutes(aheadBy: -.infinity), -525_600)
        XCTAssertEqual(LiveProgress.gapMinutes(aheadBy: .nan), 0)
        XCTAssertEqual(LiveProgress.gapMinutes(aheadBy: 525_599 * 60), 525_599)
    }

    func test_estimatedPlane_agreesWithTheRecord() throws {
        let cases = try TripMapFixtures.liveCases()
        var checked = 0
        for flightCase in cases.flights {
            let made = try cases.made(flightCase)
            for moment in flightCase.moments where moment.phase == LiveProgress.Phase.estimated.rawValue {
                let progress = LiveProgress(plan: made.plan, path: made.path, record: made.record, flight: made.flight, at: moment.at)
                let record = try XCTUnwrap(made.record)
                XCTAssertEqual(try XCTUnwrap(progress.planeDistance), record.distance(at: moment.at), accuracy: 0.001, flightCase.name)
                XCTAssertEqual(try XCTUnwrap(progress.touchdown).timeIntervalSince1970, record.touchdown.timeIntervalSince1970, accuracy: 0.001)
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 0)
    }
}
