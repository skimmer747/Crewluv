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

    // MARK: - From a fraction to a time (Stage 2 spec §4.2)

    func test_scheduledTime_alongTheWindow_isSteady() {
        let departure = FactsTestData.equinox
        let arrival = departure.addingTimeInterval(202 * 60)
        XCTAssertEqual(FlightProgress.scheduledTime(atFraction: 0, departure: departure, arrival: arrival), departure.addingTimeInterval(15 * 60))
        XCTAssertEqual(FlightProgress.scheduledTime(atFraction: 0.5, departure: departure, arrival: arrival), departure.addingTimeInterval(105 * 60))
        XCTAssertEqual(FlightProgress.scheduledTime(atFraction: 1, departure: departure, arrival: arrival), departure.addingTimeInterval(195 * 60))
    }

    func test_scheduledTime_isTheInverseOfScheduledFraction() throws {
        let departure = FactsTestData.equinox
        let arrival = departure.addingTimeInterval(8 * 3600)
        let time = try XCTUnwrap(FlightProgress.scheduledTime(atFraction: 0.37, departure: departure, arrival: arrival))
        XCTAssertEqual(FlightProgress.scheduledFraction(departure: departure, arrival: arrival, at: time), 0.37, accuracy: 1e-9)
    }

    func test_scheduledTime_aShortBlock_usesTheWholeBlock() {
        let departure = FactsTestData.equinox
        let arrival = departure.addingTimeInterval(20 * 60)
        XCTAssertEqual(FlightProgress.scheduledTime(atFraction: 0.5, departure: departure, arrival: arrival), departure.addingTimeInterval(10 * 60))
    }

    func test_scheduledTime_noBlock_isNil() {
        XCTAssertNil(FlightProgress.scheduledTime(atFraction: 0.5, departure: FactsTestData.equinox, arrival: FactsTestData.equinox))
    }

    func test_mapLegTime_aDrive_isSteadyFromStartToEnd() {
        let drive = MapLeg(id: "d", kind: .drive,
                           origin: FactsTestData.mark("LEX", latitude: 38.04, longitude: -84.61),
                           destination: FactsTestData.mark("SDF", latitude: 38.17, longitude: -85.74),
                           start: FactsTestData.equinox, end: FactsTestData.equinox.addingTimeInterval(3600), flightNumber: nil)
        XCTAssertEqual(drive.time(atFraction: 0.25), FactsTestData.equinox.addingTimeInterval(900))
    }
}
