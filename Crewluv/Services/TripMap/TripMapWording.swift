//
//  TripMapWording.swift
//  CrewLuve
//
//  Every sentence the trip map shows or speaks (moving map spec §5, §6, §14). Times are the family's own, in
//  `calendar.timeZone`, unless the words say "there".
//

import Foundation

nonisolated enum TripMapWording {

    // MARK: - The card's chips

    /// The chips on the card's map: the top one and the bottom one (moving map spec §5.1, §5.2).
    static func cardChips(for tripMap: TripMap, at date: Date, calendar: Calendar = .current, locale: Locale = .current) -> (top: String?, bottom: String?) {
        switch tripMap.mode {
        case .inFlight:
            return (nil, tripMap.currentLeg.map { landingCountdown(for: $0, now: date) })
        case .onTrip:
            let place = tripMap.pilotLocation(at: date).map { placeChip(for: $0, at: date, locale: locale) }
            let next = tripMap.nextFlight(after: date).map { nextDepartureChip(for: $0, now: date, calendar: calendar, locale: locale) }
            return (place, next)
        case .nextTrip:
            return (nextTripChip(startingAt: tripMap.span.start, now: date, calendar: calendar, locale: locale), nil)
        }
    }

    /// "Cologne · 9:14 PM there".
    static func placeChip(for place: AirportMark, at now: Date, locale: Locale = .current) -> String {
        guard let zone = place.timeZone else { return place.name }
        return "\(place.name) · \(clockTime(now, in: zone, locale: locale)) there"
    }

    /// "Next: Dubai, tomorrow 6:10 AM".
    static func nextDepartureChip(for leg: MapLeg, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let day = dayPhrase(for: leg.start, now: now, calendar: calendar, locale: locale)
        return "Next: \(leg.destination.name), \(day) \(clockTime(leg.start, in: calendar.timeZone, locale: locale))"
    }

    /// "Home · next trip Wednesday".
    static func nextTripChip(startingAt start: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "Home · next trip \(dayPhrase(for: start, now: now, calendar: calendar, locale: locale))"
    }

    /// "Landing in 2 h 10 min", to the gate arrival.
    static func landingCountdown(for leg: MapLeg, now: Date) -> String {
        let minutes = Int((leg.end.timeIntervalSince(now) / 60).rounded(.up))
        guard minutes > 0 else { return "Landing now" }
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "Landing in \(rest) min" }
        if rest == 0 { return "Landing in \(hours) h" }
        return "Landing in \(hours) h \(rest) min"
    }

    // MARK: - Landing

    /// "Lands Cologne 9:30 PM · 3:30 PM your time", or one time when the destination keeps the family's.
    static func landingLine(for leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let yours = clockTime(leg.end, in: calendar.timeZone, locale: locale)
        guard let there = arrivalLocalClock(for: leg, calendar: calendar, locale: locale) else {
            return "Lands \(leg.destination.name) \(yours)"
        }
        return "Lands \(leg.destination.name) \(there) · \(yours) your time"
    }

    /// "Lands 3:30 PM", for the card's bar.
    static func landsAt(for leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "Lands \(clockTime(leg.end, in: calendar.timeZone, locale: locale))"
    }

    /// "9:30 PM in Cologne", or nil when the destination keeps the family's time.
    static func arrivalLocalTime(for leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String? {
        arrivalLocalClock(for: leg, calendar: calendar, locale: locale).map { "\($0) in \(leg.destination.name)" }
    }

    // MARK: - The bar under the map

    /// The bar's words on the ground (moving map spec §5.3): the day, cities and miles so far mid-trip; the dates,
    /// cities and total miles for a trip ahead. Empty in flight, where the bar shows the flight.
    static func statsItems(for tripMap: TripMap, at date: Date, dayNumber: Int?, totalDays: Int?,
                           calendar: Calendar = .current, locale: Locale = .current) -> [String] {
        let cities = destinations(of: tripMap.legs, leavingOut: Set([tripMap.home?.code].compactMap { $0 }))
        switch tripMap.mode {
        case .inFlight:
            return []
        case .onTrip:
            var items: [String] = []
            if let dayNumber, let totalDays { items.append("Day \(dayNumber) of \(totalDays)") }
            if cities.count > 0 { items.append(cities.count == 1 ? "1 city" : "\(cities.count) cities") }
            items.append("\(milesText(milesFlown(by: date, on: tripMap.legs), locale: locale)) so far")
            return items
        case .nextTrip:
            return [dateRange(from: tripMap.span.start, to: tripMap.span.end, calendar: calendar, locale: locale),
                    cities.joined(separator: " · "),
                    milesText(totalMiles(of: tripMap.legs), locale: locale)].filter { !$0.isEmpty }
        }
    }

    /// Miles flown by `date`, counting the part of a flight that's in the air.
    static func milesFlown(by date: Date, on legs: [MapLeg]) -> Int {
        let meters = legs.filter { $0.kind == .flight }.reduce(0) { $0 + $1.distance * $1.progress(at: date) }
        return Int((meters / GreatCircle.metersPerMile).rounded())
    }

    static func totalMiles(of legs: [MapLeg]) -> Int {
        let meters = legs.filter { $0.kind == .flight }.reduce(0) { $0 + $1.distance }
        return Int((meters / GreatCircle.metersPerMile).rounded())
    }

    /// The airports the trip's flights reach, in order, each once, home left out.
    static func destinations(of legs: [MapLeg], leavingOut homeCodes: Set<String>) -> [String] {
        var seen = homeCodes
        return legs.filter { $0.kind == .flight }.map(\.destination.code).filter { seen.insert($0).inserted }
    }

    /// "Fri–Mon", "Fri" for one day, or "Nov 13–Nov 20" when the trip runs a week or more.
    static func dateRange(from start: Date, to end: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
        if days >= 6 {
            let monthDay = style(calendar: calendar, locale: locale).month(.abbreviated).day()
            return "\(start.formatted(monthDay))–\(end.formatted(monthDay))"
        }
        let weekday = style(calendar: calendar, locale: locale).weekday(.abbreviated)
        guard !calendar.isDate(start, inSameDayAs: end) else { return start.formatted(weekday) }
        return "\(start.formatted(weekday))–\(end.formatted(weekday))"
    }

    /// "today", "tomorrow", a weekday within the week, else "Nov 20".
    static func dayPhrase(for date: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "today"
        case 1: return "tomorrow"
        case 2...6: return date.formatted(style(calendar: calendar, locale: locale).weekday(.wide))
        default: return date.formatted(style(calendar: calendar, locale: locale).month(.abbreviated).day())
        }
    }

    // MARK: - The full-screen map

    /// The pill at the top: "UPS207 · In flight", "Driving to Louisville", "Day 2 of 4" or "Next trip".
    static func topPill(for tripMap: TripMap, at date: Date, dayNumber: Int?, totalDays: Int?) -> String {
        if let leg = tripMap.legInMotion(at: date) {
            switch leg.kind {
            case .flight: return [leg.flightNumber, "In flight"].compactMap { $0 }.joined(separator: " · ")
            case .drive: return "Driving to \(leg.destination.name)"
            }
        }
        if tripMap.mode == .nextTrip, date < tripMap.span.start { return "Next trip" }
        if let dayNumber, let totalDays { return "Day \(dayNumber) of \(totalDays)" }
        return "Trip map"
    }

    /// The panel's first line: the landing line in the air, else where they are.
    static func panelHeadline(for tripMap: TripMap, at date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        if let leg = tripMap.legInMotion(at: date) {
            return leg.kind == .flight ? landingLine(for: leg, calendar: calendar, locale: locale) : "Driving to \(leg.destination.name)"
        }
        if tripMap.mode == .nextTrip, date < tripMap.span.start {
            return nextTripChip(startingAt: tripMap.span.start, now: date, calendar: calendar, locale: locale)
        }
        return tripMap.pilotLocation(at: date).map { placeChip(for: $0, at: date, locale: locale) } ?? ""
    }

    /// "Fri 9:14 PM", under the timeline and as the slider's VoiceOver value.
    static func timelineTime(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        date.formatted(style(calendar: calendar, locale: locale).weekday(.abbreviated).hour().minute())
    }

    // MARK: - VoiceOver

    /// The card as one sentence (moving map spec §14).
    static func cardSummary(for tripMap: TripMap, now: Date, pilotName: String,
                            calendar: Calendar = .current, locale: Locale = .current) -> String {
        switch tripMap.mode {
        case .inFlight:
            guard let leg = tripMap.currentLeg else { return "Trip map" }
            let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
            return "\(lead) \(leg.destination.name), landing at \(clockTime(leg.end, in: calendar.timeZone, locale: locale)) your time. Estimated from the schedule."
        case .onTrip:
            var parts = ["Trip map."]
            if let place = tripMap.pilotLocation(at: now) { parts.append("\(pilotName) is in \(place.name).") }
            if let next = tripMap.nextFlight(after: now) {
                parts.append("\(nextDepartureChip(for: next, now: now, calendar: calendar, locale: locale)).")
            }
            return parts.joined(separator: " ")
        case .nextTrip:
            let cities = destinationNames(of: tripMap.legs, leavingOut: Set([tripMap.home?.code].compactMap { $0 }))
            let day = dayPhrase(for: tripMap.span.start, now: now, calendar: calendar, locale: locale)
            return "Map of the next trip, \(day): \(cities.joined(separator: ", "))."
        }
    }

    // MARK: - Private

    /// The names of the cities the trip's flights reach, in order, each once, home left out — for VoiceOver.
    private static func destinationNames(of legs: [MapLeg], leavingOut homeCodes: Set<String>) -> [String] {
        var seen = homeCodes
        return legs.filter { $0.kind == .flight }.map(\.destination).filter { seen.insert($0.code).inserted }.map(\.name)
    }

    private static func milesText(_ miles: Int, locale: Locale) -> String {
        "\(miles.formatted(.number.locale(locale))) mi"
    }

    private static func arrivalLocalClock(for leg: MapLeg, calendar: Calendar, locale: Locale) -> String? {
        guard let there = leg.destination.timeZone,
              there.secondsFromGMT(for: leg.end) != calendar.timeZone.secondsFromGMT(for: leg.end) else { return nil }
        return clockTime(leg.end, in: there, locale: locale)
    }

    private static func clockTime(_ date: Date, in zone: TimeZone, locale: Locale) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: zone))
    }

    private static func style(calendar: Calendar, locale: Locale) -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }
}
