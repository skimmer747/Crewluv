//
//  StillOnGroundFactsTests.swift
//  CrewluvTests
//
//  The facts of a flight whose real plane is still on the ground at its departure airport after the plan's takeoff
//  time (which plane design §4), in US English for a family in Louisville. The flight is `FactsTestData`'s equator
//  flight, from E0 to E20: its gates at 10:00 and 13:22 UTC, its plan in the air from 10:15. Here its real plane
//  hasn't left the gate.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class StillOnGroundFactsTests: XCTestCase {

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

    /// The real plane at the gate in E0, last seen there half a minute before `now`.
    private func atTheGate(_ now: String) -> LiveFlight {
        let fix = LiveFlight.Fix(latitude: 0, longitude: 0, altitudeFeet: nil, groundSpeedKnots: 0, trackDegrees: nil,
                                 isOnGround: true, registration: "N370UP", typeCode: "B763", seenAt: at(now).addingTimeInterval(-30))
        return LiveFlight(legID: "eq", callsign: "TST1", state: .ground, fix: fix, landedAt: nil, trail: [])
    }

    /// The facts of a map of the one flight, its real plane at the gate, as the status screen's model hands it on at `now`.
    private func facts(atTheGate now: String, isReplay: Bool = false) throws -> TripFacts {
        try facts(of: try FactsTestData.equatorLiveLeg(atTheGate(now), at: at(now)), isReplay: isReplay)
    }

    private func facts(of leg: MapLeg, isReplay: Bool = false) throws -> TripFacts {
        let home = FactsTestData.homeByTheEquator
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: home,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        return TripFacts(tripMap: map, geography: FactsTestData.equator, comparisons: try FactsTestData.appComparisons(),
                         stories: [leg.id: LegStory(leg: leg, geography: FactsTestData.equator, home: home)],
                         sunEvents: [leg.id: SkyFacts.sunEvents(on: leg)], dayNumber: 1, totalDays: 1,
                         calendar: calendar, locale: locale, isReplay: isReplay)
    }

    private func row(_ kind: FactRow.Kind, in rows: [FactRow]) throws -> FactRow {
        try XCTUnwrap(rows.first { $0.kind == kind }, "no \(kind) row")
    }

    // MARK: - The headline

    func test_headline_atTheGateAfterThePlansTakeoff_isStillOnTheGround_aheadOfAnyEventOrSunCountdown() throws {
        // At 11:20 the plan has the plane past 5° E, where it crossed into Bravo at about 11:00.
        let facts = try facts(atTheGate: "11:20")
        XCTAssertEqual(facts.headline(at: at("11:20")), "Still on the ground in E0")
        XCTAssertEqual(facts.headline(at: at("11:20"), includesEvents: false), "Still on the ground in E0")
        XCTAssertEqual(facts.sheetHeadline(at: at("11:20")), "Still on the ground in E0")
    }

    func test_headline_atTheGateBeforeThePlansTakeoff_isAsBefore() throws {
        XCTAssertEqual(try facts(atTheGate: "10:10").headline(at: at("10:10")), "Over Alpha")
    }

    func test_headline_inAReplay_isWhereTheMapHasThePlane() throws {
        // With no record, a replay's plane is the schedule's, which crossed into Bravo a few minutes before.
        XCTAssertEqual(try facts(atTheGate: "11:20", isReplay: true).headline(at: at("11:20")), "Just crossed into Bravo")
    }

    // MARK: - The rows

    func test_rows_atTheGate_sayItsStillOnTheGround_howFarItHasToGo_andNoSky() throws {
        let rows = try facts(atTheGate: "11:20").rows(at: at("11:20"), now: at("11:20"))
        let below = try row(.below, in: rows)
        XCTAssertEqual(below.title, "Still on the ground in E0")
        // The plan, run from a takeoff that hasn't happened, has the plane at 14° E at 13:06, 9:06 AM in Louisville.
        XCTAssertEqual(plain(below.detail), "Passes 35 mi from home at about 9:06 AM")
        XCTAssertNil(rows.first { $0.kind == .sky })
        let distance = try row(.distance, in: rows)
        XCTAssertEqual(distance.title, "1,382 mi to go")
        XCTAssertEqual(plain(distance.detail), "Halfway at about 8:17 AM · like driving the Alaska Highway")
        // The plane's row has no height or speed: it isn't in the air.
        XCTAssertEqual(try row(.plane, in: rows).title, "Boeing 767-300 · N370UP")
        XCTAssertNil(try row(.plane, in: rows).detail)
    }

    func test_rows_atTheGate_haveNoSky_whereTheScheduleWouldFlyIntoTheNight() throws {
        // At 16:30 the schedule's plane is over the Test Sea, 52 minutes before its cockpit sunset.
        let replayRows = try facts(atTheGate: "16:30", isReplay: true).rows(at: at("16:30"), now: at("16:30"))
        XCTAssertEqual(try row(.sky, in: replayRows).title, "Flying into the night")
        let rows = try facts(atTheGate: "16:30").rows(at: at("16:30"), now: at("16:30"))
        XCTAssertNil(rows.first { $0.kind == .sky })
    }

    func test_rows_atTheGate_leaveOutTheClosestPointToHome_andHalfway_onceTheirGuessesHaveGoneBy() throws {
        // Nearly eight hours on, the guesses from a takeoff that hasn't happened have both gone by: the plan, run from
        // the leg's start to its new end, has the plane past 14° E before 18:00.
        let rows = try facts(atTheGate: "18:00").rows(at: at("18:00"), now: at("18:00"))
        XCTAssertNil(try row(.below, in: rows).detail)
        XCTAssertFalse(try row(.distance, in: rows).detail?.contains("Halfway") ?? false)
    }

    func test_rows_atTheGateBeforeThePlansTakeoff_areAsBefore() throws {
        let rows = try facts(atTheGate: "10:10").rows(at: at("10:10"), now: at("10:10"))
        XCTAssertEqual(try row(.below, in: rows).title, "Over Alpha")
        XCTAssertEqual(try row(.distance, in: rows).title, "0 mi flown · 1,382 to go")
    }

    // MARK: - The banner and the list

    func test_latestEvent_atTheGate_isNone() throws {
        XCTAssertNil(try facts(atTheGate: "11:20").latestEvent(at: at("11:20")))
    }

    func test_tripSoFar_atTheGate_leavesTheFlightOutUntilItTakesOff() throws {
        let soFar = try facts(atTheGate: "11:20").tripSoFar(at: at("11:20"))
        XCTAssertEqual(soFar.flights.map(\.id), [])
        XCTAssertNotNil(soFar.totals)
    }

    func test_tripSoFar_listsTheFlight_onceItsTakenOff() throws {
        let inTheAir = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("11:20")), at: at("11:20"))
        let soFar = try facts(of: inTheAir).tripSoFar(at: at("11:20"))
        XCTAssertEqual(soFar.flights.map(\.id), ["eq"])
        XCTAssertEqual(soFar.flights.first?.tag, "In the air now")
    }

    // MARK: - The card's sentence and the timeline

    func test_cardSummary_atTheGate_saysSo_withNothingBelowAndNoLatestEvent() throws {
        XCTAssertEqual(plain(try facts(atTheGate: "11:20").cardSummary(now: at("11:20"), pilotName: "Alex")),
                       "TST1 to E20, still on the ground, 1 hour 5 minutes behind schedule. Lands about 10:27 AM your time.")
    }

    func test_stillOnGroundAirport_isTheDepartureAirport_nowOnly() throws {
        XCTAssertEqual(try facts(atTheGate: "11:20").stillOnGroundAirport(at: at("11:20"))?.code, "E0")
        XCTAssertNil(try facts(atTheGate: "11:20", isReplay: true).stillOnGroundAirport(at: at("11:20")))
        XCTAssertNil(try facts(atTheGate: "10:10").stillOnGroundAirport(at: at("10:10")))
    }
}
