//
//  TripFactsTests.swift
//  CrewluvTests
//
//  The headline, the tall stop, weather's window and the card's words (Stage 2 spec §4.4, §5.2, §6, §7.3). The
//  flight along the equator crosses into Bravo at 11:00 UTC, is halfway at 11:45, out over the Test Sea at 12:03 and
//  closest to home (35 mi) at 12:21: 7:00, 7:45, 8:03 and 8:21 AM in Louisville.
//

import XCTest
@testable import Crewluv

final class TripFactsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    private func plain(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private func equatorFacts(hasStory: Bool = true, forecasts: [String: LandingForecast] = [:]) -> TripFacts {
        let leg = FactsTestData.equatorFlight(from: 0, to: 20)
        let home = FactsTestData.mark("HOME", latitude: 0.5, longitude: 14)
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: home,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        return TripFacts(tripMap: map, geography: FactsTestData.equator, comparisons: nil,
                         stories: hasStory ? [leg.id: LegStory(leg: leg, geography: FactsTestData.equator, home: home)] : [:],
                         sunEvents: [leg.id: SkyFacts.sunEvents(on: leg)], forecasts: forecasts,
                         dayNumber: 1, totalDays: 1, calendar: calendar, locale: locale)
    }

    private func europeRecap() throws -> TripFacts {
        let map = try XCTUnwrap(TripMap.make(tripLegs: TripMapTestLegs.europeTrip(), isNextTrip: false, isRecap: true,
                                             homeAirportCode: "SDF", legacyDelayMinutes: nil, at: TripMapTestLegs.tripStart,
                                             coordinate: TripMapTestLegs.coordinate))
        let sunEvents = Dictionary(uniqueKeysWithValues: map.legs.map { ($0.id, SkyFacts.sunEvents(on: $0)) })
        return TripFacts(tripMap: map, geography: nil, comparisons: nil, stories: [:], sunEvents: sunEvents,
                         calendar: calendar, locale: locale)
    }

    // MARK: - The headline (§4.4)

    func test_headline_inPriorityOrder() {
        let facts = equatorFacts()
        XCTAssertEqual(facts.headline(at: at("11:02")), "Just crossed into Bravo")
        XCTAssertEqual(facts.headline(at: at("11:10")), "Over Bravo, near Testville", "the crossing was 10 minutes ago")
        XCTAssertEqual(facts.headline(at: at("11:46")), "Halfway!")
        XCTAssertEqual(facts.headline(at: at("12:05")), "Out over the Test Sea")
        XCTAssertEqual(facts.headline(at: at("12:22")), "Closest to home: 35 mi, wave!")
        XCTAssertEqual(facts.headline(at: at("12:40")), "Over the Test Sea")
    }

    func test_headline_beforeTheStoryIsReady_isTheLandingCountdown() {
        XCTAssertEqual(equatorFacts(hasStory: false).headline(at: at("12:10")), "Landing in 1 h 12 min")
    }

    func test_headline_aCockpitSunriseWithin30Minutes_comesBeforeThePlace() {
        let start = FactsTestData.date("2026-11-13T23:00:00Z")
        let leg = MapLeg(id: "night", kind: .flight,
                         origin: AirportMark(code: "SDF", city: "Louisville", coordinate: TripMapTestLegs.airports["SDF"]!, timeZone: nil),
                         destination: AirportMark(code: "CGN", city: "Cologne", coordinate: TripMapTestLegs.airports["CGN"]!, timeZone: nil),
                         start: start, end: start.addingTimeInterval(8 * 3600), flightNumber: "UPS207")
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: nil, span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        let facts = TripFacts(tripMap: map, geography: nil, comparisons: nil, stories: [:], sunEvents: [leg.id: SkyFacts.sunEvents(on: leg)])
        XCTAssertEqual(facts.headline(at: FactsTestData.date("2026-11-14T06:17:43Z")), "Sunrise from the cockpit in 21 min")
    }

    func test_headline_onTheGround_isNil() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: TripMapTestLegs.tripStart.addingTimeInterval(12 * 3600)))
        let facts = TripFacts(tripMap: map, geography: nil, comparisons: nil, stories: [:], sunEvents: [:])
        XCTAssertNil(facts.headline(at: TripMapTestLegs.tripStart.addingTimeInterval(12 * 3600)))
    }

    // MARK: - Weather's window (§7.3)

    func test_forecast_onlyForALandingWithin48HoursOfNow() {
        let facts = equatorFacts(forecasts: ["eq": LandingForecast(temperature: "81°F", condition: "clear")])
        let leg = facts.tripMap.legs[0]
        XCTAssertNotNil(facts.forecast(for: leg, now: at("11:10")))
        XCTAssertNil(facts.forecast(for: leg, now: at("13:30")), "already landed")
        XCTAssertNil(facts.forecast(for: leg, now: leg.end.addingTimeInterval(-49 * 3600)), "more than 48 hours out")
    }

    // MARK: - The tall stop (§5.2)

    func test_tripSoFar_listsThisFlightsMilestones_thenTheTotals() {
        let tripSoFar = equatorFacts().tripSoFar(at: at("12:30"))
        XCTAssertEqual(tripSoFar.flights.map(\.title), ["TST1 · E0 → E20"])
        // Newest first (best guesses design §3), and the flight is the one in the air.
        XCTAssertEqual(tripSoFar.flights.first?.events.map { plain($0.text) }, [
            "Closest to home, 35 mi · 8:21 AM", "Out over the Test Sea · 8:03 AM", "Halfway · 7:45 AM", "Crossed into Bravo · 7:00 AM",
        ])
        XCTAssertEqual(tripSoFar.flights.first?.events.map(\.isEstimate), [false, false, false, false], "the schedule is told as it is")
        XCTAssertEqual(tripSoFar.flights.first?.tag, "In the air now")
        XCTAssertEqual(tripSoFar.totalsTitle, "Trip so far")
        XCTAssertEqual(tripSoFar.totals, "Day 1 of 1 · 1,036 mi")
    }

    func test_tripSoFar_onlyMilestonesThatHaveHappened() {
        XCTAssertEqual(equatorFacts().tripSoFar(at: at("11:50")).flights.first?.events.count, 2)
    }

    func test_tripSoFar_onALayover_saysTripSoFarOnce_inTheRows() throws {
        // The rows have "Trip so far" on a layover, so it isn't said again under the list (best guesses design §5).
        let at = TripMapTestLegs.tripStart.addingTimeInterval(12 * 3600)
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: at))
        let sunEvents = Dictionary(uniqueKeysWithValues: map.legs.map { ($0.id, SkyFacts.sunEvents(on: $0)) })
        let facts = TripFacts(tripMap: map, geography: nil, comparisons: nil, stories: [:], sunEvents: sunEvents,
                              calendar: calendar, locale: locale)
        XCTAssertTrue(facts.rows(at: at, now: at).contains { $0.kind == .tripSoFar })
        XCTAssertTrue(facts.hasTripSoFarRow(at: at))
        XCTAssertNil(facts.tripSoFar(at: at).totals)
        XCTAssertEqual(facts.tripSoFar(at: at).flights.map(\.tag), [], "a finished flight with no event isn't listed")

        // In flight the rows have none, so it's under the list.
        let inFlight = TripMapTestLegs.tripStart.addingTimeInterval(4 * 3600)
        XCTAssertFalse(facts.rows(at: inFlight, now: inFlight).contains { $0.kind == .tripSoFar })
        XCTAssertNotNil(facts.tripSoFar(at: inFlight).totals)
    }

    func test_hasTripSoFarRow_isWhetherTheRowsHaveIt_atEveryMoment() throws {
        let start = TripMapTestLegs.tripStart
        let trip = TripMapTestLegs.europeTrip()
        let drive = MapLeg(id: "d", kind: .drive,
                           origin: FactsTestData.mark("LEX", latitude: 38.04, longitude: -84.61, city: "Lexington"),
                           destination: FactsTestData.mark("SDF", latitude: 38.17, longitude: -85.74, city: "Louisville"),
                           start: start, end: start.addingTimeInterval(3600), flightNumber: nil)
        let maps = [
            try XCTUnwrap(TripMapTestLegs.map(trip, at: start)),
            try XCTUnwrap(TripMapTestLegs.map(trip, isNextTrip: true, at: start.addingTimeInterval(-86_400))),
            try XCTUnwrap(TripMap.make(tripLegs: trip, isNextTrip: false, isRecap: true, homeAirportCode: "SDF",
                                       legacyDelayMinutes: nil, at: start, coordinate: TripMapTestLegs.coordinate)),
            TripMap(mode: .onTrip, legs: [drive], home: nil, span: DateInterval(start: drive.start, end: drive.end), tripDays: nil),
        ]
        var checked = 0
        for map in maps {
            let sunEvents = Dictionary(uniqueKeysWithValues: map.legs.map { ($0.id, SkyFacts.sunEvents(on: $0)) })
            // With a day to tell, a "Trip so far" row always has something to say where there is one.
            let facts = TripFacts(tripMap: map, geography: nil, comparisons: nil, stories: [:], sunEvents: sunEvents,
                                  dayNumber: 1, totalDays: 4, calendar: calendar, locale: locale)
            for half in stride(from: -60, through: 200, by: 1) {
                let at = start.addingTimeInterval(Double(half) * 1800)
                XCTAssertEqual(facts.hasTripSoFarRow(at: at), facts.rows(at: at, now: at).contains { $0.kind == .tripSoFar },
                               "\(map.mode) at \(half) half hours")
                checked += 1
            }
        }
        XCTAssertEqual(checked, 4 * 261)
    }

    func test_tripSoFar_afterARecapsTrip_isTheRecap() throws {
        let facts = try europeRecap()
        let tripSoFar = facts.tripSoFar(at: facts.tripMap.span.end.addingTimeInterval(3600))
        XCTAssertEqual(tripSoFar.totalsTitle, "Trip recap")
        XCTAssertEqual(tripSoFar.totals, "2 cities · 14,819 mi · 18 time zones · 1 sunset from the cockpit")
    }

    // MARK: - The card (§6.4, §6.5)

    func test_cardSummary_inFlight_addsThePlaceBelow() {
        XCTAssertEqual(plain(equatorFacts().cardSummary(now: at("11:10"), pilotName: "Alex")),
                       "TST1 to E20, over Bravo. Lands at 9:22 AM your time. Estimated from the schedule.")
    }

    func test_recap_tilesLongestAndSummary() throws {
        let facts = try europeRecap()
        XCTAssertEqual(facts.recapTiles, [RecapTile(value: "2", label: "cities"), RecapTile(value: "14,819", label: "miles"),
                                          RecapTile(value: "18", label: "time zones"), RecapTile(value: "1", label: "sunset aloft")])
        XCTAssertEqual(facts.recapLongestLine, "Longest: Dubai → Louisville, 7,382 mi")
        XCTAssertEqual(facts.cardSummary(now: facts.tripMap.span.end, pilotName: "Alex"),
                       "Trip recap: home from 4 days away. 2 cities, 14,819 miles, 18 time zones, 1 sunset from the cockpit. Longest flight, Dubai to Louisville, 7,382 miles.")
    }

    func test_sheetHeadline_afterARecapsTrip_isHomeFromDaysAway() throws {
        let facts = try europeRecap()
        XCTAssertTrue(facts.isRecapOver(at: facts.tripMap.span.end))
        XCTAssertEqual(facts.sheetHeadline(at: facts.tripMap.span.end.addingTimeInterval(3600)), "Home from 4 days away")
    }
}
