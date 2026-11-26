//
//  LandedBeforeGateFactsTests.swift
//  CrewluvTests
//
//  The facts and the list of a flight whose real plane is down at its arrival airport and not yet at the gate
//  (landed before the gate design §3), in US English for a family in Louisville. The flight is `FactsTestData`'s
//  equator flight, from E0 to E20, 1,382 mi: its real plane is seen down at E20 at 12:55 UTC and reaches the gate at
//  13:02, which is 9:02 AM in Louisville.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LandedBeforeGateFactsTests: XCTestCase {

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

    /// The facts of a map of the one flight, its real plane down at E20 since 12:55, made at `now`. A cockpit sunset
    /// at 13:20 stands in for the sky, so its row would show if it weren't left out.
    private func facts(landedAt now: String, isReplay: Bool = false) throws -> TripFacts {
        let live = FactsTestData.equatorLive(seenUntil: at("12:53"), landedAt: FactsTestData.liveTime(atLongitude: 20))
        let leg = try FactsTestData.equatorLiveLeg(live, at: at(now))
        let home = FactsTestData.homeByTheEquator
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: home,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        return TripFacts(tripMap: map, geography: FactsTestData.equator, comparisons: try FactsTestData.appComparisons(),
                         stories: [leg.id: LegStory(leg: leg, geography: FactsTestData.equator, home: home)],
                         sunEvents: [leg.id: [SkyFacts.SunEvent(kind: .sunset, time: at("13:20"), peopleBelowGap: nil)]],
                         dayNumber: 1, totalDays: 1,
                         calendar: calendar, locale: locale, isReplay: isReplay)
    }

    private func row(_ kind: FactRow.Kind, in rows: [FactRow]) throws -> FactRow {
        try XCTUnwrap(rows.first { $0.kind == kind }, "no \(kind) row")
    }

    // MARK: - The headline and the rows

    func test_headline_saysWhereItLanded() throws {
        XCTAssertEqual(try facts(landedAt: "12:58").headline(at: at("12:58")), "Landed in E20")
        XCTAssertEqual(try facts(landedAt: "12:58").sheetHeadline(at: at("12:58")), "Landed in E20")
    }

    func test_rows_sayItsTrackedLive_itLanded_howFarItFlew_andWhenItReachesTheGate_withNoSky() throws {
        let rows = try facts(landedAt: "12:58").rows(at: at("12:58"), now: at("12:58"))
        XCTAssertEqual(rows.map(\.kind), [.source, .below, .plane, .distance, .takeoff, .headed])
        XCTAssertEqual(try row(.source, in: rows).title, "Tracked live")
        let below = try row(.below, in: rows)
        XCTAssertEqual(below.title, "Landed in E20")
        XCTAssertNil(below.detail, "nothing of what's below, or of home")
        XCTAssertEqual(try row(.distance, in: rows).title, "1,382 mi flown")
        XCTAssertEqual(plain(try row(.headed, in: rows).title), "Reaches the gate in E20 at 9:02 AM L")
        XCTAssertEqual(try row(.plane, in: rows).title, "Boeing 767-300 · N370UP")
        XCTAssertNil(try row(.plane, in: rows).detail, "no height or speed on the ground")
    }

    func test_inAReplay_theFactsReadWhereTheMapHasThePlane_asBefore() throws {
        let replay = try facts(landedAt: "12:58", isReplay: true)
        let rows = replay.rows(at: at("12:58"), now: at("12:58"))
        XCTAssertTrue(rows.contains { $0.kind == .sky }, "the sky row, as before")
        XCTAssertEqual(try row(.distance, in: rows).title, "1,382 mi flown · 0 to go")
        XCTAssertTrue(try XCTUnwrap(plain(try row(.headed, in: rows).title)).hasPrefix("Lands E20"))
        XCTAssertNil(replay.flightNow(at: at("12:58")))
    }

    // MARK: - The list

    func test_tripSoFar_tagsTheFlight_landed_untilTheGate() throws {
        XCTAssertEqual(try facts(landedAt: "12:58").tripSoFar(at: at("12:58")).flights.map(\.tag), ["Landed"])
        XCTAssertEqual(try facts(landedAt: "12:58", isReplay: true).tripSoFar(at: at("12:58")).flights.map(\.tag), ["In the air"])
        XCTAssertEqual(try facts(landedAt: "13:03").tripSoFar(at: at("13:03")).flights.map(\.tag), [nil], "at the gate")
    }

    func test_flightNow_isLandedInTheArrivalAirport_now() throws {
        let flight = try facts(landedAt: "12:58").flightNow(at: at("12:58"))
        guard case .landedIn(let airport) = flight else { return XCTFail("\(String(describing: flight))") }
        XCTAssertEqual(airport.code, "E20")
    }

    // MARK: - The words

    func test_factsWords_sayItLanded_andHowFarItFlew() {
        let anchorage = AirportMark(code: "ANC", city: "Anchorage", coordinate: CLLocationCoordinate2D(latitude: 61.2, longitude: -150.0),
                                    timeZone: TimeZone(identifier: "America/Anchorage"))
        XCTAssertEqual(FactsWording.landed(in: anchorage), "Landed in Anchorage")
        XCTAssertEqual(FactsWording.flown(miles: 2_788, locale: locale), "2,788 mi flown")
        XCTAssertEqual(FactsWording.landedTag, "Landed")
    }

    func test_gateLine_saysAt_inTheCitysTimeAndTheFamilys() {
        let louisville = AirportMark(code: "SDF", city: "Louisville", coordinate: CLLocationCoordinate2D(latitude: 38.2, longitude: -85.7),
                                     timeZone: TimeZone(identifier: "America/New_York"))
        let anchorage = AirportMark(code: "ANC", city: "Anchorage", coordinate: CLLocationCoordinate2D(latitude: 61.2, longitude: -150.0),
                                    timeZone: TimeZone(identifier: "America/Anchorage"))
        // At the gate at 00:52 UTC: 3:52 PM in Anchorage, 7:52 PM in Louisville.
        let end = FactsTestData.date("2026-11-14T00:52:00Z")
        let toAnchorage = MapLeg(id: "f1", kind: .flight, origin: louisville, destination: anchorage,
                                 start: end.addingTimeInterval(-6 * 3600), end: end, flightNumber: "UPS2963")
        XCTAssertEqual(plain(TripMapWording.gateLine(for: toAnchorage, calendar: calendar, locale: locale)),
                       "Reaches the gate in Anchorage at 3:52 PM · 7:52 PM L")
        let home = MapLeg(id: "f2", kind: .flight, origin: anchorage, destination: louisville,
                          start: end.addingTimeInterval(-6 * 3600), end: end, flightNumber: "UPS2964")
        XCTAssertEqual(plain(TripMapWording.gateLine(for: home, calendar: calendar, locale: locale)), "Reaches the gate in Louisville at 7:52 PM L")
    }
}
