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
    func headline(at date: Date) -> String? {
        guard let leg = tripMap.legInMotion(at: date), leg.kind == .flight else { return nil }
        let recent = milestones(on: leg).last { $0.time <= date && date.timeIntervalSince($0.time) < Milestone.headlineDuration }
        if let recent {
            return FactsWording.headline(for: recent.kind)
        }
        let soon = sunEvents[leg.id]?.first { $0.time > date && $0.time.timeIntervalSince(date) <= Self.sunHeadlineWindow }
        if let soon {
            return FactsWording.cockpitCountdown(soon, now: date)
        }
        return belowText(on: leg, at: date) ?? TripMapWording.landingCountdown(for: leg, now: date)
    }

    /// The sheet's first line: the headline in flight, "Home from 4 days away" after a recap's trip, else Stage 1's.
    func sheetHeadline(at date: Date) -> String {
        if let headline = headline(at: date) { return headline }
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

    func tripSoFar(at date: Date) -> TripSoFar {
        let started = tripMap.legs.filter { $0.kind == .flight && $0.start <= date }.reversed()
        let flights = started.compactMap { leg -> TripSoFar.Flight? in
            let lines = milestones(on: leg).filter { $0.time <= date }.map { FactsWording.listLine(for: $0, calendar: calendar, locale: locale) }
            return lines.isEmpty ? nil : TripSoFar.Flight(id: leg.id, title: FactsWording.flightTitle(leg), milestones: lines)
        }
        if isRecapOver(at: date) {
            let totals = TripTotals.whole(tripMap, sunEvents: sunEvents)
            return TripSoFar(flights: flights, totalsTitle: "Trip recap",
                             totals: FactsWording.soFar(totals, dayNumber: nil, totalDays: nil, locale: locale))
        }
        let totals = TripTotals.soFar(on: tripMap, at: date, sunEvents: sunEvents, isReplay: isReplay)
        return TripSoFar(flights: flights, totalsTitle: "Trip so far",
                         totals: FactsWording.soFar(totals, dayNumber: dayNumber, totalDays: totalDays, locale: locale))
    }

    /// True once a recap's trip is over at `date`.
    func isRecapOver(at date: Date) -> Bool {
        tripMap.mode == .recap && date >= tripMap.span.end
    }

    // MARK: - The card (§6.4, §6.5)

    /// The card as one sentence for VoiceOver.
    func cardSummary(now: Date, pilotName: String) -> String {
        switch tripMap.mode {
        case .inFlight:
            if let leg = tripMap.currentLeg {
                let plane = leg.plane(at: now, isReplay: isReplay)
                let below = stories[leg.id]?.place(atDistance: plane.distance)?.name
                // With a real plane the sentence says how it's doing against the schedule (Stage 3 spec §9), and
                // while it's out of sight, where it was last seen (§15).
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
        case .recap:
            return FactsWording.recapSummary(days: tripMap.dayCount(in: calendar), totals: TripTotals.whole(tripMap, sunEvents: sunEvents),
                                             longest: TripTotals.longestFlight(of: tripMap.legs), locale: locale)
        case .onTrip, .nextTrip:
            break
        }
        return TripMapWording.cardSummary(for: tripMap, now: now, pilotName: pilotName, calendar: calendar, locale: locale)
    }

    var recapTiles: [RecapTile] {
        FactsWording.recapTiles(TripTotals.whole(tripMap, sunEvents: sunEvents), locale: locale)
    }

    /// "Longest: Dubai → Louisville, 7,382 mi".
    var recapLongestLine: String? {
        TripTotals.longestFlight(of: tripMap.legs).map { "Longest: \(FactsWording.longest($0, locale: locale))" }
    }
}
