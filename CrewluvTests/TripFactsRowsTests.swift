//
//  TripFactsRowsTests.swift
//  CrewluvTests
//
//  The sheet's rows (Stage 2 spec §5), in US English for a family in Louisville.
//

import XCTest
@testable import Crewluv

final class TripFactsRowsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }
    private let start = TripMapTestLegs.tripStart

    private func plain(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private func facts(_ map: TripMap, forecasts: [String: LandingForecast] = [:]) throws -> TripFacts {
        let home = map.home
        let stories = Dictionary(uniqueKeysWithValues: map.legs.map { ($0.id, LegStory(leg: $0, geography: FactsTestData.equator, home: home)) })
        let sunEvents = Dictionary(uniqueKeysWithValues: map.legs.map { ($0.id, SkyFacts.sunEvents(on: $0)) })
        return TripFacts(tripMap: map, geography: FactsTestData.equator, comparisons: try FactsTestData.appComparisons(),
                         stories: stories, sunEvents: sunEvents, forecasts: forecasts, calendar: calendar, locale: locale)
    }

    private func equatorMap() -> TripMap {
        let leg = FactsTestData.equatorFlight(from: 0, to: 20)
        return TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: FactsTestData.mark("HOME", latitude: 0.5, longitude: 14),
                       span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
    }

    private func row(_ kind: FactRow.Kind, in rows: [FactRow]) throws -> FactRow {
        try XCTUnwrap(rows.first { $0.kind == kind }, "no \(kind) row")
    }

    // MARK: - In flight (§5.1)

    func test_rows_inFlight_belowDistanceAndLanding() throws {
        let rows = try facts(equatorMap()).rows(at: FactsTestData.date("2026-03-20T11:10:00Z"), now: FactsTestData.date("2026-03-20T11:10:00Z"))
        XCTAssertEqual(rows.map(\.kind), [.below, .distance, .headed], "no sky row: midday, eastbound, and no moon")

        let below = try row(.below, in: rows)
        XCTAssertEqual(below.title, "Over Bravo, near Testville")
        XCTAssertEqual(plain(below.detail), "Passes 35 mi from home at 8:21 AM")

        let distance = try row(.distance, in: rows)
        XCTAssertEqual(distance.title, "422 mi flown · 960 to go")
        XCTAssertEqual(plain(distance.detail), "Halfway at 7:45 AM · Averaging about 460 mph · like driving the Alaska Highway")

        let headed = try row(.headed, in: rows)
        XCTAssertEqual(plain(headed.title), "Lands E20 9:22 AM")
        XCTAssertNil(headed.detail)
    }

    func test_rows_inFlight_weatherOnlyForALandingStillAhead() throws {
        let withWeather = try facts(equatorMap(), forecasts: ["eq": LandingForecast(temperature: "81°F", condition: "clear")])
        let shown = FactsTestData.date("2026-03-20T11:10:00Z")

        let live = try row(.headed, in: withWeather.rows(at: shown, now: shown))
        XCTAssertEqual(live.detail, "81°F and clear on landing")
        XCTAssertTrue(live.hasWeather)

        let replayed = try row(.headed, in: withWeather.rows(at: shown, now: FactsTestData.date("2026-03-20T14:00:00Z")))
        XCTAssertNil(replayed.detail, "the landing has happened in real time")
        XCTAssertFalse(replayed.hasWeather)
    }

    func test_rows_inFlight_theSkyBeforeACockpitSunset() throws {
        let departure = FactsTestData.date("2026-11-13T18:00:00Z")
        let leg = MapLeg(id: "evening", kind: .flight,
                         origin: AirportMark(code: "SDF", city: "Louisville", coordinate: TripMapTestLegs.airports["SDF"]!, timeZone: nil),
                         destination: AirportMark(code: "CGN", city: "Cologne", coordinate: TripMapTestLegs.airports["CGN"]!, timeZone: nil),
                         start: departure, end: departure.addingTimeInterval(8 * 3600), flightNumber: "UPS207")
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: nil, span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        let at = FactsTestData.date("2026-11-13T20:30:00Z")
        let sky = try row(.sky, in: try facts(map).rows(at: at, now: at))
        XCTAssertEqual(sky.title, "Flying into the night")
        XCTAssertEqual(sky.detail, "Sunset in 17 min, about 21 min after the people below")
        XCTAssertEqual(sky.symbolName, "sunset.fill")
    }

    // MARK: - On a layover (§5.3)

    func test_rows_onALayoverInCologne() throws {
        let at = start.addingTimeInterval(12 * 3600)
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: at))
        let rows = try facts(map).rows(at: at, now: at)
        XCTAssertEqual(rows.map(\.kind), [.whereTheyAre, .nextFlight, .tripSoFar])

        let here = try row(.whereTheyAre, in: rows)
        XCTAssertEqual(here.title, "In Cologne")
        XCTAssertEqual(plain(here.detail), "6 hours ahead of you · sunrise at 7:45 AM there")

        let next = try row(.nextFlight, in: rows)
        XCTAssertEqual(plain(next.title), "Next: Dubai, tomorrow 3:00 PM")
        XCTAssertEqual(plain(next.detail), "3,086 mi, like driving coast to coast · lands 6:00 AM there")

        XCTAssertEqual(try row(.tripSoFar, in: rows).detail, "1 city · 4,351 mi · 6 time zones · 1 sunset from the cockpit")
    }

    // MARK: - At home before a trip (§5.4)

    func test_rows_atHomeTheDayBefore() throws {
        let at = start.addingTimeInterval(-24 * 3600)
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), isNextTrip: true, at: at))
        let rows = try facts(map).rows(at: at, now: at)
        XCTAssertEqual(rows.map(\.kind), [.leaves, .tripAhead, .onTheWay])

        let leaves = try row(.leaves, in: rows)
        XCTAssertEqual(plain(leaves.title), "Leaves tomorrow 7:00 AM")
        XCTAssertEqual(leaves.detail, "UPS207 to Cologne")

        XCTAssertEqual(try row(.tripAhead, in: rows).detail, "4 days · Cologne, Dubai · 14,819 mi · like digging straight through the Earth twice")
        XCTAssertEqual(try row(.onTheWay, in: rows).detail, "18 time zones · a sunset from the cockpit")
    }

    // MARK: - The recap (§5.5)

    func test_rows_afterARecapsTrip() throws {
        let map = try XCTUnwrap(TripMap.make(tripLegs: TripMapTestLegs.europeTrip(), isNextTrip: false, isRecap: true, homeAirportCode: "SDF",
                                             legacyDelayMinutes: nil, at: start, coordinate: TripMapTestLegs.coordinate))
        let at = map.span.end.addingTimeInterval(3600)
        let rows = try facts(map).rows(at: at, now: at)
        XCTAssertEqual(rows.map(\.kind), [.theTrip, .onTheWay, .longestFlight])
        XCTAssertEqual(try row(.theTrip, in: rows).detail, "4 days · Cologne, Dubai · 14,819 mi · like digging straight through the Earth twice")
        XCTAssertEqual(try row(.onTheWay, in: rows).detail, "18 time zones · 1 sunset from the cockpit")
        XCTAssertEqual(try row(.longestFlight, in: rows).detail, "Dubai → Louisville, 7,382 mi")
    }

    // MARK: - On a drive

    func test_rows_onADriveWithNothingFlown_isEmpty() throws {
        let drive = MapLeg(id: "d", kind: .drive,
                           origin: FactsTestData.mark("LEX", latitude: 38.04, longitude: -84.61, city: "Lexington"),
                           destination: FactsTestData.mark("SDF", latitude: 38.17, longitude: -85.74, city: "Louisville"),
                           start: start, end: start.addingTimeInterval(3600), flightNumber: nil)
        let map = TripMap(mode: .onTrip, legs: [drive], home: nil, span: DateInterval(start: drive.start, end: drive.end), tripDays: nil)
        let at = start.addingTimeInterval(1800)
        XCTAssertEqual(try facts(map).rows(at: at, now: at), [])
    }
}
