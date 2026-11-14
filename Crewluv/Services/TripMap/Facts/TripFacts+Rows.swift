//
//  TripFacts+Rows.swift
//  CrewLuve
//
//  The facts sheet's rows (Stage 2 spec §5): in flight, "now, then where to"; on a layover, where they are, the next
//  flight and the trip so far; at home, the trip ahead and its forecast; after a recap's trip, the trip. A row with
//  nothing to say is left out.
//

import Foundation

nonisolated extension TripFacts {

    /// The rows at `date` on the timeline, with `now` the real time (for weather).
    func rows(at date: Date, now: Date) -> [FactRow] {
        if let leg = tripMap.legInMotion(at: date) {
            return leg.kind == .flight ? flightRows(on: leg, at: date, now: now) : [tripSoFarRow(at: date)].compactMap { $0 }
        }
        if isRecapOver(at: date) { return recapRows() }
        if tripMap.mode == .nextTrip, date < tripMap.span.start { return homeRows(at: date, now: now) }
        return layoverRows(at: date, now: now)
    }

    // MARK: - In flight (§5.1)

    private func flightRows(on leg: MapLeg, at date: Date, now: Date) -> [FactRow] {
        [belowRow(on: leg, at: date), skyRow(on: leg, at: date), distanceRow(on: leg, at: date), headedRow(on: leg, now: now)]
            .compactMap { $0 }
    }

    private func belowRow(on leg: MapLeg, at date: Date) -> FactRow? {
        let closest = stories[leg.id]?.closestToHome.flatMap { closest in
            leg.time(atFraction: closest.fraction).map {
                FactsWording.closestToHome(miles: Milestone.roundedMiles(closest.meters), at: $0, now: date, calendar: calendar, locale: locale)
            }
        }
        if let place = belowText(on: leg, at: date) {
            return FactRow(.below, symbol: "mappin.and.ellipse", title: place, details: [closest])
        }
        return closest.map { FactRow(.below, symbol: "mappin.and.ellipse", title: $0) }
    }

    private func skyRow(on leg: MapLeg, at date: Date) -> FactRow? {
        let next = sunEvents[leg.id]?.first { $0.time > date }
        let parts = [
            next.map { FactsWording.flyingInto($0.kind) },
            next.map { FactsWording.cockpitEvent($0, now: date, calendar: calendar, locale: locale) },
            SkyFacts.chase(on: leg, at: date).map(FactsWording.chase),
            SkyFacts.moon(on: leg, at: date).map(FactsWording.moon),
        ].compactMap { $0 }
        guard let title = parts.first else { return nil }
        let symbol: String
        if let next {
            symbol = next.kind == .sunset ? "sunset.fill" : "sunrise.fill"
        } else {
            symbol = SkyFacts.sunAltitude(on: leg, at: date) > SkyFacts.cockpitHorizon ? "sun.max.fill" : "moon.stars.fill"
        }
        return FactRow(.sky, symbol: symbol, title: title, details: Array(parts.dropFirst()))
    }

    private func distanceRow(on leg: MapLeg, at date: Date) -> FactRow {
        let totalMiles = leg.distance / GreatCircle.metersPerMile
        let flown = Int((totalMiles * leg.progress(at: date)).rounded())
        let halfway = leg.time(atFraction: 0.5).flatMap { $0 > date ? FactsWording.halfway(at: $0, calendar: calendar, locale: locale) : nil }
        let speed = FlightProgress.airborneWindow(departure: leg.start, arrival: leg.end)
            .map { FactsWording.averageSpeed(milesPerHour: totalMiles / ($0.duration / 3600)) }
        return FactRow(.distance, symbol: "point.topleft.down.to.point.bottomright.curvepath",
                       title: FactsWording.distance(flownMiles: flown, toGoMiles: Int(totalMiles.rounded()) - flown, locale: locale),
                       details: [halfway, speed, comparisons?.phrase(forMiles: totalMiles).map(FactsWording.midLine)])
    }

    private func headedRow(on leg: MapLeg, now: Date) -> FactRow {
        let landingWeather = forecast(for: leg, now: now)
        return FactRow(.headed, symbol: "airplane.arrival",
                       title: TripMapWording.landingLine(for: leg, calendar: calendar, locale: locale),
                       details: [landingWeather.map(FactsWording.weather),
                                 leg.destination.timeZone.flatMap { FactsWording.timeDifference(from: $0, to: calendar.timeZone, at: leg.end) }],
                       hasWeather: landingWeather != nil)
    }

    // MARK: - On a layover (§5.3)

    private func layoverRows(at date: Date, now: Date) -> [FactRow] {
        [whereTheyAreRow(at: date), nextFlightRow(at: date, now: now), tripSoFarRow(at: date)].compactMap { $0 }
    }

    private func whereTheyAreRow(at date: Date) -> FactRow? {
        guard let place = tripMap.pilotLocation(at: date) else { return nil }
        let difference = place.timeZone.flatMap { FactsWording.timeDifference(from: $0, to: calendar.timeZone, at: date) }
        let sun = place.timeZone.flatMap { zone in
            SkyFacts.nextGroundSunEvent(at: place.coordinate, after: date).map {
                FactsWording.groundSun($0.kind, at: $0.time, in: zone, locale: locale)
            }
        }
        return FactRow(.whereTheyAre, symbol: "mappin.and.ellipse", title: "In \(place.name)", details: [difference, sun])
    }

    private func nextFlightRow(at date: Date, now: Date) -> FactRow? {
        guard let next = tripMap.nextFlight(after: date) else { return nil }
        let miles = next.distance / GreatCircle.metersPerMile
        let distance = [TripMapWording.milesText(Int(miles.rounded()), locale: locale),
                        comparisons?.phrase(forMiles: miles).map(FactsWording.midLine)]
            .compactMap { $0 }
            .joined(separator: ", ")
        let landingWeather = forecast(for: next, now: now)
        return FactRow(.nextFlight, symbol: "airplane.departure",
                       title: TripMapWording.nextDepartureChip(for: next, now: date, calendar: calendar, locale: locale),
                       details: [distance, FactsWording.lands(next, calendar: calendar, locale: locale), landingWeather.map(FactsWording.weather)],
                       hasWeather: landingWeather != nil)
    }

    private func tripSoFarRow(at date: Date) -> FactRow? {
        let totals = TripTotals.soFar(on: tripMap, at: date, sunEvents: sunEvents)
        guard let line = FactsWording.soFar(totals, dayNumber: dayNumber, totalDays: totalDays, locale: locale) else { return nil }
        return FactRow(.tripSoFar, symbol: "chart.bar.fill", title: "Trip so far", details: [line])
    }

    // MARK: - At home before a trip (§5.4)

    private func homeRows(at date: Date, now: Date) -> [FactRow] {
        let whole = TripTotals.whole(tripMap, sunEvents: sunEvents)
        return [leavesRow(at: date, now: now), tripRow(.tripAhead, title: "The trip ahead", totals: whole),
                onTheWayRow(whole, isForecast: true)].compactMap { $0 }
    }

    private func leavesRow(at date: Date, now: Date) -> FactRow? {
        guard let first = tripMap.nextFlight(after: date) else { return nil }
        let day = TripMapWording.dayPhrase(for: first.start, now: date, calendar: calendar, locale: locale)
        let clock = TripMapWording.clockTime(first.start, in: calendar.timeZone, locale: locale)
        let flight = first.flightNumber.map { "\($0) to \(first.destination.name)" } ?? "Flying to \(first.destination.name)"
        let landingWeather = forecast(for: first, now: now)
        return FactRow(.leaves, symbol: "airplane.departure", title: "Leaves \(day) \(clock)",
                       details: [flight, landingWeather.map(FactsWording.weather)], hasWeather: landingWeather != nil)
    }

    // MARK: - After a recap's trip (§5.5)

    private func recapRows() -> [FactRow] {
        let whole = TripTotals.whole(tripMap, sunEvents: sunEvents)
        let longest = TripTotals.longestFlight(of: tripMap.legs).map {
            FactRow(.longestFlight, symbol: "arrow.left.and.right", title: "Longest flight", details: [FactsWording.longest($0, locale: locale)])
        }
        return [tripRow(.theTrip, title: "The trip", totals: whole), onTheWayRow(whole, isForecast: false), longest].compactMap { $0 }
    }

    // MARK: - Shared

    /// "4 days · Cologne, Dubai · 9,800 mi · like driving the Alaska Highway 7 times".
    private func tripRow(_ kind: FactRow.Kind, title: String, totals: TripTotals) -> FactRow {
        let cities = TripMapWording.destinationNames(of: tripMap.legs, leavingOut: Set([tripMap.home?.code].compactMap { $0 }))
        return FactRow(kind, symbol: "globe.americas.fill", title: title, details: [
            FactsWording.days(tripMap.dayCount(in: calendar)),
            cities.isEmpty ? nil : cities.joined(separator: ", "),
            totals.miles > 0 ? TripMapWording.milesText(totals.miles, locale: locale) : nil,
            comparisons?.phrase(forMiles: Double(totals.miles)).map(FactsWording.midLine),
        ])
    }

    private func onTheWayRow(_ totals: TripTotals, isForecast: Bool) -> FactRow? {
        FactsWording.onTheWay(totals, isForecast: isForecast, locale: locale).map {
            FactRow(.onTheWay, symbol: "chart.bar.fill", title: "On the way", details: [$0])
        }
    }
}
