//
//  TripFacts.swift
//  CrewLuve
//
//  Everything the facts say about a trip at a moment (Stage 2 spec §3.1, §4.4, §5): the headline, the rows
//  (TripFacts+Rows.swift), the trip so far and the recap's numbers. Each answer is a lookup in the flights' stories and
//  sun events, so replay and scrubbing need nothing extra (§4.10). A flight with a real plane is read where the real
//  plane is, along the path it really flew (Stage 3 spec §8).
//

import Foundation

nonisolated struct TripFacts {
    let tripMap: TripMap
    let geography: Geography?
    let comparisons: ComparisonPicker?
    /// By leg id, for the flights whose story is ready.
    let stories: [String: LegStory]
    /// Each flight's cockpit sunrises and sunsets, by leg id.
    let sunEvents: [String: [SkyFacts.SunEvent]]
    /// Landing-hour forecasts, by leg id.
    var forecasts: [String: LandingForecast] = [:]
    /// The status's trip day, for "Day 2 of 4".
    var dayNumber: Int?
    var totalDays: Int?
    var calendar: Calendar = .current
    var locale: Locale = .current
    /// The moments asked about are a replay's, not now: the full-screen map's clock isn't live. A real plane is
    /// then where its record has it, and what only its newest fix tells is left out (Stage 3 spec §7.3).
    var isReplay = false

    /// Weather shows for a flight landing within this of now (§7.2).
    static let weatherHorizon: TimeInterval = 48 * 3600
    /// A cockpit sunrise or sunset this close leads the headline.
    static let sunHeadlineWindow: TimeInterval = 30 * 60

    // MARK: - Milestones

    func milestones(on leg: MapLeg) -> [Milestone] {
        stories[leg.id].map { Milestone.milestones(on: leg, story: $0) } ?? []
    }

    // MARK: - The headline (§4.4)

    /// In flight: a milestone from the last 5 minutes, else a cockpit sunrise or sunset in the next 30, else the place
    /// below, else the landing countdown. While the real plane is out of sight they're its best guesses, in the same
    /// plain words (best guesses design §2). Nil on the ground and on a drive, where Stage 1's words stay.
    ///
    /// A real plane still on the ground at its departure airport after the plan's takeoff time is "Still on the ground
    /// in Rockford", ahead of all of them: it has crossed nothing yet, whatever the schedule's times say (which plane
    /// design §4).
    /// - Parameter includesEvents: false beside the latest event's banner, which shows the milestone already
    ///   (latest event design §2).
    func headline(at date: Date, includesEvents: Bool = true) -> String? {
        guard let leg = tripMap.legInMotion(at: date), leg.kind == .flight else { return nil }
        if isStillOnGround(leg, at: date) {
            return FactsWording.stillOnGround(in: leg.origin)
        }
        let recent = milestones(on: leg).last { $0.time <= date && date.timeIntervalSince($0.time) < Milestone.headlineDuration }
        if includesEvents, let recent {
            return FactsWording.headline(for: recent.kind)
        }
        let soon = sunEvents[leg.id]?.first { $0.time > date && $0.time.timeIntervalSince(date) <= Self.sunHeadlineWindow }
        if let soon {
            return FactsWording.cockpitCountdown(soon, now: date)
        }
        return belowText(on: leg, at: date) ?? TripMapWording.landingCountdown(for: leg, now: date)
    }

    /// The sheet's first line: the headline in flight, "Home from 4 days away" after a recap's trip, else Stage 1's.
    /// The latest event's banner is on the map above it, so the headline here leaves events out.
    func sheetHeadline(at date: Date) -> String {
        if let headline = headline(at: date, includesEvents: false) { return headline }
        if isRecapOver(at: date) { return FactsWording.recapChip(days: tripMap.dayCount(in: calendar)) }
        return TripMapWording.panelHeadline(for: tripMap, at: date, calendar: calendar, locale: locale)
    }

    /// "Over Kansas", "Over Québec, near Montréal", from the flight's story, read where the plane is. A real plane
    /// that's out of sight is where the plan has it, flying on from the last place it was seen, and reads the same.
    func belowText(on leg: MapLeg, at date: Date) -> String? {
        let plane = leg.plane(at: date, isReplay: isReplay)
        guard let place = stories[leg.id]?.place(atDistance: plane.distance) else { return nil }
        return FactsWording.below(place, near: geography?.city(near: plane.coordinate))
    }

    /// "Last seen near Montréal · 12 min ago", while the real plane is out of sight, or nil while it's seen.
    func lastSeenLine(on leg: MapLeg, at date: Date) -> String? {
        guard let unseenFor = leg.plane(at: date, isReplay: isReplay).unseenFor else { return nil }
        let seen = lastSeenPlace(on: leg)
        return FactsWording.lastSeenLine(seen.place, near: seen.city, ago: unseenFor)
    }

    /// What was under the real plane where it was last seen, and the city by it.
    private func lastSeenPlace(on leg: MapLeg) -> (place: Geography.Place?, city: Geography.City?) {
        let path = leg.path
        return (stories[leg.id]?.place(atDistance: path.flownLength),
                geography?.city(near: path.point(atDistance: path.flownLength)))
    }

    /// The newest event of the flight between its gates at `date`, for the banner (latest event design §1). Nil on
    /// the ground, on a drive, and before the flight's first event, and for a real plane still on the ground at its
    /// departure airport after the plan's takeoff time, which has passed nothing yet (which plane design §4).
    func latestEvent(at date: Date) -> LatestEvent? {
        guard let leg = tripMap.legInMotion(at: date), leg.kind == .flight, !isStillOnGround(leg, at: date) else { return nil }
        // By time, not by the way along: a best guess and a sighting can disagree a little.
        guard let newest = milestones(on: leg).filter({ $0.time <= date }).max(by: { $0.time < $1.time }) else { return nil }
        return LatestEvent(
            title: FactsWording.eventTitle(for: newest.kind),
            when: FactsWording.eventWhen(newest, at: date, isReplay: isReplay, calendar: calendar, locale: locale),
            sentence: FactsWording.spokenLatestEvent(newest, at: date, isReplay: isReplay, calendar: calendar, locale: locale))
    }

    /// Whether the real plane of `leg`, the leg between its gates at `date`, is still on the ground at its departure
    /// airport after the plan's takeoff time (which plane design §4). The facts then say so in place of what's below,
    /// and count nothing of the flight as passed. Now only: a replay reads where the map has the plane.
    func isStillOnGround(_ leg: MapLeg, at date: Date) -> Bool {
        !isReplay && leg.isStillOnGround(at: date)
    }

    /// The airport where the flight between its gates at `date` waits, while its real plane is still on the ground
    /// there after the plan's takeoff time: the line under the timeline names it (which plane design §4). Nil in a
    /// replay, whose moment is flying, as the map has the plane.
    func stillOnGroundAirport(at date: Date) -> AirportMark? {
        isReplay ? nil : tripMap.stillOnGroundAirport(at: date)
    }

    /// Whether a flight with live data shows, which adsb.lol is credited for (Stage 3 spec §8).
    var showsLiveData: Bool {
        tripMap.legs.contains(where: \.hasLiveData)
    }

    // MARK: - Weather (§7.3)

    /// The forecast for `leg` when it lands between the real `now` and 48 hours on, whatever moment the timeline shows.
    func forecast(for leg: MapLeg, now: Date) -> LandingForecast? {
        guard leg.end > now, leg.end.timeIntervalSince(now) <= Self.weatherHorizon else { return nil }
        return forecasts[leg.id]
    }

    // MARK: - The tall stop (§5.2, §5.5)

    /// A real plane still on the ground at its departure airport after the plan's takeoff time has passed none of its
    /// flight's events, and its flight is left out until it takes off, with no "In the air now" (which plane design
    /// §4).
    func tripSoFar(at date: Date) -> TripSoFar {
        let started = tripMap.legs.filter { $0.kind == .flight && $0.start <= date && !isStillOnGround($0, at: date) }.reversed()
        let flights = started.compactMap { leg -> TripSoFar.Flight? in
            // Newest first, so the latest is at the top (best guesses design §3).
            let events = milestones(on: leg).filter { $0.time <= date }.reversed().map {
                TripSoFar.Event(text: FactsWording.listLine(for: $0, calendar: calendar, locale: locale), isEstimate: $0.isEstimate)
            }
            // The flight between its gates is always listed, and set apart (§4).
            let tag = leg.isMoving(at: date) ? FactsWording.inTheAir(isReplay: isReplay) : nil
            guard tag != nil || !events.isEmpty else { return nil }
            return TripSoFar.Flight(id: leg.id, title: FactsWording.flightTitle(leg), tag: tag, events: Array(events))
        }
        if isRecapOver(at: date) {
            let totals = TripTotals.whole(tripMap, sunEvents: sunEvents)
            return TripSoFar(flights: flights, totalsTitle: "Trip recap",
                             totals: FactsWording.soFar(totals, dayNumber: nil, totalDays: nil, locale: locale))
        }
        // Where the rows already have a "Trip so far" row, it isn't said again under the list (§5).
        let totals = hasTripSoFarRow(at: date) ? nil : FactsWording.soFar(
            TripTotals.soFar(on: tripMap, at: date, sunEvents: sunEvents, isReplay: isReplay),
            dayNumber: dayNumber, totalDays: totalDays, locale: locale)
        return TripSoFar(flights: flights, totalsTitle: "Trip so far", totals: totals)
    }

    /// True once a recap's trip is over at `date`.
    func isRecapOver(at date: Date) -> Bool {
        tripMap.mode == .recap && date >= tripMap.span.end
    }

    // MARK: - The card (§6.4, §6.5)

    /// The card as one sentence for VoiceOver, and in flight the latest event's banner after it.
    func cardSummary(now: Date, pilotName: String) -> String {
        switch tripMap.mode {
        case .inFlight:
            if let leg = tripMap.currentLeg {
                return [flightSummary(of: leg, now: now), latestEvent(at: now)?.sentence].compactMap { $0 }.joined(separator: " ")
            }
        case .recap:
            return FactsWording.recapSummary(days: tripMap.dayCount(in: calendar), totals: TripTotals.whole(tripMap, sunEvents: sunEvents),
                                             longest: TripTotals.longestFlight(of: tripMap.legs), locale: locale)
        case .onTrip, .nextTrip:
            break
        }
        return TripMapWording.cardSummary(for: tripMap, now: now, pilotName: pilotName, calendar: calendar, locale: locale)
    }

    /// The flight in the air as one sentence: where it is and when it lands.
    private func flightSummary(of leg: MapLeg, now: Date) -> String {
        let plane = leg.plane(at: now, isReplay: isReplay)
        let below = stories[leg.id]?.place(atDistance: plane.distance)?.name
        // With a real plane the sentence says how it's doing against the schedule (Stage 3 spec §9), and while
        // it's out of sight, where it was last seen (§15).
        let lastSeen = plane.unseenFor.map { ago -> String in
            let seen = lastSeenPlace(on: leg)
            return FactsWording.lastSeen(seen.place, near: seen.city, ago: ago)
        }
        if let live = TripMapWording.liveSummary(for: leg, over: below, lastSeen: lastSeen, now: now,
                                                 calendar: calendar, locale: locale) {
            return live
        }
        let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
        let over = below.map { ", over \($0)" } ?? ""
        let landing = TripMapWording.clockTime(leg.end, in: calendar.timeZone, locale: locale)
        return "\(lead) \(leg.destination.name)\(over). Lands at \(landing) your time. Estimated from the schedule."
    }

    var recapTiles: [RecapTile] {
        FactsWording.recapTiles(TripTotals.whole(tripMap, sunEvents: sunEvents), locale: locale)
    }

    /// "Longest: Dubai → Louisville, 7,382 mi".
    var recapLongestLine: String? {
        TripTotals.longestFlight(of: tripMap.legs).map { "Longest: \(FactsWording.longest($0, locale: locale))" }
    }
}
