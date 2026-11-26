//
//  FactsWording.swift
//  CrewLuve
//
//  The facts' sentences (Stage 2 spec §4, §5): milestones, what's below, the sky, distance and landing. The family's
//  own times, in `calendar.timeZone`, are marked "L", and a city's follow its name (time labels design §2). Totals and
//  the recap are in FactsWording+Trip.swift.
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

    /// The tall stop's list: "Crossed into Kansas · 1:12 PM L". A best guess reads "about": "Out over the Pacific ·
    /// about 4:05 PM L" (best guesses design §2).
    static func listLine(for milestone: Milestone, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "\(eventTitle(for: milestone.kind)) · \(clock(of: milestone, calendar: calendar, locale: locale))"
    }

    /// What an event was, on its own: "Crossed into Kansas", "Out over the Atlantic", "Halfway", "Closest to home,
    /// 40 mi". The latest event's banner shows it large (latest event design §1).
    static func eventTitle(for kind: Milestone.Kind) -> String {
        switch kind {
        case .crossedInto(let name): "Crossed into \(name)"
        case .outOver(let name): "Out over \(name)"
        case .halfway: "Halfway"
        case .closestToHome(let miles): "Closest to home, \(miles) mi"
        }
    }

    /// When an event was, under it in the banner: "Just now" in its first minute, then "12 min ago". A best guess
    /// says so: "About now", "About 12 min ago". At a moment of the replay, where "ago" means nothing, its clock
    /// time: "10:37 AM L", "About 10:37 AM L".
    static func eventWhen(_ milestone: Milestone, at date: Date, isReplay: Bool = false,
                          calendar: Calendar = .current, locale: Locale = .current) -> String {
        let about = milestone.isEstimate ? "About " : ""
        if isReplay {
            return about + ClockLabel.yours(milestone.time, calendar: calendar, locale: locale)
        }
        guard let minutes = minutesSince(milestone.time, at: date) else { return milestone.isEstimate ? "About now" : "Just now" }
        return "\(about)\(TripMapWording.minutesText(minutes)) ago"
    }

    /// The widest "when" the banner shows: a best guess more than ten hours ago. A replay's clock time, "About 10:37
    /// AM L", is narrower. The key to the two planes goes by it, so it doesn't move while the same event shows (which
    /// plane design §2).
    static let widestEventWhen = "About 88 h 88 min ago"

    /// The banner as VoiceOver reads it: "Latest: crossed into Canada, 12 minutes ago.", "Latest: halfway, about
    /// 40 minutes ago.", or at a moment of the replay "Latest: crossed into Canada, at 10:37 AM your time."
    static func spokenLatestEvent(_ milestone: Milestone, at date: Date, isReplay: Bool = false,
                                  calendar: Calendar = .current, locale: Locale = .current) -> String {
        let what: String
        switch milestone.kind {
        case .closestToHome(let miles): what = "closest to home, \(miles) miles"
        default:
            let title = eventTitle(for: milestone.kind)
            what = title.prefix(1).lowercased() + title.dropFirst()
        }
        let about = milestone.isEstimate ? "about " : ""
        let when: String
        if isReplay {
            when = "at \(about)\(ClockLabel.spoken(ClockLabel.yours(milestone.time, calendar: calendar, locale: locale)))"
        } else if let minutes = minutesSince(milestone.time, at: date) {
            when = "\(about)\(TripMapWording.spokenMinutes(minutes)) ago"
        } else {
            when = milestone.isEstimate ? "about now" : "just now"
        }
        return "Latest: \(what), \(when)."
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

    /// "Passes 40 mi from home at 1:05 PM L", or "Closest to home was 40 mi at 1:05 PM L" once it's passed. Where
    /// nobody saw the real plane the time is a best guess: "Passes 40 mi from home at about 1:05 PM L".
    static func closestToHome(miles: Int, at time: Date, now: Date, isEstimate: Bool = false,
                              calendar: Calendar = .current, locale: Locale = .current) -> String {
        let clock = (isEstimate ? "about " : "") + ClockLabel.yours(time, calendar: calendar, locale: locale)
        return time > now ? "Passes \(miles) mi from home at \(clock)" : "Closest to home was \(miles) mi at \(clock)"
    }

    /// In place of what's below, a real plane still on the ground at its departure airport after the plan's takeoff
    /// time: "Still on the ground in Rockford" (which plane design §4).
    static func stillOnGround(in airport: AirportMark) -> String {
        "Still on the ground in \(airport.name)"
    }

    /// In place of what's below, a real plane seen at its gate before the plan's takeoff: "On the ground in
    /// Louisville" (live or scheduled design §4.2).
    static func onTheGround(in airport: AirportMark) -> String {
        "On the ground in \(airport.name)"
    }

    /// In place of what's below, a flight by the schedule alone before its takeoff: "Scheduled to take off about 3:14
    /// PM L" (live or scheduled design §4.2). The time is the gate's plus the map's own taxi allowance, so "about".
    static func scheduledTakeoff(at time: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "Scheduled to take off about \(ClockLabel.yours(time, calendar: calendar, locale: locale))"
    }

    /// The second line of the facts' first row for a flight by the schedule alone, as the schedule's plane's popup
    /// says it (live or scheduled design §4.1).
    static let notTrackedLines = ["Shown where the schedule has it", TripMapWording.mayBeAtGate]

    /// In place of what's below, a real plane back on the ground at its departure airport after an air return:
    /// "Returned to Rockford" (air return design §3).
    static func returned(to airport: AirportMark) -> String {
        "Returned to \(airport.name)"
    }

    /// "Landed in Anchorage": the real plane is down, and not yet at the gate (landed before the gate design §3).
    static func landed(in airport: AirportMark) -> String {
        "Landed in \(airport.name)"
    }

    /// The list's tag on the flight between its gates once its real plane is down.
    static let landedTag = "Landed"

    // MARK: - The real plane (Stage 3 spec §8)

    /// Under what's below, while the real plane is out of tracking range: "Last tracked near Montréal · 12 min ago",
    /// by a city of a million or more, else "Last tracked over Québec · 12 min ago", else "Last tracked 12 min ago".
    /// It's the one line that says the place above it is worked out (best guesses design §2). "Tracked", never
    /// "seen": it's the receivers that lose the plane, not air traffic control, and a family shouldn't fear it's
    /// missing.
    static func lastSeenLine(_ place: Geography.Place?, near city: Geography.City?, ago: TimeInterval) -> String {
        let time = "\(TripMapWording.minutesText(minutes(ago: ago))) ago"
        if let city { return "Last tracked near \(city.name) · \(time)" }
        if let place { return "Last tracked over \(place.name) · \(time)" }
        return "Last tracked \(time)"
    }

    /// Where a plane that's out of sight was last seen, for VoiceOver's sentence: "near Montréal" by a city of a
    /// million or more, else "over Québec", else how long ago, "2 hours ago".
    static func lastSeen(_ place: Geography.Place?, near city: Geography.City?, ago: TimeInterval) -> String {
        if let city { return "near \(city.name)" }
        if let place { return "over \(place.name)" }
        return "\(TripMapWording.spokenMinutes(minutes(ago: ago))) ago"
    }

    /// The tag on the flight between its gates, in the list: "In the air now", or "In the air" at a moment of
    /// the replay (best guesses design §4).
    static func inTheAir(isReplay: Bool) -> String {
        isReplay ? "In the air" : "In the air now"
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

    /// The sky row: "Sunset in 25 min", or "Sunrise at 6:38 AM L" an hour or more ahead.
    static func cockpitEvent(_ event: SkyFacts.SunEvent, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        // Under 59 minutes as a countdown, so it never reads "in 60 min".
        let when = event.time.timeIntervalSince(now) < 59 * 60
            ? "in \(minutes(from: now, to: event.time)) min"
            : "at \(ClockLabel.yours(event.time, calendar: calendar, locale: locale))"
        return "\(name(of: event.kind)) \(when)"
    }

    /// After the sky row's sunrise or sunset, how much sooner or later the cockpit sees it than the ground below
    /// (time labels design §3.6): "The pilot sees it 31 min before the ground does". Nil when they see it about
    /// together.
    static func cockpitGap(_ event: SkyFacts.SunEvent) -> String? {
        guard let gap = event.peopleBelowGap else { return nil }
        let side = event.kind == .sunset ? "after" : "before"
        return "The pilot sees it \(Int((gap / 60).rounded())) min \(side) the ground does"
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

    /// On the ground at an airport: "sunrise at 7:02 AM Cologne".
    static func groundSun(_ kind: SkyFacts.SunEvent.Kind, at time: Date, in zone: TimeZone, city: String,
                          locale: Locale = .current) -> String {
        "\(kind == .sunrise ? "sunrise" : "sunset") at \(ClockLabel.place(time, in: zone, city: city, locale: locale))"
    }

    // MARK: - Distance (§4.6)

    /// "2,140 mi flown · 1,960 to go".
    static func distance(flownMiles: Int, toGoMiles: Int, locale: Locale = .current) -> String {
        "\(number(flownMiles, locale: locale)) mi flown · \(number(toGoMiles, locale: locale)) to go"
    }

    /// "2,788 mi to go": a real plane still at its departure airport has flown nothing yet (which plane design §4).
    static func toGo(miles: Int, locale: Locale = .current) -> String {
        "\(number(miles, locale: locale)) mi to go"
    }

    /// "2,788 mi flown": the whole of it, once the real plane is down (landed before the gate design §3).
    static func flown(miles: Int, locale: Locale = .current) -> String {
        "\(number(miles, locale: locale)) mi flown"
    }

    /// "Halfway at 4:12 PM L", or with the real plane's estimate "Halfway at about 12:05 PM L" (Stage 3 spec §8).
    static func halfway(at time: Date, isEstimate: Bool = false, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "Halfway at \(isEstimate ? "about " : "")\(ClockLabel.yours(time, calendar: calendar, locale: locale))"
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

    /// "84°F and clear at takeoff": the weather in the hour the flight left (time labels design §3.3).
    static func takeoffWeather(_ forecast: LandingForecast) -> String {
        "\(forecast.temperature) and \(forecast.condition) at takeoff"
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

    /// "lands 4:05 PM Dubai", or in the family's time, "lands 4:05 PM L", when the destination keeps it or its zone
    /// isn't known. With the real plane's estimate, "lands about 3:52 PM Dubai" (Stage 3 spec §9).
    static func lands(_ leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let about = TripMapWording.about(leg)
        if let there = leg.destination.timeZone, !ClockLabel.keepsTheSameClock(there, as: calendar.timeZone, at: leg.end) {
            return "lands \(about)\(ClockLabel.place(leg.end, in: there, city: leg.destination.name, locale: locale))"
        }
        return "lands \(about)\(ClockLabel.yours(leg.end, calendar: calendar, locale: locale))"
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

    /// "1:12 PM L", or "about 1:12 PM L" for a best guess.
    private static func clock(of milestone: Milestone, calendar: Calendar, locale: Locale) -> String {
        (milestone.isEstimate ? "about " : "") + ClockLabel.yours(milestone.time, calendar: calendar, locale: locale)
    }

    /// The minutes from `time` to `date`, to the nearest, held to a year. Nil under a minute.
    private static func minutesSince(_ time: Date, at date: Date) -> Int? {
        let seconds = date.timeIntervalSince(time)
        guard seconds >= 60 else { return nil }
        return Int(min((seconds / 60).rounded(), 365 * 24 * 60))
    }

    /// Whole minutes for a length of time, held from a minute to a year, so one that can't be right never
    /// overflows.
    private static func minutes(ago: TimeInterval) -> Int {
        let asked = (ago / 60).rounded()
        return asked.isNaN ? 1 : Int(min(max(asked, 1), 365 * 24 * 60))
    }

    /// `text` without the spaces around it, or nil when nothing is left.
    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
