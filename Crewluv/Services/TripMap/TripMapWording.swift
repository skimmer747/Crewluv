//
//  TripMapWording.swift
//  CrewLuve
//
//  Every sentence the trip map shows or speaks (moving map spec §5, §6, §14; Stage 3 spec §9). The family's own
//  times, in `calendar.timeZone`, are marked "L", and a city's follow its name (time labels design §2). VoiceOver says
//  "your time". A landing time that's the real plane's estimate is marked "about".
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
            return (nextTripChip(startingAt: tripMap.span.start, now: date, isAtBase: tripMap.isWaitingAtBase,
                                 calendar: calendar, locale: locale), nil)
        case .recap:
            return (FactsWording.recapChip(days: tripMap.dayCount(in: calendar)), "Replay the trip")
        }
    }

    /// "Cologne · 9:14 PM": the city's time, after its name.
    static func placeChip(for place: AirportMark, at now: Date, locale: Locale = .current) -> String {
        guard let zone = place.timeZone else { return place.name }
        return "\(place.name) · \(clockTime(now, in: zone, locale: locale))"
    }

    /// "Next: Dubai, tomorrow 6:10 AM L".
    static func nextDepartureChip(for leg: MapLeg, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let day = dayPhrase(for: leg.start, now: now, calendar: calendar, locale: locale)
        return "Next: \(leg.destination.name), \(day) \(ClockLabel.yours(leg.start, calendar: calendar, locale: locale))"
    }

    /// "Home · next trip Wednesday", or "At base · next trip Wednesday" while the pilot waits at base (base waits
    /// design §3).
    static func nextTripChip(startingAt start: Date, now: Date, isAtBase: Bool = false, calendar: Calendar = .current,
                             locale: Locale = .current) -> String {
        let place = isAtBase ? "At base" : "Home"
        return "\(place) · next trip \(dayPhrase(for: start, now: now, calendar: calendar, locale: locale))"
    }

    /// "Landing in 2 h 10 min", to the gate arrival.
    static func landingCountdown(for leg: MapLeg, now: Date) -> String {
        let minutes = Int((leg.end.timeIntervalSince(now) / 60).rounded(.up))
        guard minutes > 0 else { return "Landing now" }
        return "Landing in \(minutesText(minutes))"
    }

    // MARK: - Landing

    /// "Lands Cologne 9:30 PM · 3:30 PM L", or one time, "Lands Louisville 3:30 PM L", when the destination keeps the
    /// family's clock. With the real plane's estimate, "Lands Cologne about 9:18 PM · 3:18 PM L".
    static func landingLine(for leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "Lands \(leg.destination.name) \(about(leg))\(ClockLabel.pair(leg.end, in: leg.destination.timeZone, calendar: calendar, locale: locale))"
    }

    /// "Reaches the gate in Anchorage at 3:52 PM · 7:52 PM L", or one time where the destination keeps the family's
    /// clock: the facts' landing row once the real plane is down (landed before the gate design §3). It names the city,
    /// so its first time is the city's (time labels design §2). "at", as the card's sentence and the plane's popup say
    /// it, unless the time is the real plane's estimate.
    static func gateLine(for leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let when = about(leg).isEmpty ? "at " : about(leg)
        let pair = ClockLabel.pair(leg.end, in: leg.destination.timeZone, calendar: calendar, locale: locale)
        return "Reaches the gate in \(leg.destination.name) \(when)\(pair)"
    }

    /// "Took off Taipei 7:42 PM · 6:42 AM L", or one time where the departure airport keeps the family's clock: the
    /// facts' takeoff row (time labels design §3.3). "about" when it's the schedule's takeoff, not the real plane's.
    static func takeoffLine(for leg: MapLeg, at takeoff: Date, isEstimate: Bool, calendar: Calendar = .current,
                            locale: Locale = .current) -> String {
        let pair = ClockLabel.pair(takeoff, in: leg.origin.timeZone, calendar: calendar, locale: locale)
        return "Took off \(leg.origin.name) \(isEstimate ? "about " : "")\(pair)"
    }

    /// "Lands 3:30 PM L", for the card's bar. With the real plane's estimate, "Lands about 3:18 PM L".
    static func landsAt(for leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "Lands \(about(leg))\(ClockLabel.yours(leg.end, calendar: calendar, locale: locale))"
    }

    /// The card's bar's landing time at `now`: "Lands 3:30 PM L", or once the real plane is down, before the gate,
    /// "At the gate 3:30 PM L" (landed before the gate design §3).
    static func barArrival(for leg: MapLeg, at now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard leg.isLandedBeforeGate(at: now) else { return landsAt(for: leg, calendar: calendar, locale: locale) }
        return "At the gate \(ClockLabel.yours(leg.end, calendar: calendar, locale: locale))"
    }

    /// "9:30 PM in Cologne", or nil when the destination keeps the family's time.
    static func arrivalLocalTime(for leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String? {
        arrivalLocalClock(for: leg, calendar: calendar, locale: locale).map { "\($0) in \(leg.destination.name)" }
    }

    // MARK: - The real plane

    /// "12 min ahead", "About 20 min behind", "Still on the ground · 20 min behind" or "Landed 8 min early": the real
    /// plane against the schedule (Stage 3 spec §5.3).
    static func liveLabel(_ label: LiveLabel) -> String {
        switch label {
        case .onSchedule:
            return "On schedule"
        case .ahead(let minutes, let isEstimated):
            return "\(isEstimated ? "About " : "")\(minutesText(minutes)) ahead"
        case .behind(let minutes, let isEstimated):
            return "\(isEstimated ? "About " : "")\(minutesText(minutes)) behind"
        case .stillOnGround(let minutesBehind):
            return minutesBehind.map { "Still on the ground · \(minutesText($0)) behind" } ?? "Still on the ground"
        case .returned:
            return "Returned"
        case .landedOnTime:
            return "Landed on time"
        case .landedEarly(let minutes):
            return "Landed \(minutesText(minutes)) early"
        case .landedLate(let minutes):
            return "Landed \(minutesText(minutes)) late"
        }
    }

    /// The label as VoiceOver says it in the card's sentence: "12 minutes ahead of schedule", "about 20 minutes
    /// behind schedule", "still on the ground" or "landed 8 minutes early".
    static func spokenLiveLabel(_ label: LiveLabel) -> String {
        switch label {
        case .onSchedule:
            return "on schedule"
        case .ahead(let minutes, let isEstimated):
            return "\(isEstimated ? "about " : "")\(spokenMinutes(minutes)) ahead of schedule"
        case .behind(let minutes, let isEstimated):
            return "\(isEstimated ? "about " : "")\(spokenMinutes(minutes)) behind schedule"
        case .stillOnGround(let minutesBehind):
            return minutesBehind.map { "still on the ground, \(spokenMinutes($0)) behind schedule" } ?? "still on the ground"
        case .returned:
            return "returned"
        case .landedOnTime:
            return "landed on time"
        case .landedEarly(let minutes):
            return "landed \(spokenMinutes(minutes)) early"
        case .landedLate(let minutes):
            return "landed \(spokenMinutes(minutes)) late"
        }
    }

    /// The card's sentence for a flight with a real plane (Stage 3 spec §9, §15): "UPS207 to Cologne, 12 minutes
    /// ahead of schedule, over Québec. Lands about 3:18 PM your time." Once it's down, "…, landed 8 minutes early.
    /// Reaches the gate at 3:18 PM your time." Seen at its gate before the plan's takeoff, with no label yet: "UPS70 to
    /// Honolulu, on the ground in Louisville. Lands at 12:11 AM your time." (live or scheduled design §7). Nil when the
    /// plane has no label and isn't seen at its gate, and the schedule's sentence stands.
    /// - Parameters:
    ///   - place: what's below the plane, when the facts know.
    ///   - lastSeen: where a plane that's out of sight was last seen, as `FactsWording.lastSeen` words it: "near
    ///     Montréal", "over Québec" or "2 hours ago". It follows what's below, which is then a best guess
    ///     (Stage 3 spec §15, best guesses design §2).
    static func liveSummary(for leg: MapLeg, over place: String? = nil, lastSeen: String? = nil, now: Date,
                            calendar: Calendar = .current, locale: Locale = .current) -> String? {
        let label = leg.flight?.progress(at: now).label
        let spoken: String
        switch label {
        // A plane back at its departure airport after an air return names it (air return design §3).
        case .returned?: spoken = "returned to \(leg.origin.name)"
        case let label?: spoken = spokenLiveLabel(label)
        case nil:
            guard leg.atDeparture(at: now) == .atGate else { return nil }
            spoken = "on the ground in \(leg.origin.name)"
        }
        let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
        // What's below and where it was last seen are said only of a plane in the air: not of one on the ground at its
        // gate, nor of one that's down (which plane design §4).
        let isFlying = switch label {
        case .onSchedule?, .ahead?, .behind?: true
        case .stillOnGround?, .returned?, .landedOnTime?, .landedEarly?, .landedLate?, nil: false
        }
        let isDown = switch label {
        case .landedOnTime?, .landedEarly?, .landedLate?: true
        case .onSchedule?, .ahead?, .behind?, .stillOnGround?, .returned?, nil: false
        }
        let over = isFlying ? (place.map { ", over \($0)" } ?? "") + (lastSeen.map { ", last tracked \($0)" } ?? "") : ""
        let time = clockTime(leg.end, in: calendar.timeZone, locale: locale)
        // It's down and on its way in: "landed 8 minutes early. Lands at 3:18 PM" would say so twice.
        let arrival = isDown ? "Reaches the gate at \(time) your time." : "Lands \(leg.isArrivalEstimated ? "about" : "at") \(time) your time."
        return "\(lead) \(leg.destination.name), \(spoken)\(over). \(arrival)"
    }

    // MARK: - The bar under the map

    /// The bar's words on the ground (moving map spec §5.3): the day, cities and miles so far mid-trip; the dates,
    /// cities and total miles for a trip ahead. Empty in flight, where the bar shows the flight.
    static func statsItems(for tripMap: TripMap, at date: Date, dayNumber: Int?, totalDays: Int?,
                           calendar: Calendar = .current, locale: Locale = .current) -> [String] {
        let cities = destinations(of: tripMap.legs, leavingOut: Set([tripMap.home?.code].compactMap { $0 }))
        switch tripMap.mode {
        case .inFlight, .recap:
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

    /// Miles flown by `date`, counting the part of a flight that's in the air. A flight with a real path counts
    /// the miles along it (Stage 3 spec §8).
    /// - Parameter isReplay: `date` is a moment of the replay, not now.
    static func milesFlown(by date: Date, on legs: [MapLeg], isReplay: Bool = false) -> Int {
        let meters = legs.filter { $0.kind == .flight }.reduce(0) { total, leg in
            if date >= leg.end { return total + leg.pathLength }
            if date < leg.start { return total }
            return total + leg.plane(at: date, isReplay: isReplay).distance
        }
        return Int((meters / GreatCircle.metersPerMile).rounded())
    }

    /// The trip's miles, along each flight's real path where it has one.
    static func totalMiles(of legs: [MapLeg]) -> Int {
        let meters = legs.filter { $0.kind == .flight }.reduce(0) { $0 + $1.pathLength }
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

    /// The pill at the top: "UPS207 · Live · 12 min ahead", "UPS207 · Not tracked live", "Driving to Louisville",
    /// "Day 2 of 4" or "Next trip".
    /// - Parameter isReplay: `date` is a moment of the replay, not now: a flight is "In flight" with a real path, else
    ///   "By the schedule" (live or scheduled design §6).
    static func topPill(for tripMap: TripMap, at date: Date, dayNumber: Int?, totalDays: Int?, isReplay: Bool = false) -> String {
        if tripMap.mode == .recap, date >= tripMap.span.end { return "Trip recap" }
        if let leg = tripMap.legInMotion(at: date) {
            switch leg.kind {
            case .flight:
                // While Crewlu Cloud's first answer is on its way the status is empty: the flight number alone, or
                // where it's going.
                let words = [leg.flightNumber, flightStatus(for: leg, at: date, isReplay: isReplay)]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                return words.isEmpty ? "Flight to \(leg.destination.name)" : words
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
            return nextTripChip(startingAt: tripMap.span.start, now: date, isAtBase: tripMap.isWaitingAtBase,
                                calendar: calendar, locale: locale)
        }
        return tripMap.pilotLocation(at: date).map { placeChip(for: $0, at: date, locale: locale) } ?? ""
    }

    /// "Fri 9:14 PM", the time under the timeline.
    static func timelineTime(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        date.formatted(style(calendar: calendar, locale: locale).weekday(.abbreviated).hour().minute())
    }

    /// "Sat 1:40 PM L · Layover in Denver": the line under the timeline, when and what (activity markers design §4.2).
    /// While the flight is named in place of the activity, `flight`: "Mon 12:21 PM L · On the ground in Rockford", "Mon
    /// 12:21 PM L · Returned to Rockford", "Mon 7:45 PM L · Landed in Anchorage", "Mon 3:12 PM L · Scheduled to fly to
    /// Honolulu" or "Mon 3:40 PM L · Should be flying to Honolulu".
    static func timelineLine(_ date: Date, activity: TripActivity?, flight: FlightNow? = nil,
                             calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = "\(timelineTime(date, calendar: calendar, locale: locale)) \(ClockLabel.mark)"
        guard let words = timelineWords(activity, flight: flight) else { return time }
        return "\(time) · \(words)"
    }

    /// "Saturday 1:40 PM, layover in Denver": the timeline's VoiceOver value (activity markers design §4.3), as the
    /// line under it says.
    static func timelineSpokenValue(_ date: Date, activity: TripActivity?, flight: FlightNow? = nil,
                                    calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = date.formatted(style(calendar: calendar, locale: locale).weekday(.wide).hour().minute())
        guard let words = timelineWords(activity, flight: flight) else { return time }
        return "\(time), \(words.prefix(1).lowercased() + words.dropFirst())"
    }

    /// What the pilot is doing, or what's said of the flight in place of "Flying to": "On the ground in Rockford" while
    /// its real plane is still at its departure airport (which plane design §4), "Returned to Rockford" once it's back
    /// there after an air return (air return design §3), "Landed in Anchorage" where it's down at the arrival airport,
    /// before the gate (landed before the gate design §3). By the schedule alone, "Scheduled to fly to Honolulu" before
    /// its takeoff and "Should be flying to Honolulu" after (live or scheduled design §4).
    private static func timelineWords(_ activity: TripActivity?, flight: FlightNow?) -> String? {
        switch flight {
        case .stillIn(let airport): "On the ground in \(airport.name)"
        case .returnedTo(let airport): FactsWording.returned(to: airport)
        case .landedIn(let airport): FactsWording.landed(in: airport)
        case .dueTo(let airport): "Scheduled to fly to \(airport.name)"
        case .shouldBeFlyingTo(let airport): "Should be flying to \(airport.name)"
        case nil: activity?.words
        }
    }

    // MARK: - Follow the plane

    /// The caption a tap on Follow the plane shows for a moment, and VoiceOver announces (follow the plane design §2):
    /// what the map does now. With no flight in the air, turning it on changes nothing yet, so it says when it will.
    static func followCaption(isOn: Bool, hasFlightInAir: Bool) -> String {
        guard isOn else { return "Showing the whole flight" }
        return hasFlightInAir ? "Following the plane" : "Follows the plane when a flight is in the air"
    }

    // MARK: - VoiceOver

    /// The card as one sentence (moving map spec §14).
    static func cardSummary(for tripMap: TripMap, now: Date, pilotName: String,
                            calendar: Calendar = .current, locale: Locale = .current) -> String {
        switch tripMap.mode {
        case .inFlight:
            guard let leg = tripMap.currentLeg else { return "Trip map" }
            if let live = liveSummary(for: leg, now: now, calendar: calendar, locale: locale) {
                return withSource(live, for: leg, at: now)
            }
            let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
            let due = spokenDueClause(for: leg, at: now, calendar: calendar, locale: locale)
            let landing = clockTime(leg.end, in: calendar.timeZone, locale: locale)
            return withSource("\(lead) \(leg.destination.name)\(due), landing at \(landing) your time.", for: leg, at: now)
        case .onTrip:
            var parts = ["Trip map."]
            if let place = tripMap.pilotLocation(at: now) { parts.append("\(pilotName) is in \(place.name).") }
            if let next = tripMap.nextFlight(after: now) {
                parts.append("\(ClockLabel.spoken(nextDepartureChip(for: next, now: now, calendar: calendar, locale: locale))).")
            }
            return parts.joined(separator: " ")
        case .nextTrip:
            let cities = destinationNames(of: tripMap.legs, leavingOut: Set([tripMap.home?.code].compactMap { $0 }))
            let day = dayPhrase(for: tripMap.span.start, now: now, calendar: calendar, locale: locale)
            return "Map of the next trip, \(day): \(cities.joined(separator: ", "))."
        case .recap:
            let chip = FactsWording.recapChip(days: tripMap.dayCount(in: calendar))
            return "Trip recap: \(chip.prefix(1).lowercased() + chip.dropFirst())."
        }
    }

    // MARK: - Helpers, shared with FactsWording

    /// "45 min", "2 h" or "2 h 10 min": the landing countdown's length, and the real plane's gap.
    static func minutesText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        if rest == 0 { return "\(hours) h" }
        return "\(hours) h \(rest) min"
    }

    /// "1 minute", "45 minutes", "2 hours" or "2 hours 10 minutes": a length as VoiceOver says it.
    static func spokenMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        let hoursText = hours == 1 ? "1 hour" : "\(hours) hours"
        let restText = rest == 1 ? "1 minute" : "\(rest) minutes"
        if hours == 0 { return restText }
        if rest == 0 { return hoursText }
        return "\(hoursText) \(restText)"
    }

    /// "about " before a landing time that's the real plane's estimate, else nothing (Stage 3 spec §9).
    static func about(_ leg: MapLeg) -> String {
        leg.isArrivalEstimated ? "about " : ""
    }

    /// The names of the cities the trip's flights reach, in order, each once, home left out — for VoiceOver.
    static func destinationNames(of legs: [MapLeg], leavingOut homeCodes: Set<String>) -> [String] {
        var seen = homeCodes
        return legs.filter { $0.kind == .flight }.map(\.destination).filter { seen.insert($0.code).inserted }.map(\.name)
    }

    static func milesText(_ miles: Int, locale: Locale) -> String {
        "\(miles.formatted(.number.locale(locale))) mi"
    }

    private static func arrivalLocalClock(for leg: MapLeg, calendar: Calendar, locale: Locale) -> String? {
        guard let there = leg.destination.timeZone,
              there.secondsFromGMT(for: leg.end) != calendar.timeZone.secondsFromGMT(for: leg.end) else { return nil }
        return clockTime(leg.end, in: there, locale: locale)
    }

    static func clockTime(_ date: Date, in zone: TimeZone, locale: Locale) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: zone))
    }

    private static func style(calendar: Calendar, locale: Locale) -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }
}
