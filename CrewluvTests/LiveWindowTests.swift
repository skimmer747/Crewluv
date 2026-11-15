//
//  LiveWindowTests.swift
//  CrewluvTests
//
//  When a flight's live data is asked for (Stage 3 spec §10.2), held to the shared cases in Fixtures/TripMap.
//

import XCTest
@testable import Crewluv

final class LiveWindowTests: XCTestCase {

    func test_constants_matchTheSharedCases() throws {
        let constants = try TripMapFixtures.liveCases().constants
        XCTAssertEqual(LiveWindow.opensBefore, constants.windowOpensMinutesBefore * 60)
        XCTAssertEqual(LiveWindow.closesAfter, constants.windowClosesHoursAfter * 3600)
        XCTAssertEqual(LiveWindow.keepsFor, constants.windowKeepsMinutes * 60)
        XCTAssertEqual(LiveWindow.endsAfter, constants.windowEndsHoursAfter * 3600)
    }

    func test_isOpen_everySharedCase_matches() throws {
        let windows = try TripMapFixtures.liveCases().windows
        XCTAssertFalse(windows.isEmpty)
        for window in windows {
            let flight = window.flight.map { LiveFlight($0, trail: $0.trail) }
            XCTAssertEqual(LiveWindow.isOpen(departure: window.departure, arrival: window.arrival, flight: flight, at: window.at),
                           window.isOpen, window.name)
        }
    }
}
