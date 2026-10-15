//
//  SolarPosition.swift
//  CrewLuve
//
//  Decides whether the sun is up at a place and time, for the flight route
//  map's day/night sky and the sun or moon icon at each airport.
//

import Foundation

/// The sun's position from the Astronomical Almanac's low-precision solar
/// coordinates — the algorithm the U.S. Naval Observatory publishes as
/// "Approximate Solar Coordinates" (https://aa.usno.navy.mil/faq/sun_approx).
/// It is good to about an arcminute, which away from the poles puts sunrise
/// and sunset within a minute of the Observatory's own times.
nonisolated enum SolarPosition {

    /// The altitude of the sun's center at sunrise and sunset, in degrees:
    /// its upper edge on the horizon, after atmospheric refraction.
    private static let sunriseAltitude = -0.833

    /// Noon UTC on January 1, 2000 (Julian date 2451545.0), the epoch the
    /// solar coordinates count days from.
    private static let j2000 = Date(timeIntervalSince1970: 946_728_000)

    /// Whether the sun is above the horizon at `date`, for a place given in
    /// degrees with longitude positive east.
    static func isSunUp(latitude: Double, longitude: Double, at date: Date) -> Bool {
        altitude(latitude: latitude, longitude: longitude, at: date) > sunriseAltitude
    }

    /// The altitude of the sun's center above the horizon, in degrees.
    private static func altitude(latitude: Double, longitude: Double, at date: Date) -> Double {
        let days = date.timeIntervalSince(j2000) / 86_400
        let meanLongitude = 280.460 + 0.9856474 * days
        let meanAnomaly = radians(357.528 + 0.9856003 * days)
        let eclipticLongitude = radians(meanLongitude + 1.915 * sin(meanAnomaly) + 0.020 * sin(2 * meanAnomaly))
        let obliquity = radians(23.439 - 0.0000004 * days)

        let declination = asin(sin(obliquity) * sin(eclipticLongitude))
        let rightAscension = degrees(atan2(cos(obliquity) * sin(eclipticLongitude), cos(eclipticLongitude)))

        // Apparent minus mean solar time: how far the real sun runs ahead of
        // or behind clock time, between about −14 and +16 minutes in a year.
        let equationOfTimeMinutes = 4 * (meanLongitude - rightAscension).remainder(dividingBy: 360)

        // The sun crosses Greenwich near 12:00 UTC and moves west 15° an hour.
        let utcHours = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86_400) / 3_600
        let subsolarLongitude = -15 * (utcHours - 12) - equationOfTimeMinutes / 4
        let hourAngle = radians(longitude - subsolarLongitude)

        let latitudeRadians = radians(latitude)
        let sineOfAltitude = sin(latitudeRadians) * sin(declination)
            + cos(latitudeRadians) * cos(declination) * cos(hourAngle)
        return degrees(asin(sineOfAltitude))
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}
