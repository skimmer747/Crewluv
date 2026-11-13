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

    // MARK: - The subsolar point (moving map spec §7.1, the night shading)

    private func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func test_subsolarPoint_atTheJuneSolstice_isOverTheTropicOfCancer() {
        let sun = SolarPosition.subsolarPoint(at: utcDate(2026, 6, 21, 8, 24))
        XCTAssertEqual(sun.declination * 180 / .pi, 23.44, accuracy: 0.05)
    }

    func test_subsolarPoint_atTheMarchEquinox_isOverTheEquator() {
        let sun = SolarPosition.subsolarPoint(at: utcDate(2026, 3, 20, 14, 46))
        XCTAssertEqual(sun.declination * 180 / .pi, 0, accuracy: 0.05)
    }

    /// In mid-October the sun runs about 14 minutes ahead of the clock, so at noon UTC it has already passed Greenwich.
    func test_subsolarPoint_atNoonUTCInMidOctober_isAFewDegreesWestOfGreenwich() {
        let sun = SolarPosition.subsolarPoint(at: utcDate(2026, 10, 15, 12, 0))
        XCTAssertEqual(sun.longitude, -3.55, accuracy: 0.2)
    }

    func test_subsolarPoint_longitude_staysWithinTheMap() {
        let start = utcDate(2026, 1, 1, 0, 0)
        for hours in stride(from: 0, to: 24 * 365, by: 7) {
            let longitude = SolarPosition.subsolarPoint(at: start.addingTimeInterval(Double(hours) * 3600)).longitude
            XCTAssertLessThanOrEqual(abs(longitude), 180)
        }
    }

    func test_altitude_underTheSubsolarPoint_isStraightUp() {
        let date = utcDate(2026, 11, 13, 17, 0)
        let sun = SolarPosition.subsolarPoint(at: date)
        let altitude = SolarPosition.altitude(latitude: sun.declination * 180 / .pi, longitude: sun.longitude, at: date)
        XCTAssertEqual(altitude, 90, accuracy: 0.01)
    }
}
