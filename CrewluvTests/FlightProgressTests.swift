//
//  FlightProgressTests.swift
//  CrewluvTests
//
//  The schedule's plane (moving map spec §7.3), held to the shared cases in Fixtures/TripMap.
//

import XCTest
@testable import Crewluv

final class FlightProgressTests: XCTestCase {

    func test_constants_matchTheSharedCases() throws {
        let constants = try TripMapFixtures.progressCases().constants
        XCTAssertEqual(FlightProgress.taxiOutAllowance, constants.taxiOutMinutes * 60)
        XCTAssertEqual(FlightProgress.taxiInAllowance, constants.taxiInMinutes * 60)
        XCTAssertEqual(FlightProgress.shortestCruise, constants.shortestCruiseMinutes * 60)
    }

    func test_scheduledFraction_everySharedCase_matches() throws {
        let cases = try TripMapFixtures.progressCases().scheduleCases
        XCTAssertFalse(cases.isEmpty)
        for scheduleCase in cases {
            let fraction = FlightProgress.scheduledFraction(departure: scheduleCase.departure, arrival: scheduleCase.arrival, at: scheduleCase.at)
            XCTAssertEqual(fraction, scheduleCase.fraction, accuracy: 1e-9, scheduleCase.name)
        }
    }

    func test_airborneWindow_longFlight_leavesRoomToTaxi() throws {
        let departure = Date(timeIntervalSince1970: 1_800_000_000)
        let window = try XCTUnwrap(FlightProgress.airborneWindow(departure: departure, arrival: departure.addingTimeInterval(8 * 3600)))
        XCTAssertEqual(window.start, departure.addingTimeInterval(15 * 60))
        XCTAssertEqual(window.end, departure.addingTimeInterval(8 * 3600 - 7 * 60))
    }

    func test_airborneWindow_arrivalBeforeDeparture_isNil() {
        let departure = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertNil(FlightProgress.airborneWindow(departure: departure, arrival: departure.addingTimeInterval(-60)))
    }
}
