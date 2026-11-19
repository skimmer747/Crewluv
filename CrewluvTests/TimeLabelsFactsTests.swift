//
//  TimeLabelsFactsTests.swift
//  CrewluvTests
//
//  The facts with every time saying whose it is (time labels design §3.3, §3.4): the takeoff row, the bold newest
//  event, and VoiceOver's "your time". The made-up flight is `FactsTestData`'s, along the equator from 10:00 UTC, for a
//  family in Louisville (EDT on 20 March). Its real plane is first seen at 10:17, 17 mi from the departure airport, and
//  the schedule takes off at 10:15, after its taxi allowance. Its airports have no time zone, so only the family's
//  time shows.
//

import XCTest
@testable import Crewluv

final class TimeLabelsFactsTests: XCTestCase {

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

    private func facts(seenUntil: String, now: String? = nil, isReplay: Bool = false) throws -> TripFacts {
        let live = FactsTestData.equatorLive(seenUntil: at(seenUntil))
        return try facts(of: try FactsTestData.equatorLiveLeg(live, at: at(now ?? seenUntil)), isReplay: isReplay)
    }

    private func facts(of leg: MapLeg, isReplay: Bool = false,
                       takeoffForecasts: [String: LandingForecast] = [:]) throws -> TripFacts {
        let home = FactsTestData.homeByTheEquator
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: home,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        return TripFacts(tripMap: map, geography: FactsTestData.equator, comparisons: try FactsTestData.appComparisons(),
                         stories: [leg.id: LegStory(leg: leg, geography: FactsTestData.equator, home: home)],
                         sunEvents: [leg.id: SkyFacts.sunEvents(on: leg)], takeoffForecasts: takeoffForecasts,
                         dayNumber: 1, totalDays: 1, calendar: calendar, locale: locale, isReplay: isReplay)
    }

    // MARK: - The takeoff row (§3.3)

    func test_takeoffRow_theRealPlanesTakeoff_hasNoAbout() throws {
        let rows = try facts(seenUntil: "11:10").rows(at: at("11:10"), now: at("11:10"))
        let takeoff = try XCTUnwrap(rows.first { $0.kind == .takeoff })
        XCTAssertEqual(plain(takeoff.title), "Took off E0 6:17 AM L")
        XCTAssertEqual(takeoff.symbolName, "airplane.departure")
        XCTAssertNil(takeoff.detail)
    }

    func test_takeoffRow_withNoRealPlane_isTheSchedules_withAbout() throws {
        let rows = try facts(of: FactsTestData.equatorFlight(from: 0, to: 20)).rows(at: at("11:10"), now: at("11:10"))
        XCTAssertEqual(plain(rows.first { $0.kind == .takeoff }?.title), "Took off E0 about 6:15 AM L")
    }

    func test_takeoffRow_withTheTakeoffHoursWeather_saysIt_andNeedsApplesCredit() throws {
        let leg = FactsTestData.equatorFlight(from: 0, to: 20)
        let weather = LandingForecast(temperature: "84°F", condition: "clear")
        let rows = try facts(of: leg, takeoffForecasts: [leg.id: weather]).rows(at: at("11:10"), now: at("11:10"))
        let takeoff = try XCTUnwrap(rows.first { $0.kind == .takeoff })
        XCTAssertEqual(takeoff.detail, "84°F and clear at takeoff")
        XCTAssertTrue(takeoff.hasWeather)
    }

    func test_takeoffRow_withNoWeather_hasNoSecondLine() throws {
        let rows = try facts(of: FactsTestData.equatorFlight(from: 0, to: 20)).rows(at: at("11:10"), now: at("11:10"))
        let takeoff = try XCTUnwrap(rows.first { $0.kind == .takeoff })
        XCTAssertNil(takeoff.detail)
        XCTAssertFalse(takeoff.hasWeather)
    }

    func test_takeoffRow_beforeTheSchedulesTakeoff_isLeftOut() throws {
        let rows = try facts(of: FactsTestData.equatorFlight(from: 0, to: 20)).rows(at: at("10:10"), now: at("10:10"))
        XCTAssertFalse(rows.contains { $0.kind == .takeoff }, "taxiing out at 10:10")
    }

