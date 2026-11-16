//
//  FactsWording.swift
//  CrewLuve
//
//  The facts' sentences (Stage 2 spec §4, §5): milestones, what's below, the sky, distance and landing. Times are the
//  family's own, in `calendar.timeZone`, unless the words say "there". Totals and the recap are in
//  FactsWording+Trip.swift.
//

import Foundation

nonisolated enum FactsWording {

    // MARK: - Milestones (§4.3)

    /// The headline: "Just crossed into Kansas", "Out over the Atlantic", "Halfway!", "Closest to home: 40 mi, wave!".
    static func headline(for kind: Milestone.Kind) -> String {
        switch kind {
        case .crossedInto(let name): "Just crossed into \(name)"
        case .outOver(let name): "Out over \(name)"
        case .halfway: "Halfway!"
        case .closestToHome(let miles): "Closest to home: \(miles) mi, wave!"
        }
    }

    /// The tall stop's list: "Crossed into Kansas · 1:12 PM".
    static func listLine(for milestone: Milestone, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = TripMapWording.clockTime(milestone.time, in: calendar.timeZone, locale: locale)
        switch milestone.kind {
        case .crossedInto(let name): return "Crossed into \(name) · \(time)"
        case .outOver(let name): return "Out over \(name) · \(time)"
        case .halfway: return "Halfway · \(time)"
        case .closestToHome(let miles): return "Closest to home, \(miles) mi · \(time)"
        }
    }

    /// "UPS207 · Louisville → Cologne", or the cities alone without a flight number.
    static func flightTitle(_ leg: MapLeg) -> String {
        let route = "\(leg.origin.name) → \(leg.destination.name)"
        return leg.flightNumber.map { "\($0) · \(route)" } ?? route
    }

    // MARK: - Below (§4.1)

    /// "Over Kansas", "Over Québec, near Montréal".
    static func below(_ place: Geography.Place, near city: Geography.City?) -> String {
        city.map { "Over \(place.name), near \($0.name)" } ?? "Over \(place.name)"
    }

    /// "Passes 40 mi from home at 1:05 PM", or "Closest to home was 40 mi at 1:05 PM" once it's passed. Ahead of a
    /// real plane the time is its estimate: "Passes 40 mi from home at about 1:05 PM" (Stage 3 spec §9).
    static func closestToHome(miles: Int, at time: Date, now: Date, isEstimate: Bool = false,
                              calendar: Calendar = .current, locale: Locale = .current) -> String {
        let clock = TripMapWording.clockTime(time, in: calendar.timeZone, locale: locale)
        guard time > now else { return "Closest to home was \(miles) mi at \(clock)" }
        return "Passes \(miles) mi from home at \(isEstimate ? "about " : "")\(clock)"
    }

    // MARK: - The real plane (Stage 3 spec §8)

    /// The headline and the "below" row while the real plane is an estimate: "Estimated · last seen near Montréal".
    static func estimated(lastSeen: String) -> String {
        "Estimated · last seen \(lastSeen)"
    }

    /// Where an estimated plane was last seen: "near Montréal" by a city of a million or more, else "over Québec",
    /// else how long ago, "2 h ago". `isSpoken` writes that out for VoiceOver: "2 hours ago".
    static func lastSeen(_ place: Geography.Place?, near city: Geography.City?, ago: TimeInterval, isSpoken: Bool = false) -> String {
        if let city { return "near \(city.name)" }
        if let place { return "over \(place.name)" }
        // Held from a minute to a year, so a time that can't be right never overflows.
        let asked = (ago / 60).rounded()
        let minutes = asked.isNaN ? 1 : Int(min(max(asked, 1), 365 * 24 * 60))
        return "\(isSpoken ? TripMapWording.spokenMinutes(minutes) : TripMapWording.minutesText(minutes)) ago"
    }

    /// The plane's row: "Boeing 767-300 · N370UP". An unknown type code shows as itself, and a missing type or
    /// registration is left out. Nil with neither.
    static func aircraft(typeCode: String?, registration: String?) -> String? {
        let parts = [typeCode.flatMap(nonEmpty).map(AircraftTypeNames.name(for:)), registration.flatMap(nonEmpty)].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "35,000 ft · 540 mph": the real plane's height to the nearest 100 ft and its speed over the ground to the
    /// nearest 10 mph, each where the plane sent one that could be right. Nil with neither.
    static func heightAndSpeed(altitudeFeet: Double?, groundSpeedKnots: Double?, locale: Locale = .current) -> String? {
        let height = altitudeFeet.flatMap { feet in
            believedHeightsFeet.contains(feet) ? "\(number(Int((feet / 100).rounded()) * 100, locale: locale)) ft" : nil
        }
        let speed = groundSpeedKnots.flatMap { knots -> String? in
            guard believedSpeedsKnots.contains(knots) else { return nil }
            let milesPerHour = knots * GreatCircle.metersPerNauticalMile / GreatCircle.metersPerMile
            return "\(number(Int((milesPerHour / 10).rounded()) * 10, locale: locale)) mph"
        }
        let parts = [height, speed].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// A height or a speed outside these is left out: no airliner sends one, and a number that can't be right
    /// mustn't reach the screen.
    static let believedHeightsFeet: ClosedRange<Double> = 0...60_000
    static let believedSpeedsKnots: ClosedRange<Double> = 0...800

    /// The credit under the facts wherever a flight with live data shows: adsb.lol's data is under the ODbL.
    static let liveCredit = "Live position: adsb.lol"
    /// The credit as VoiceOver reads it.
    static let spokenLiveCredit = "Live position from adsb.lol."

    // MARK: - The sky (§4.5)

    /// The headline: "Sunset from the cockpit in 25 min".
    static func cockpitCountdown(_ event: SkyFacts.SunEvent, now: Date) -> String {
        "\(name(of: event.kind)) from the cockpit in \(minutes(from: now, to: event.time)) min"
    }

    /// The sky row: "Sunset in 25 min, about 12 min after the people below", or "Sunrise at 6:38 AM" an hour or more
    /// ahead.
    static func cockpitEvent(_ event: SkyFacts.SunEvent, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        // Under 59 minutes as a countdown, so it never reads "in 60 min".
        let when = event.time.timeIntervalSince(now) < 59 * 60
            ? "in \(minutes(from: now, to: event.time)) min"
            : "at \(TripMapWording.clockTime(event.time, in: calendar.timeZone, locale: locale))"
        guard let gap = event.peopleBelowGap else { return "\(name(of: event.kind)) \(when)" }
        let side = event.kind == .sunset ? "after" : "before"
        return "\(name(of: event.kind)) \(when), about \(Int((gap / 60).rounded())) min \(side) the people below"
    }

    static func flyingInto(_ kind: SkyFacts.SunEvent.Kind) -> String {
        kind == .sunset ? "Flying into the night" : "Flying into the morning"
    }

    static func chase(_ chase: SkyFacts.Chase) -> String {
        "Chasing the sun: their \(chase == .afternoon ? "afternoon" : "morning") is stretching"
    }

    /// "Waxing gibbous moon, up", "Full moon, below the horizon".
    static func moon(_ moon: SkyFacts.Moon) -> String {
        "\(moonName(moon.phase)), \(moon.isUp ? "up" : "below the horizon")"
    }

    static func moonName(_ phase: LunarPhase) -> String {
        switch phase {
        case .new: "New moon"
        case .waxingCrescent: "Waxing crescent moon"
        case .firstQuarter: "First quarter moon"
        case .waxingGibbous: "Waxing gibbous moon"
        case .full: "Full moon"
        case .waningGibbous: "Waning gibbous moon"
        case .lastQuarter: "Last quarter moon"
        case .waningCrescent: "Waning crescent moon"
        }
    }

    /// On the ground at an airport: "sunrise at 7:02 AM there".
    static func groundSun(_ kind: SkyFacts.SunEvent.Kind, at time: Date, in zone: TimeZone, locale: Locale = .current) -> String {
        "\(kind == .sunrise ? "sunrise" : "sunset") at \(TripMapWording.clockTime(time, in: zone, locale: locale)) there"
    }

    // MARK: - Distance (§4.6)

    /// "2,140 mi flown · 1,960 to go".
    static func distance(flownMiles: Int, toGoMiles: Int, locale: Locale = .current) -> String {
        "\(number(flownMiles, locale: locale)) mi flown · \(number(toGoMiles, locale: locale)) to go"
    }

    /// "Halfway at 4:12 PM", or with the real plane's estimate "Halfway at about 12:05 PM" (Stage 3 spec §8).
    static func halfway(at time: Date, isEstimate: Bool = false, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "Halfway at \(isEstimate ? "about " : "")\(TripMapWording.clockTime(time, in: calendar.timeZone, locale: locale))"
    }

    /// "Averaging about 510 mph", to the nearest 10.
    static func averageSpeed(milesPerHour: Double) -> String {
        "Averaging about \(Int((milesPerHour / 10).rounded()) * 10) mph"
    }

    /// A comparison in the middle of a line: "like driving coast to coast".
    static func midLine(_ phrase: String) -> String {
        phrase.prefix(1).lowercased() + phrase.dropFirst()
    }

    // MARK: - Where they're headed (§4.7)

    /// "48°F and rain on landing".
    static func weather(_ forecast: LandingForecast) -> String {
        "\(forecast.temperature) and \(forecast.condition) on landing"
    }

    /// "6 hours ahead of you", "5½ hours behind you", "½ hour ahead of you", or nil when the clocks match.
    static func timeDifference(from zone: TimeZone, to yours: TimeZone, at date: Date) -> String? {
        let seconds = zone.secondsFromGMT(for: date) - yours.secondsFromGMT(for: date)
        guard seconds != 0 else { return nil }
        let quarters = abs(seconds) / 900
        let whole = quarters / 4
        let part = ["", "¼", "½", "¾"][quarters % 4]
        let amount = whole == 0 ? part : "\(whole)\(part)"
        let unit = quarters <= 4 ? "hour" : "hours"
        return "\(amount) \(unit) \(seconds > 0 ? "ahead of" : "behind") you"
    }

    /// "lands 4:05 PM there", or in the family's time when the destination keeps it or its zone isn't known. With
    /// the real plane's estimate, "lands about 3:52 PM there" (Stage 3 spec §9).
    static func lands(_ leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let about = TripMapWording.about(leg)
        if let there = leg.destination.timeZone,
           there.secondsFromGMT(for: leg.end) != calendar.timeZone.secondsFromGMT(for: leg.end) {
            return "lands \(about)\(TripMapWording.clockTime(leg.end, in: there, locale: locale)) there"
        }
        return "lands \(about)\(TripMapWording.clockTime(leg.end, in: calendar.timeZone, locale: locale))"
    }

    // MARK: - Helpers

    static func number(_ value: Int, locale: Locale = .current) -> String {
        value.formatted(.number.locale(locale))
    }

    /// Whole minutes until `time`, rounded up, and at least 1.
    private static func minutes(from now: Date, to time: Date) -> Int {
        max(1, Int((time.timeIntervalSince(now) / 60).rounded(.up)))
    }

    private static func name(of kind: SkyFacts.SunEvent.Kind) -> String {
        kind == .sunrise ? "Sunrise" : "Sunset"
    }

    /// `text` without the spaces around it, or nil when nothing is left.
    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
