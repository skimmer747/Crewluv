//
//  MoonPosition.swift
//  CrewLuve
//
//  Where the moon is (Stage 2 spec §4.5): its phase from the mean cycle, as the website's src/time/moon.ts works it
//  out, and the point it's straight above, ported from crewlu-globe's subLunarPoint (Paul Schlyter's method, good to
//  a degree or two, which is plenty to say whether it's up).
//

import Foundation

nonisolated enum MoonPosition {

    /// The mean length of the moon's cycle, new moon to new moon, in days.
    static let synodicMonth = 29.530588853

    /// A new moon to count from: 6 January 2000 at 18:14 UTC.
    static let knownNewMoon = Date(timeIntervalSince1970: 947_182_440)

    /// How far through its cycle the moon is: 0 at new moon, 0.5 at full.
    static func cycle(at date: Date) -> Double {
        let cycles = date.timeIntervalSince(knownNewMoon) / 86_400 / synodicMonth
        return cycles - cycles.rounded(.down)
    }

    /// Eight equal parts of the cycle, each centred on its own point.
    static func phase(at date: Date) -> LunarPhase {
        LunarPhase(rawValue: Int((cycle(at: date) * 8 + 0.5).rounded(.down)) % 8) ?? .new
    }

    /// The point on the earth with the moon straight overhead, in degrees, longitude positive east.
    static func subLunarPoint(at date: Date) -> (latitude: Double, longitude: Double) {
        let days = date.timeIntervalSince1970 / 86_400 + 2_440_587.5 - 2_451_543.5
        let node = revolution(125.1228 - 0.0529538083 * days)
        let inclination = 5.1454
        let perigee = revolution(318.0634 + 0.1643573223 * days)
        let meanDistance = 60.2666
        let eccentricity = 0.0549
        let meanAnomaly = revolution(115.3654 + 13.0649929509 * days)

        var eccentricAnomaly = meanAnomaly
            + degrees(eccentricity * sin(radians(meanAnomaly)) * (1 + eccentricity * cos(radians(meanAnomaly))))
        for _ in 0..<4 {
            eccentricAnomaly -= (eccentricAnomaly - degrees(eccentricity * sin(radians(eccentricAnomaly))) - meanAnomaly)
                / (1 - eccentricity * cos(radians(eccentricAnomaly)))
        }

        let x = meanDistance * (cos(radians(eccentricAnomaly)) - eccentricity)
        let y = meanDistance * (1 - eccentricity * eccentricity).squareRoot() * sin(radians(eccentricAnomaly))
        let trueAnomaly = revolution(degrees(atan2(y, x)))
        let distance = (x * x + y * y).squareRoot()
        let argument = radians(trueAnomaly + perigee)

        let xh = distance * (cos(radians(node)) * cos(argument) - sin(radians(node)) * sin(argument) * cos(radians(inclination)))
        let yh = distance * (sin(radians(node)) * cos(argument) + cos(radians(node)) * sin(argument) * cos(radians(inclination)))
        let zh = distance * sin(argument) * sin(radians(inclination))
        let eclipticLongitude = radians(revolution(degrees(atan2(yh, xh))))
        let eclipticLatitude = atan2(zh, (xh * xh + yh * yh).squareRoot())

        let obliquity = radians(23.4393 - 3.563e-7 * days)
        let xe = cos(eclipticLongitude) * cos(eclipticLatitude)
        let ye = sin(eclipticLongitude) * cos(eclipticLatitude) * cos(obliquity) - sin(eclipticLatitude) * sin(obliquity)
        let ze = sin(eclipticLongitude) * cos(eclipticLatitude) * sin(obliquity) + sin(eclipticLatitude) * cos(obliquity)
        let rightAscension = revolution(degrees(atan2(ye, xe)))
        let declination = degrees(atan2(ze, (xe * xe + ye * ye).squareRoot()))

        let daysSinceJ2000 = date.timeIntervalSince1970 / 86_400 + 2_440_587.5 - 2_451_545.0
        let siderealTime = revolution(280.46061837 + 360.98564736629 * daysSinceJ2000)
        let longitude = (rightAscension - siderealTime + 540).truncatingRemainder(dividingBy: 360) - 180
        return (declination, longitude)
    }

    /// The moon's altitude above the horizon at a place, in degrees. Its parallax, about a degree, is left out.
    static func altitude(latitude: Double, longitude: Double, at date: Date) -> Double {
        let moon = subLunarPoint(at: date)
        let sine = sin(radians(latitude)) * sin(radians(moon.latitude))
            + cos(radians(latitude)) * cos(radians(moon.latitude)) * cos(radians(longitude - moon.longitude))
        return degrees(asin(min(max(sine, -1), 1)))
    }

    // MARK: - Private

    /// An angle within 0..<360.
    private static func revolution(_ degrees: Double) -> Double {
        let remainder = degrees.truncatingRemainder(dividingBy: 360)
        return remainder < 0 ? remainder + 360 : remainder
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}