    func test_takeoffRow_aRealPlaneFirstSeenFarOut_isLeftOut() throws {
        // Nobody saw it before 1° E, 69 mi out: when it left can't be told, and the schedule's time could be far off.
        let live = FactsTestData.equatorLive(seenUntil: at("11:10"), unseen: -1...1)
        let rows = try facts(of: try FactsTestData.equatorLiveLeg(live, at: at("11:10"))).rows(at: at("11:10"), now: at("11:10"))
        XCTAssertFalse(rows.contains { $0.kind == .takeoff })
        XCTAssertTrue(rows.contains { $0.kind == .headed })
    }

    func test_takeoffRow_comesJustAboveTheLandingRow() throws {
        let kinds = try facts(seenUntil: "11:10").rows(at: at("11:10"), now: at("11:10")).map(\.kind)
        let takeoff = try XCTUnwrap(kinds.firstIndex(of: .takeoff))
        XCTAssertEqual(kinds.index(after: takeoff), kinds.firstIndex(of: .headed))
    }

    func test_takeoffLine_aDepartureAirportOnAnotherClock_givesBothTimes() {
        let taipei = FactsTestData.mark("TPE", latitude: 25.08, longitude: 121.23, city: "Taipei", zone: "Asia/Taipei")
        let anchorage = FactsTestData.mark("ANC", latitude: 61.17, longitude: -150.0, city: "Anchorage", zone: "America/Anchorage")
        let leg = MapLeg(id: "f", kind: .flight, origin: taipei, destination: anchorage,
                         start: at("11:30"), end: at("19:30"), flightNumber: "UPS95")
        let words = TripMapWording.takeoffLine(for: leg, at: at("11:42"), isEstimate: false, calendar: calendar, locale: locale)
        XCTAssertEqual(plain(words), "Took off Taipei 7:42 PM · 7:42 AM L")
        let guessed = TripMapWording.takeoffLine(for: leg, at: at("11:42"), isEstimate: true, calendar: calendar, locale: locale)
        XCTAssertEqual(plain(guessed), "Took off Taipei about 7:42 PM · 7:42 AM L")
    }

    func test_takeoffLine_aDepartureAirportOnTheFamilysClock_givesOneTime() {
        let louisville = FactsTestData.mark("SDF", latitude: 38.17, longitude: -85.74, city: "Louisville", zone: "America/New_York")
        let leg = MapLeg(id: "f", kind: .flight, origin: louisville, destination: louisville,
                         start: at("13:00"), end: at("15:00"), flightNumber: nil)
        XCTAssertEqual(plain(TripMapWording.takeoffLine(for: leg, at: at("13:05"), isEstimate: false, calendar: calendar, locale: locale)),
                       "Took off Louisville 9:05 AM L")
    }

    // MARK: - The newest event, bold (§3.4)

    func test_tripSoFar_theFlightInTheAir_marksItsNewestEventCurrent() throws {
        let tripSoFar = try facts(seenUntil: "12:30").tripSoFar(at: at("12:30"))
        XCTAssertEqual(tripSoFar.flights.first?.events.map(\.isCurrent), [true, false, false, false])
    }

    func test_tripSoFar_aReplaysMoment_marksItsNewestEventCurrent() throws {
        let tripSoFar = try facts(seenUntil: "12:30", isReplay: true).tripSoFar(at: at("11:10"))
        XCTAssertEqual(tripSoFar.flights.first?.events.map(\.isCurrent), [true])
    }

    func test_tripSoFar_aFlightThatsOver_hasNoCurrentEvent() throws {
        let tripSoFar = try facts(of: FactsTestData.equatorFlight(from: 0, to: 20)).tripSoFar(at: at("14:00"))
        let events = try XCTUnwrap(tripSoFar.flights.first?.events)
        XCTAssertFalse(events.isEmpty)
        XCTAssertFalse(events.contains(where: \.isCurrent))
    }

    // MARK: - VoiceOver

    func test_rowSentence_saysYourTime_forTheL() throws {
        let rows = try facts(seenUntil: "11:10").rows(at: at("11:10"), now: at("11:10"))
        XCTAssertEqual(plain(rows.first { $0.kind == .takeoff }?.sentence), "Took off E0 6:17 AM your time")
        XCTAssertEqual(plain(rows.first { $0.kind == .headed }?.sentence), "Lands E20 about 9:11 AM your time")
    }
}
