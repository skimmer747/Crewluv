//
//  SharedDaylight.swift
//  CrewLuve
//
//  Computes the wall-clock windows when the pilot and the home user
//  are both in daylight, expressed on the home user's 24-hour clock.
//

import Foundation

enum SharedDaylight {

    /// A span on a 24-hour clock face, in fractional hours within [0, 24).
    /// `startHour` is always less than `endHour`; windows never wrap midnight
    /// because home daylight cannot span midnight on the home clock.
    struct Window: Equatable, Sendable {
        let startHour: Double
        let endHour: Double
    }

    /// Returns the windows (0, 1, or 2) during which both locations are in
    /// daylight, positioned by home wall-clock time. Only the wall-clock
    /// hour and minute of each date matter — the calendar day each value
    /// happens to fall on is ignored, so sun times fetched for different
    /// days still produce correct windows.
    static func windows(
        pilotSunrise: Date,
        pilotSunset: Date,
        homeSunrise: Date,
        homeSunset: Date,
        homeTimeZone: TimeZone
    ) -> [Window] {
        let homeStart = fractionalHour(of: homeSunrise, in: homeTimeZone)
        let homeEnd = fractionalHour(of: homeSunset, in: homeTimeZone)

        // Home daylight never wraps midnight on the home clock; anything else
        // is degenerate data (polar day/night edge cases) — show no windows.
        guard homeStart < homeEnd else { return [] }

        let pilotStart = fractionalHour(of: pilotSunrise, in: homeTimeZone)
        let pilotEnd = fractionalHour(of: pilotSunset, in: homeTimeZone)

        // Pilot daylight can wrap midnight on the home clock; split it into
        // non-wrapping segments before intersecting.
        let pilotSegments: [(start: Double, end: Double)] = pilotStart <= pilotEnd
            ? [(pilotStart, pilotEnd)]
            : [(pilotStart, 24), (0, pilotEnd)]

        let oneSecond = 1.0 / 3600.0
        return pilotSegments
            .compactMap { segment -> Window? in
                let start = max(segment.start, homeStart)
                let end = min(segment.end, homeEnd)
                guard end - start > oneSecond else { return nil }
                return Window(startHour: start, endHour: end)
            }
            .sorted { $0.startHour < $1.startHour }
    }

    private static func fractionalHour(of date: Date, in timeZone: TimeZone) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return Double(components.hour ?? 0)
            + Double(components.minute ?? 0) / 60
            + Double(components.second ?? 0) / 3600
    }
}
