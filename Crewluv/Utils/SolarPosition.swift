//
//  SolarPosition.swift
//  CrewLuve
//
//  Where the sun is: whether it's up at a place, its height there, and the
//  point it's straight above, for the trip map's night shading.
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

    /// The point on the earth with the sun straight overhead at `date`: its
    /// latitude (the sun's declination) in radians, and its longitude in
    /// degrees, positive east, within -180...180.
    static func subsolarPoint(at date: Date) -> (declination: Double, longitude: Double) {
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
        let longitude = (-15 * (utcHours - 12) - equationOfTimeMinutes / 4).remainder(dividingBy: 360)
        return (declination, longitude)
    }

    /// The altitude of the sun's center above the horizon, in degrees: negative below it.
    static func altitude(latitude: Double, longitude: Double, at date: Date) -> Double {
        let sun = subsolarPoint(at: date)
        let hourAngle = radians(longitude - sun.longitude)
        let latitudeRadians = radians(latitude)
        let sineOfAltitude = sin(latitudeRadians) * sin(sun.declination)
            + cos(latitudeRadians) * cos(sun.declination) * cos(hourAngle)
        return degrees(asin(sineOfAltitude))
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}
