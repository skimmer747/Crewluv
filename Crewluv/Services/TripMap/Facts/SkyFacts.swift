//
//  SkyFacts.swift
//  CrewLuve
//
//  The sky from the cockpit (Stage 2 spec §4.5): sunrises and sunsets at cruise, when the people below see them,
//  chasing the sun, and the moon. Also the next sunrise or sunset on the ground at an airport (§5.3).
//

import CoreLocation

nonisolated enum SkyFacts {

    nonisolated struct SunEvent: Equatable, Sendable {
        nonisolated enum Kind: Equatable, Sendable {
            case sunrise, sunset
        }

        let kind: Kind
        let time: Date
        /// How much later than the people below the cockpit sees a sunset, or how much earlier a sunrise, when that's
        /// 5 minutes or more.
        let peopleBelowGap: TimeInterval?
    }

    /// Which part of the day stretches while the plane chases the sun.
    nonisolated enum Chase: Equatable, Sendable {
        case morning, afternoon
    }

    nonisolated struct Moon: Equatable, Sendable {
        let phase: LunarPhase
        let isUp: Bool
    }

    /// The sun's centre at sunrise and sunset on the ground, after refraction.
    static let groundHorizon = SolarPosition.sunriseAltitude
    /// The schedule's height in the air. It also stands in for a real plane that's climbing or coming down.
    static let cruiseAltitudeFeet: Double = 35_000
    /// A real plane's own height counts while it's at its cruise: between these, in feet. Lower, it's on its way
    /// up or down, and the sunrises and sunsets ahead are seen from the cruise it's climbing to. Higher can't be
    /// right.
    static let cruiseAltitudesFeet: ClosedRange<Double> = 25_000...60_000
    /// The sun's altitude at a cockpit sunrise or sunset at cruise: about −3.86°.
    static let cockpitHorizon = groundHorizon - horizonDip(feet: cruiseAltitudeFeet)
    /// Under this, the cockpit and the people below see it at about the same time.
    static let peopleBelowThreshold: TimeInterval = 5 * 60
    /// Chasing the sun: its hour angle at the plane moving at under half its usual 15° an hour.
    static let chaseRate: Double = 7.5

    private static let sampleStep: TimeInterval = 120
    private static let groundSearch: TimeInterval = 3 * 3600
    private static let groundStep: TimeInterval = 600

    /// How far below level the horizon lies from `feet` up, in degrees: 1.76′ × √(height in m).
    static func horizonDip(feet: Double) -> Double {
        1.76 / 60 * (max(feet, 0) * 0.3048).squareRoot()
    }

    /// The sun's altitude at a cockpit sunrise or sunset on `leg` (Stage 3 spec §8): from the height the real
    /// plane was last seen at, while it's in the air at its cruise, and from 35,000 ft otherwise.
    static func cockpitHorizon(for leg: MapLeg) -> Double {
        guard let live = leg.flight?.live, live.state == .airborne, let fix = live.fix, !fix.isOnGround,
              let feet = fix.altitudeFeet, cruiseAltitudesFeet.contains(feet) else { return cockpitHorizon }
        return groundHorizon - horizonDip(feet: feet)
    }

    /// The sun's altitude at the plane, in degrees: where its record has it, else where the schedule does.
    static func sunAltitude(on leg: MapLeg, at date: Date) -> Double {
        let here = leg.coursePosition(at: date)
        return SolarPosition.altitude(latitude: here.latitude, longitude: here.longitude, at: date)
    }

    // MARK: - Sunrise and sunset from the cockpit

    /// The sunrises and sunsets the cockpit sees while the flight is in the air, in order: sampled every 2 minutes
    /// and narrowed to 5 seconds. A flight with a record is followed along its real path, at its real times.
    static func sunEvents(on leg: MapLeg) -> [SunEvent] {
        guard leg.kind == .flight, let window = leg.airborne else { return [] }
        let horizon = cockpitHorizon(for: leg)
        let height: (Date) -> Double = { sunAltitude(on: leg, at: $0) - horizon }
        var times: [Date] = []
        var time = window.start
        while time < window.end {
            times.append(time)
            time += sampleStep
        }
        times.append(window.end)
        let heights = times.map(height)
        return times.indices.dropFirst().compactMap { index -> SunEvent? in
            let isRising = heights[index - 1] <= 0 && heights[index] > 0
            let isSetting = heights[index - 1] > 0 && heights[index] <= 0
            guard isRising || isSetting else { return nil }
            let eventTime = crossing(of: height, from: times[index - 1], to: times[index], isRising: isRising, precision: 5)
            return SunEvent(kind: isRising ? .sunrise : .sunset, time: eventTime,
                            peopleBelowGap: peopleBelowGap(at: leg.coursePosition(at: eventTime), cockpitTime: eventTime, isSunrise: isRising))
        }
    }

    // MARK: - Chasing the sun

    /// While the sun's up at the plane and its hour angle there changes at under 7.5° an hour: the afternoon, or the
    /// morning while the sun is east of the plane's meridian.
    static func chase(on leg: MapLeg, at date: Date) -> Chase? {
        guard leg.kind == .flight, let window = leg.airborne,
              window.contains(date), sunAltitude(on: leg, at: date) > cockpitHorizon(for: leg) else { return nil }
        let here = leg.coursePosition(at: date)
        let soon = leg.coursePosition(at: date.addingTimeInterval(60))
        let degreesPerHour = 15 + wrapped(soon.longitude - here.longitude) * 60
        guard abs(degreesPerHour) < chaseRate else { return nil }
        let hourAngle = wrapped(here.longitude - SolarPosition.subsolarPoint(at: date).longitude)
        return hourAngle < 0 ? .morning : .afternoon
    }

    // MARK: - The moon

    /// The moon while the sun is below the cockpit's horizon, or nil in daylight.
    static func moon(on leg: MapLeg, at date: Date) -> Moon? {
        guard leg.kind == .flight, sunAltitude(on: leg, at: date) <= cockpitHorizon(for: leg) else { return nil }
        let here = leg.coursePosition(at: date)
        return Moon(phase: MoonPosition.phase(at: date),
                    isUp: MoonPosition.altitude(latitude: here.latitude, longitude: here.longitude, at: date) > 0)
    }

    // MARK: - On the ground

    /// The next sunrise or sunset on the ground at `place` within a day of `date`: sampled every 10 minutes and narrowed
    /// to 30 seconds.
    static func nextGroundSunEvent(at place: CLLocationCoordinate2D, after date: Date) -> (kind: SunEvent.Kind, time: Date)? {
        let height = groundHeight(at: place)
        var earlier = date
        var before = height(earlier)
        while earlier.timeIntervalSince(date) < 86_400 {
            let later = earlier.addingTimeInterval(groundStep)
            let after = height(later)
            if (before <= 0) != (after <= 0) {
                let isRising = after > 0
                let kind: SunEvent.Kind = isRising ? .sunrise : .sunset
                return (kind, crossing(of: height, from: earlier, to: later, isRising: isRising, precision: 30))
            }
            earlier = later
            before = after
        }
        return nil
    }

    // MARK: - Private

    /// The sun's height above the ground's sunrise altitude at `place`.
    private static func groundHeight(at place: CLLocationCoordinate2D) -> (Date) -> Double {
        { SolarPosition.altitude(latitude: place.latitude, longitude: place.longitude, at: $0) - groundHorizon }
    }

    /// When the ground under a cockpit event sees the same event. A sunset reaches the ground first and a sunrise
    /// last, so it steps that way until the sun's on the other side of the ground's horizon, up to 3 hours.
    private static func peopleBelowGap(at point: CLLocationCoordinate2D, cockpitTime: Date, isSunrise: Bool) -> TimeInterval? {
        let height = groundHeight(at: point)
        let step = isSunrise ? sampleStep : -sampleStep
        var near = cockpitTime
        while abs(near.timeIntervalSince(cockpitTime)) < groundSearch {
            let far = near.addingTimeInterval(step)
            if height(far) > 0 {
                let ground = isSunrise
                    ? crossing(of: height, from: near, to: far, isRising: true, precision: 5)
                    : crossing(of: height, from: far, to: near, isRising: false, precision: 5)
                let gap = abs(cockpitTime.timeIntervalSince(ground))
                return gap >= peopleBelowThreshold ? gap : nil
            }
            near = far
        }
        return nil
    }

    /// Narrows a change of sign in `height` between two moments to `precision` seconds, and gives the middle.
    private static func crossing(of height: (Date) -> Double, from earlier: Date, to later: Date,
                                 isRising: Bool, precision: TimeInterval) -> Date {
        var low = earlier
        var high = later
        while high.timeIntervalSince(low) > precision {
            let middle = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
            if (height(middle) > 0) == isRising {
                high = middle
            } else {
                low = middle
            }
        }
        return low.addingTimeInterval(high.timeIntervalSince(low) / 2)
    }

    /// A longitude difference within −180..<180.
    private static func wrapped(_ degrees: Double) -> Double {
        let shifted = (degrees + 180).truncatingRemainder(dividingBy: 360)
        return (shifted < 0 ? shifted + 360 : shifted) - 180
    }
}
