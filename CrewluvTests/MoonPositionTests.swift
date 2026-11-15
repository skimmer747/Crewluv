//
//  MoonPositionTests.swift
//  CrewluvTests
//
//  The moon's phase and position (Stage 2 spec §4.5). The phase dates are the middles of each phase in November
//  2026, by the mean cycle the website uses; the full moon is within two hours of the real one (Nov 24, 14:53 UTC).
//

import XCTest
@testable import Crewluv

final class MoonPositionTests: XCTestCase {

    func test_phase_atTheMiddleOfEachPhase_isThatPhase() {
        let middles: [(String, LunarPhase)] = [
            ("2026-11-09T21:58:00Z", .new),
            ("2026-11-13T14:33:00Z", .waxingCrescent),
            ("2026-11-17T07:09:00Z", .firstQuarter),
            ("2026-11-20T23:44:00Z", .waxingGibbous),
            ("2026-11-24T16:20:00Z", .full),
            ("2026-11-28T08:55:00Z", .waningGibbous),
            ("2026-12-02T01:31:00Z", .lastQuarter),
            ("2026-12-05T18:06:00Z", .waningCrescent),
        ]
        for (iso, phase) in middles {
            XCTAssertEqual(MoonPosition.phase(at: FactsTestData.date(iso)), phase, iso)
        }
    }

    func test_cycle_atTheKnownNewMoon_isZero() {
        XCTAssertEqual(MoonPosition.cycle(at: MoonPosition.knownNewMoon), 0, accuracy: 1e-12)
    }

    func test_subLunarPoint_staysWithinTheMoonsReach() {
        let start = FactsTestData.date("2026-01-01T00:00:00Z")
        for day in 0..<60 {
            let point = MoonPosition.subLunarPoint(at: start.addingTimeInterval(Double(day) * 86_400))
            XCTAssertLessThanOrEqual(abs(point.latitude), 29)
            XCTAssertLessThanOrEqual(abs(point.longitude), 180)
        }
    }

    func test_altitude_aWaxingGibbousEveningOverCologne_isHigh() {
        let altitude = MoonPosition.altitude(latitude: 50.87, longitude: 7.14, at: FactsTestData.date("2026-11-20T21:00:00Z"))
        XCTAssertEqual(altitude, 44.3, accuracy: 2)
    }

    func test_altitude_atDawnOverTheNetherlands_isBelowTheHorizon() {
        let altitude = MoonPosition.altitude(latitude: 51.79, longitude: 4.25, at: FactsTestData.date("2026-11-14T06:38:00Z"))
        XCTAssertEqual(altitude, -45.5, accuracy: 2)
    }
}
