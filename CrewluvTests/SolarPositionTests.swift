//
//  SolarPositionTests.swift
//  CrewluvTests
//
//  Checks the route map's day/night math against U.S. Naval Observatory
//  sunrise and sunset times.
//

import XCTest
@testable import Crewluv

final class SolarPositionTests: XCTestCase {

    // Louisville International (SDF), as queried from the USNO API:
    // https://aa.usno.navy.mil/api/rstt/oneday?date=2026-10-15&coords=38.1746,-85.7382&tz=-4
    private let latitude = 38.1746
    private let longitude = -85.7382

    /// USNO reports these times for UTC−4 (EDT).
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: -4 * 3600)!
        return calendar
    }()

    // MARK: - Helpers

    private func easternTime(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: components)!
    }

    /// The first whole minute after `start`, within a day, at which
    /// `isSunUp` changes to `sunUp`.
    private func firstChange(toSunUp sunUp: Bool, after start: Date) -> Date? {
        var wasSunUp = SolarPosition.isSunUp(latitude: latitude, longitude: longitude, at: start)
        for minute in 1...(24 * 60) {
            let time = start.addingTimeInterval(TimeInterval(minute * 60))
            let isSunUp = SolarPosition.isSunUp(latitude: latitude, longitude: longitude, at: time)
            if isSunUp == sunUp, wasSunUp != sunUp { return time }
            wasSunUp = isSunUp
        }
        return nil
    }

    /// Asserts that, scanning the local day, `isSunUp` turns true within
    /// three minutes of `sunrise` and false within three minutes of `sunset`.
    private func assertSunUpChanges(
        sunrise: Date,
        sunset: Date,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let midnight = calendar.startOfDay(for: sunrise)
        let computedSunrise = try XCTUnwrap(firstChange(toSunUp: true, after: midnight), file: file, line: line)
        let computedSunset = try XCTUnwrap(firstChange(toSunUp: false, after: midnight), file: file, line: line)

        XCTAssertEqual(
            computedSunrise.timeIntervalSince(sunrise) / 60, 0, accuracy: 3,
            "Minutes from the USNO sunrise", file: file, line: line
        )
        XCTAssertEqual(
            computedSunset.timeIntervalSince(sunset) / 60, 0, accuracy: 3,
            "Minutes from the USNO sunset", file: file, line: line
        )
    }

    // MARK: - Louisville sunrise and sunset
    //
    // The equation of time has opposite signs on these dates (about −9 and
    // +14 minutes), so an error in its sign or size can't cancel out.

    func test_isSunUp_louisvilleOnOctober15_matchesNavalObservatoryWithinThreeMinutes() throws {
        try assertSunUpChanges(
            sunrise: easternTime(2026, 10, 15, 7, 52),
            sunset: easternTime(2026, 10, 15, 19, 5)
        )
    }

    func test_isSunUp_louisvilleOnMarch15_matchesNavalObservatoryWithinThreeMinutes() throws {
        try assertSunUpChanges(
            sunrise: easternTime(2026, 3, 15, 7, 54),
            sunset: easternTime(2026, 3, 15, 19, 50)
        )
    }
}
