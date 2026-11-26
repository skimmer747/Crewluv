//
//  LiveOrScheduledFactsTests.swift
//  CrewluvTests
//
//  The facts and the list say how the flight between its gates is known (live or scheduled design §4, §5, §6), in US
//  English for a family in Louisville. The equator flight (FactsTestData) leaves its gate at 10:00 UTC (6:00 AM in
//  Louisville), takes off at 10:15, crosses into Bravo at 11:00, is halfway at 11:45, passes 35 mi from home at 12:21
//  and reaches its gate at 13:22.
//

import XCTest
@testable import Crewluv

final class LiveOrScheduledFactsTests: XCTestCase {

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

    private let home = FactsTestData.mark("HOME", latitude: 0.5, longitude: 14)

    /// The facts of a map of `legs`, the last of them in the air.
    private func makeFacts(_ legs: [MapLeg], isReplay: Bool = false) -> TripFacts {
        let map = TripMap(mode: .inFlight(legID: legs[legs.count - 1].id), legs: legs, home: home,
                          span: DateInterval(start: legs[0].start, end: legs[legs.count - 1].end), tripDays: nil)
        var stories: [String: LegStory] = [:]
        var sunEvents: [String: [SkyFacts.SunEvent]] = [:]
        for leg in legs {
            stories[leg.id] = LegStory(leg: leg, geography: FactsTestData.equator, home: home)
            sunEvents[leg.id] = SkyFacts.sunEvents(on: leg)
        }
        return TripFacts(tripMap: map, geography: FactsTestData.equator, comparisons: nil, stories: stories,
                         sunEvents: sunEvents, dayNumber: 1, totalDays: 1, calendar: calendar, locale: locale,
                         isReplay: isReplay)
    }

    /// The equator flight by the schedule alone, with a plan of its own and no live data, or waiting for it.
    private func bySchedule(isAwaitingLive: Bool = false) -> MapLeg {
        let leg = FactsTestData.equatorFlight(from: 0, to: 20)
        let flight = MapFlight(departure: leg.start, arrival: leg.end, from: leg.origin.coordinate, to: leg.destination.coordinate)
        return MapLeg(id: leg.id, kind: leg.kind, origin: leg.origin, destination: leg.destination, start: leg.start, end: leg.end,
                      flightNumber: leg.flightNumber, flight: flight, isAwaitingLive: isAwaitingLive)
    }

    // MARK: - By the schedule, before its takeoff (§4.2)

    func test_headline_beforeTheSchedulesTakeoff_saysWhenItsScheduledToTakeOff() {
        XCTAssertEqual(plain(makeFacts([bySchedule()]).headline(at: at("10:05"))), "Scheduled to take off about 6:15 AM L")
    }

    func test_rows_beforeTheSchedulesTakeoff_leadWithTheSource_thenTheTakeoff_theMilesToGo_andTheLanding() {
        let rows = makeFacts([bySchedule()]).rows(at: at("10:05"), now: at("10:05"))
        XCTAssertEqual(rows.map(\.kind), [.source, .below, .distance, .headed])
        XCTAssertEqual(rows[0].symbolName, "calendar")
        XCTAssertEqual(rows[0].title, "Not tracked live")
        XCTAssertEqual(rows[0].detail, "Shown where the schedule has it · If it's running late, it may still be at the gate")
        XCTAssertEqual(rows[1].symbolName, "airplane.departure")
        XCTAssertEqual(plain(rows[1].title), "Scheduled to take off about 6:15 AM L")
        XCTAssertEqual(rows[2].title, "1,382 mi to go")
        XCTAssertTrue(plain(rows[2].detail)?.contains("Halfway at about 7:45 AM L") == true, rows[2].detail ?? "")
    }

    func test_beforeTheSchedulesTakeoff_thereIsNoLatestEvent_andTheListTagsTheFlightByTheSchedule() {
        let facts = makeFacts([bySchedule()])
        XCTAssertNil(facts.latestEvent(at: at("10:05")))
        let soFar = facts.tripSoFar(at: at("10:05"))
        XCTAssertEqual(soFar.flights.map(\.tag), ["By the schedule"])
        XCTAssertEqual(soFar.flights.first?.events.count, 0)
    }

    func test_cardSummary_beforeTheSchedulesTakeoff_saysWhenItsScheduledToTakeOff_andThatItsNotTracked() {
        XCTAssertEqual(plain(makeFacts([bySchedule()]).cardSummary(now: at("10:05"), pilotName: "Alex")),
                       "TST1 to E20, scheduled to take off about 6:15 AM your time. Lands at 9:22 AM your time. " +
                       "Not tracked live, so it's shown where the schedule has it.")
    }

    func test_waitingForTheFirstAnswer_beforeItsTakeoff_saysWhenItsScheduledToTakeOff_withNoSourceRow() {
        let facts = makeFacts([bySchedule(isAwaitingLive: true)])
        XCTAssertEqual(plain(facts.headline(at: at("10:05"))), "Scheduled to take off about 6:15 AM L")
        XCTAssertEqual(facts.rows(at: at("10:05"), now: at("10:05")).map(\.kind), [.below, .distance, .headed])
    }

    // MARK: - By the schedule, in the air (§4.1, §5)

