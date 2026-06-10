//
//  SharedDaylightTests.swift
//  CrewluvTests
//
//  Tests for the shared-daylight window math used by the sun dial.
//

import XCTest
@testable import Crewluv

final class SharedDaylightTests: XCTestCase {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private let newYork = TimeZone(identifier: "America/New_York")!

    private func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int, _ minute: Int,
        in timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        )
        return calendar.date(from: components)!
    }

    // MARK: - Tokyo pilot, Eastern home (the +13h case)

    func test_windows_tokyoPilotEasternHome_returnsMorningSliverAndEveningWindow() {
        // Pilot in Tokyo: daylight 04:22–18:54 JST.
        // Home in New York (EDT): daylight 05:30–20:30.
        // On the home clock, pilot daylight spans 15:22 → 05:54 (wrapping
        // midnight), so the shared windows are 05:30–05:54 and 15:22–20:30.
        let result = SharedDaylight.windows(
            pilotSunrise: date(2026, 6, 10, 4, 22, in: tokyo),
            pilotSunset: date(2026, 6, 10, 18, 54, in: tokyo),
            homeSunrise: date(2026, 6, 10, 5, 30, in: newYork),
            homeSunset: date(2026, 6, 10, 20, 30, in: newYork),
            homeTimeZone: newYork
        )

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].startHour, 5.5, accuracy: 0.001)
        XCTAssertEqual(result[0].endHour, 5.9, accuracy: 0.001)
        XCTAssertEqual(result[1].startHour, 15.0 + 22.0 / 60.0, accuracy: 0.001)
        XCTAssertEqual(result[1].endHour, 20.5, accuracy: 0.001)
    }

    func test_windows_pilotTimesFromDifferentCalendarDay_returnsSameWindows() {
        // Weather fetches can return sun times for different calendar days
        // depending on timezone alignment. Only wall-clock time should matter.
        let sameDay = SharedDaylight.windows(
            pilotSunrise: date(2026, 6, 10, 4, 22, in: tokyo),
            pilotSunset: date(2026, 6, 10, 18, 54, in: tokyo),
            homeSunrise: date(2026, 6, 10, 5, 30, in: newYork),
            homeSunset: date(2026, 6, 10, 20, 30, in: newYork),
            homeTimeZone: newYork
        )
        let shiftedDay = SharedDaylight.windows(
            pilotSunrise: date(2026, 6, 11, 4, 22, in: tokyo),
            pilotSunset: date(2026, 6, 11, 18, 54, in: tokyo),
            homeSunrise: date(2026, 6, 10, 5, 30, in: newYork),
            homeSunset: date(2026, 6, 10, 20, 30, in: newYork),
            homeTimeZone: newYork
        )

        XCTAssertEqual(sameDay, shiftedDay)
    }

    // MARK: - Same timezone

    func test_windows_sameTimezoneNestedDaylight_returnsSingleWindow() {
        // Pilot daylight 06:00–18:00 sits inside home daylight 05:00–19:00.
        let result = SharedDaylight.windows(
            pilotSunrise: date(2026, 6, 10, 6, 0, in: newYork),
            pilotSunset: date(2026, 6, 10, 18, 0, in: newYork),
            homeSunrise: date(2026, 6, 10, 5, 0, in: newYork),
            homeSunset: date(2026, 6, 10, 19, 0, in: newYork),
            homeTimeZone: newYork
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].startHour, 6.0, accuracy: 0.001)
        XCTAssertEqual(result[0].endHour, 18.0, accuracy: 0.001)
    }

    // MARK: - No overlap

    func test_windows_pilotDaylightEntirelyInHomeNight_returnsEmpty() {
        // January: New York is EST (UTC-5), Tokyo is UTC+9, 14 hours apart.
        // Pilot daylight 08:00–16:00 JST is 18:00–02:00 on the home clock,
        // entirely outside home daylight 07:00–17:00.
        let result = SharedDaylight.windows(
            pilotSunrise: date(2026, 1, 10, 8, 0, in: tokyo),
            pilotSunset: date(2026, 1, 10, 16, 0, in: tokyo),
            homeSunrise: date(2026, 1, 10, 7, 0, in: newYork),
            homeSunset: date(2026, 1, 10, 17, 0, in: newYork),
            homeTimeZone: newYork
        )

        XCTAssertEqual(result, [])
    }

    // MARK: - Degenerate boundaries

    func test_windows_touchingBoundaries_returnsNoZeroLengthWindow() {
        // Pilot daylight on the home clock ends exactly when home daylight
        // begins — a zero-length touch is not a window.
        // Tokyo is 13h ahead of EDT: pilot 04:00–16:30 JST is 15:00–03:30
        // on the home clock; home daylight starts at 03:30.
        let result = SharedDaylight.windows(
            pilotSunrise: date(2026, 6, 10, 4, 0, in: tokyo),
            pilotSunset: date(2026, 6, 10, 16, 30, in: tokyo),
            homeSunrise: date(2026, 6, 10, 3, 30, in: newYork),
            homeSunset: date(2026, 6, 10, 14, 0, in: newYork),
            homeTimeZone: newYork
        )

        XCTAssertEqual(result, [])
    }
}
