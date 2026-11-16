//
//  AircraftTypeNamesTests.swift
//  CrewluvTests
//
//  An aircraft's name from its type code (Stage 3 spec §8).
//

import XCTest
@testable import Crewluv

final class AircraftTypeNamesTests: XCTestCase {

    func test_name_theFreightersAPilotsFamilySees() {
        XCTAssertEqual(AircraftTypeNames.name(for: "B763"), "Boeing 767-300")
        XCTAssertEqual(AircraftTypeNames.name(for: "B748"), "Boeing 747-8")
        XCTAssertEqual(AircraftTypeNames.name(for: "B744"), "Boeing 747-400")
        XCTAssertEqual(AircraftTypeNames.name(for: "B752"), "Boeing 757-200")
        XCTAssertEqual(AircraftTypeNames.name(for: "A306"), "Airbus A300-600")
        XCTAssertEqual(AircraftTypeNames.name(for: "MD11"), "McDonnell Douglas MD-11")
        // One code for the 777-200LR and the 777 Freighter, which is built on it.
        XCTAssertEqual(AircraftTypeNames.name(for: "B77L"), "Boeing 777-200")
    }

    func test_name_anAirliner() {
        XCTAssertEqual(AircraftTypeNames.name(for: "B738"), "Boeing 737-800")
        XCTAssertEqual(AircraftTypeNames.name(for: "A20N"), "Airbus A320neo")
        XCTAssertEqual(AircraftTypeNames.name(for: "E75L"), "Embraer 175")
        XCTAssertEqual(AircraftTypeNames.name(for: "CRJ9"), "Bombardier CRJ900")
    }

    func test_name_anUnknownCode_showsAsItself() {
        XCTAssertEqual(AircraftTypeNames.name(for: "ZZZZ"), "ZZZZ")
        XCTAssertEqual(AircraftTypeNames.name(for: "GLF6"), "GLF6")
    }

    func test_name_readsACodeInAnyCase_withSpacesAroundIt() {
        XCTAssertEqual(AircraftTypeNames.name(for: " b763 "), "Boeing 767-300")
        XCTAssertEqual(AircraftTypeNames.name(for: "zzzz"), "ZZZZ")
    }
}