    func test_inTheAir_theHeadlineIsWhatsBelow_underTheSourceRow() {
        let facts = makeFacts([bySchedule()])
        XCTAssertEqual(facts.headline(at: at("11:10")), "Over Bravo, near Testville")
        XCTAssertEqual(facts.rows(at: at("11:10"), now: at("11:10")).first?.title, "Not tracked live")
    }

    func test_inTheAir_itsEventsHalfwayAndClosestPointReadAbout() throws {
        let facts = makeFacts([bySchedule()])
        XCTAssertEqual(facts.latestEvent(at: at("11:10"))?.when, "About 10 min ago")
        let soFar = facts.tripSoFar(at: at("11:10"))
        XCTAssertEqual(soFar.flights.first?.tag, "By the schedule")
        let events = try XCTUnwrap(soFar.flights.first?.events)
        XCTAssertFalse(events.isEmpty)
        XCTAssertTrue(events.allSatisfy(\.isEstimate))
        let rows = facts.rows(at: at("11:10"), now: at("11:10"))
        let distance = try XCTUnwrap(rows.first { $0.kind == .distance })
        XCTAssertTrue(plain(distance.detail)?.contains("Halfway at about 7:45 AM L") == true, distance.detail ?? "")
        let below = try XCTUnwrap(rows.first { $0.kind == .below })
        XCTAssertEqual(plain(below.detail), "Passes 35 mi from home at about 8:21 AM L")
    }

    func test_whileWaitingForTheFirstAnswer_thereIsNoSourceRow_andTheListStillSaysByTheSchedule() {
        let facts = makeFacts([bySchedule(isAwaitingLive: true)])
        XCTAssertFalse(facts.rows(at: at("11:10"), now: at("11:10")).contains { $0.kind == .source })
        XCTAssertEqual(facts.tripSoFar(at: at("11:10")).flights.first?.tag, "By the schedule")
    }

    func test_aReplay_readsAsBefore_withNoSourceRow_itsEventsNotGuesses_andByTheScheduleWithNoRealPath() throws {
        let facts = makeFacts([bySchedule()], isReplay: true)
        XCTAssertFalse(facts.rows(at: at("11:10"), now: at("11:10")).contains { $0.kind == .source })
        XCTAssertFalse(facts.latestEvent(at: at("11:10"))?.when.hasPrefix("About") ?? true)
        let soFar = facts.tripSoFar(at: at("11:10"))
        XCTAssertEqual(soFar.flights.first?.tag, "By the schedule")
        XCTAssertTrue(try XCTUnwrap(soFar.flights.first?.events).allSatisfy { !$0.isEstimate })
    }

    func test_anEarlierFlightsEvents_readAsBefore() throws {
        let first = bySchedule()
        let later = FactsTestData.equatorFlight(from: 20, to: 40, departure: first.start.addingTimeInterval(5 * 3600), id: "eq2")
        let soFar = makeFacts([first, later]).tripSoFar(at: first.start.addingTimeInterval(6 * 3600))
        let earlier = try XCTUnwrap(soFar.flights.first { $0.id == "eq" })
        XCTAssertFalse(earlier.events.isEmpty)
        XCTAssertTrue(earlier.events.allSatisfy { !$0.isEstimate })
    }

    // MARK: - Tracked live (§4.1, §4.2)

    func test_aPlaneSeenInTheAir_leadsWithTrackedLive() throws {
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("10:55")), at: at("10:55"))
        let row = try XCTUnwrap(makeFacts([leg]).rows(at: at("10:55"), now: at("10:55")).first)
        XCTAssertEqual(row.kind, .source)
        XCTAssertEqual(row.symbolName, "dot.radiowaves.left.and.right")
        XCTAssertEqual(row.title, "Tracked live")
        XCTAssertNil(row.detail)
    }

    func test_aBestGuess_hasNoSourceRow() throws {
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("10:55")), at: at("11:05"))
        XCTAssertEqual(leg.tracking(at: at("11:05")), .bestGuess)
        XCTAssertFalse(makeFacts([leg]).rows(at: at("11:05"), now: at("11:05")).contains { $0.kind == .source })
    }

    func test_aRealPlaneAtItsGateBeforeThePlansTakeoff_isOnTheGround_withNoSky_nothingListed_andNoLatestEvent() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "on the ground before the plan's takeoff")
        let moment = try cases.moment("13T12:10:00", of: flightCase)
        let leg = try cases.mapLeg(flightCase, at: moment)
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: leg.origin,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        let facts = TripFacts(tripMap: map, geography: nil, comparisons: nil, stories: [:], sunEvents: [:],
                              calendar: calendar, locale: locale)
        XCTAssertEqual(facts.headline(at: moment.at), "On the ground in SDF")
        let rows = facts.rows(at: moment.at, now: moment.at)
        XCTAssertEqual(rows.first?.title, "Tracked live")
        XCTAssertEqual(rows.first { $0.kind == .below }?.title, "On the ground in SDF")
        XCTAssertFalse(rows.contains { $0.kind == .sky })
        XCTAssertTrue(rows.first { $0.kind == .distance }?.title.hasSuffix("mi to go") == true)
        XCTAssertTrue(facts.tripSoFar(at: moment.at).flights.isEmpty)
        XCTAssertNil(facts.latestEvent(at: moment.at))
        XCTAssertEqual(plain(facts.cardSummary(now: moment.at, pilotName: "Alex")),
                       "UPS207 to PHL, on the ground in SDF. Lands at 8:45 AM your time. Tracked live.")
    }
}
