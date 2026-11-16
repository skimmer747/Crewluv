//
//  LiveTripFactsTests.swift
//  CrewluvTests
//
//  The headline, the rows and the card's sentence for a flight with a real plane (Stage 3 spec §8, §9, §15), in US
//  English for a family in Louisville. The made-up real plane is `FactsTestData`'s: a degree of longitude every
//  8 minutes from 10:15 UTC, so it's at 5° E at 10:55 (6:55 AM in Louisville), 10° E at 11:35 and 14° E at 12:07.
//  One degree along the equator is 69.09 mi, and the flight is 1,382 mi.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LiveTripFactsTests: XCTestCase {

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

    /// The facts of a map of the one flight, with the real plane last seen at `seenUntil` and the map made at `now`.
    private func facts(seenUntil: String, now: String? = nil, unseen: ClosedRange<Double>? = nil, landed: Bool = false,
                       hasStory: Bool = true, isReplay: Bool = false, typeCode: String? = "B763",
                       registration: String? = "N370UP") throws -> TripFacts {
        let landedAt = landed ? FactsTestData.liveTime(atLongitude: 20) : nil
        let live = FactsTestData.equatorLive(seenUntil: at(seenUntil), unseen: unseen, landedAt: landedAt,
                                             typeCode: typeCode, registration: registration)
        return try facts(of: try FactsTestData.equatorLiveLeg(live, at: at(now ?? seenUntil)), hasStory: hasStory, isReplay: isReplay)
    }

    private func facts(of leg: MapLeg, hasStory: Bool = true, isReplay: Bool = false) throws -> TripFacts {
        let home = FactsTestData.homeByTheEquator
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: home,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        return TripFacts(tripMap: map, geography: hasStory ? FactsTestData.equator : nil, comparisons: try FactsTestData.appComparisons(),
                         stories: hasStory ? [leg.id: LegStory(leg: leg, geography: FactsTestData.equator, home: home)] : [:],
                         sunEvents: [leg.id: SkyFacts.sunEvents(on: leg)], dayNumber: 1, totalDays: 1,
                         calendar: calendar, locale: locale, isReplay: isReplay)
    }

    private func row(_ kind: FactRow.Kind, in rows: [FactRow]) throws -> FactRow {
        try XCTUnwrap(rows.first { $0.kind == kind }, "no \(kind) row")
    }

    // MARK: - The headline (§8, §9)

    func test_headline_isWhatsBelowTheRealPlane_notTheSchedules() throws {
        // At 11:10 the real plane is at 6.875° E, 64 mi from Testville. The schedule's is at 6.1° E, beside it.
        XCTAssertEqual(try facts(seenUntil: "11:10").headline(at: at("11:10")), "Over Bravo")
        let scheduled = try facts(of: FactsTestData.equatorFlight(from: 0, to: 20))
        XCTAssertEqual(scheduled.headline(at: at("11:10")), "Over Bravo, near Testville")
    }

    func test_headline_aCrossing_leadsWhenTheRealPlaneCrosses() throws {
        // It crossed into Bravo at 10:55. The schedule's plane crosses at 11:00.
        XCTAssertEqual(try facts(seenUntil: "10:57").headline(at: at("10:57")), "Just crossed into Bravo")
        XCTAssertEqual(try facts(seenUntil: "10:53").headline(at: at("10:53")), "Over Alpha")
        // At 10:57 the real plane is over Bravo, at 5.25° E. The schedule's is still over Alpha, at 4.7° E.
        let rows = try facts(seenUntil: "10:57").rows(at: at("10:57"), now: at("10:57"))
        XCTAssertEqual(try row(.below, in: rows).title, "Over Bravo")
    }

    func test_headline_whileOutOfSight_isWhatsBelowWhereThePlanHasThePlane() throws {
        // Last seen over Alpha, at 4.375° E at 10:50. Eleven minutes on at its own 450 kt it's at 5.75° E: over
        // Bravo, 25 mi from Testville. The words are as plain as when it's seen.
        XCTAssertEqual(try facts(seenUntil: "10:50", now: "11:01").headline(at: at("11:01")), "Over Bravo, near Testville")
        // Last seen at 6.875° E ten minutes ago, it's at 8.125° E by now: no city within 40 mi.
        XCTAssertEqual(try facts(seenUntil: "11:10", now: "11:20").headline(at: at("11:20")), "Over Bravo")
    }

    func test_headline_whileOutOfSight_withNoPlaceKnown_isTheLandingCountdown() throws {
        // It lands at 13:11:47 by its estimate: 112 minutes after 11:20.
        let facts = try facts(seenUntil: "11:10", now: "11:20", hasStory: false)
        XCTAssertEqual(facts.headline(at: at("11:20")), "Landing in 1 h 52 min")
    }

    func test_headline_whileOutOfSight_keepsItsOrder() throws {
        // Last seen at 9.375° E at 11:30. By the plan it's halfway at 11:35: that leads for five minutes, and then
        // what's below does.
        let facts = try facts(seenUntil: "11:30", now: "11:37")
        XCTAssertEqual(facts.headline(at: at("11:37")), "Halfway!")
        XCTAssertEqual(facts.headline(at: at("11:41")), "Over Bravo")
    }

    func test_headline_whileOutOfSight_tellsACrossingAsItsBestGuess() throws {
        // Last seen at 4.375° E at 10:50. By the plan it crosses the border at 5° E at 10:55, and nobody saw it.
        XCTAssertEqual(try facts(seenUntil: "10:50", now: "10:58").headline(at: at("10:58")), "Just crossed into Bravo")
        XCTAssertEqual(try facts(seenUntil: "10:50", now: "10:54").headline(at: at("10:54")), "Over Alpha", "not there yet, by the plan")
    }

    func test_headline_inAReplay_isWhereTheRecordHasThePlane() throws {
        let facts = try facts(seenUntil: "11:10", isReplay: true)
        XCTAssertEqual(facts.headline(at: at("10:35")), "Over Alpha", "2.5° E at 10:35")
        XCTAssertEqual(facts.headline(at: at("11:25")), "Over Bravo", "past where it was last seen, at 8.75° E by the plan")
    }

    // MARK: - The rows (§8)

    func test_rows_inTheAir_haveThePlanesRowSecond() throws {
        let rows = try facts(seenUntil: "11:10").rows(at: at("11:10"), now: at("11:10"))
        XCTAssertEqual(rows.map(\.kind), [.below, .plane, .distance, .headed])

        let below = try row(.below, in: rows)
        XCTAssertEqual(below.title, "Over Bravo")
        XCTAssertEqual(plain(below.detail), "Passes 35 mi from home at about 8:07 AM", "14° E is still ahead: its time is the estimate")

        let plane = try row(.plane, in: rows)
        XCTAssertEqual(plane.title, "Boeing 767-300 · N370UP")
        XCTAssertEqual(plane.detail, "36,000 ft · 520 mph", "450 kt")
        XCTAssertEqual(plane.symbolName, "airplane")
        XCTAssertEqual(plane.sentence, "Boeing 767-300 · N370UP. 36,000 ft, 520 mph")

        // 6.875° is 475 mi, of 1,382. No "Averaging about": that's the schedule's speed.
        let distance = try row(.distance, in: rows)
        XCTAssertEqual(distance.title, "475 mi flown · 907 to go")
        XCTAssertEqual(plain(distance.detail), "Halfway at about 7:35 AM · like driving the Alaska Highway")

        // 788 nm to go: the last 120 at 280 kt and the rest at its own 450 is 1 h 55 min, and 7 minutes to the gate.
        XCTAssertEqual(plain(try row(.headed, in: rows).title), "Lands E20 about 9:11 AM")
    }

    func test_rows_whileOutOfSight_sayWhereItWasLastSeenUnderWhatsBelow_andLeaveOutItsHeightAndSpeed() throws {
        let rows = try facts(seenUntil: "11:10", now: "11:20").rows(at: at("11:20"), now: at("11:20"))
        let below = try row(.below, in: rows)
        XCTAssertEqual(below.title, "Over Bravo")
        XCTAssertEqual(plain(below.detail), "Last seen over Bravo · 10 min ago · Passes 35 mi from home at about 8:07 AM")

        // Last seen at 6° E, 21 mi from Testville.
        let byACity = try facts(seenUntil: "11:03", now: "11:13").rows(at: at("11:13"), now: at("11:13"))
        XCTAssertEqual(plain(try row(.below, in: byACity).detail), "Last seen near Testville · 10 min ago · Passes 35 mi from home at about 8:07 AM")

        // With no place known, when it was last seen leads the row.
        let noPlace = try facts(seenUntil: "11:10", now: "11:20", hasStory: false).rows(at: at("11:20"), now: at("11:20"))
        XCTAssertEqual(try row(.below, in: noPlace).title, "Last seen 10 min ago")
        XCTAssertNil(try row(.below, in: noPlace).detail)

        let plane = try row(.plane, in: rows)
        XCTAssertEqual(plane.title, "Boeing 767-300 · N370UP")
        XCTAssertNil(plane.detail)

        // Ten more minutes at 450 kt from 6.875° E is 8.125° E: 561 mi.
        XCTAssertEqual(try row(.distance, in: rows).title, "561 mi flown · 821 to go")
    }

    func test_rows_inAReplay_haveNoHeightOrSpeed() throws {
        let rows = try facts(seenUntil: "11:10", isReplay: true).rows(at: at("10:35"), now: at("11:10"))
        let plane = try row(.plane, in: rows)
        XCTAssertEqual(plane.title, "Boeing 767-300 · N370UP")
        XCTAssertNil(plane.detail, "its height and speed are for now only")
        XCTAssertEqual(try row(.below, in: rows).title, "Over Alpha")
        XCTAssertEqual(try row(.distance, in: rows).title, "173 mi flown · 1,209 to go", "2.5° E at 10:35")
    }

    func test_rows_ofAFlightThatHasLanded_haveRealTimes_withNoAbout() throws {
        let facts = try facts(seenUntil: "12:53", now: "12:56", landed: true, isReplay: true)
        let rows = facts.rows(at: at("11:00"), now: at("12:56"))
        XCTAssertEqual(plain(try row(.below, in: rows).detail), "Passes 35 mi from home at 8:07 AM")
        XCTAssertEqual(plain(try row(.distance, in: rows).detail), "Halfway at 7:35 AM · like driving the Alaska Highway")
    }

    func test_rows_theClosestPointToHome_whereNobodySawIt_isABestGuess_withAbout() throws {
        // Nobody saw it from 13° E to 15° E, where it passed home.
        let rows = try facts(seenUntil: "12:30", unseen: 13...15).rows(at: at("12:30"), now: at("12:30"))
        XCTAssertEqual(plain(try row(.below, in: rows).detail), "Closest to home was 35 mi at about 8:07 AM")
        // Seen all the way, it's told with its real time.
        let seen = try facts(seenUntil: "12:30").rows(at: at("12:30"), now: at("12:30"))
        XCTAssertEqual(plain(try row(.below, in: seen).detail), "Closest to home was 35 mi at 8:07 AM")
    }

    func test_rows_thePlanesRow_showsAnUnknownTypeAsItself_andLeavesOutWhatsMissing() throws {
        let unknown = try facts(seenUntil: "11:10", typeCode: "ZZZZ").rows(at: at("11:10"), now: at("11:10"))
        XCTAssertEqual(try row(.plane, in: unknown).title, "ZZZZ · N370UP")

        let noRegistration = try facts(seenUntil: "11:10", registration: nil).rows(at: at("11:10"), now: at("11:10"))
        XCTAssertEqual(try row(.plane, in: noRegistration).title, "Boeing 767-300")

        let neither = try facts(seenUntil: "11:10", typeCode: nil, registration: nil).rows(at: at("11:10"), now: at("11:10"))
        let plane = try row(.plane, in: neither)
        XCTAssertEqual(plane.title, "36,000 ft · 520 mph", "what it has leads the row")
        XCTAssertNil(plane.detail)
    }

    func test_rows_withNoLiveData_areTheSchedules_asBefore() throws {
        let rows = try facts(of: try FactsTestData.equatorLiveLeg(nil, at: at("11:10"))).rows(at: at("11:10"), now: at("11:10"))
        XCTAssertEqual(rows.map(\.kind), [.below, .distance, .headed], "no plane's row")
        XCTAssertEqual(try row(.below, in: rows).title, "Over Bravo, near Testville")
        XCTAssertEqual(try row(.distance, in: rows).title, "422 mi flown · 960 to go")
        XCTAssertEqual(plain(try row(.distance, in: rows).detail), "Halfway at 7:45 AM · Averaging about 460 mph · like driving the Alaska Highway")
    }

    // MARK: - The trip so far, and the credit

    func test_tripSoFar_countsTheMilesAlongTheRealPath_andListsRealTimes() throws {
        let tripSoFar = try facts(seenUntil: "11:10").tripSoFar(at: at("11:10"))
        XCTAssertEqual(tripSoFar.flights.first?.milestones.map { plain($0) }, ["Crossed into Bravo · 6:55 AM"])
        XCTAssertEqual(tripSoFar.totals, "Day 1 of 1 · 475 mi")
    }

    func test_tripSoFar_inAReplay_countsAsFarAsTheRecordHasThePlane() throws {
        let tripSoFar = try facts(seenUntil: "11:10", isReplay: true).tripSoFar(at: at("10:35"))
        XCTAssertEqual(tripSoFar.flights, [], "at 10:35 it hadn't crossed into Bravo yet")
        XCTAssertEqual(tripSoFar.totals, "Day 1 of 1 · 173 mi")
    }

    func test_tripSoFar_aCrossingNobodySaw_isListedWithAbout() throws {
        let tripSoFar = try facts(seenUntil: "11:10", unseen: 4...6.5).tripSoFar(at: at("11:10"))
        XCTAssertEqual(tripSoFar.flights.first?.milestones.map { plain($0) }, ["Crossed into Bravo · about 6:55 AM"])
    }

    func test_showsLiveData_whenAFlightOfTheTripHasIt() throws {
        XCTAssertTrue(try facts(seenUntil: "11:10").showsLiveData)
        XCTAssertFalse(try facts(of: FactsTestData.equatorFlight(from: 0, to: 20)).showsLiveData)
        XCTAssertFalse(try facts(of: try FactsTestData.equatorLiveLeg(nil, at: at("11:10"))).showsLiveData)
    }

    // MARK: - The card for VoiceOver (§9, §15)

    func test_cardSummary_inTheAir_saysWhatsBelowTheRealPlane() throws {
        // It lands at 13:05 by its estimate, where the plan has 13:15.
        XCTAssertEqual(plain(try facts(seenUntil: "11:10").cardSummary(now: at("11:10"), pilotName: "Alex")),
                       "TST1 to E20, 10 minutes ahead of schedule, over Bravo. Lands about 9:11 AM your time.")
    }

    func test_cardSummary_whileOutOfSight_saysAbout_whatsBelowByThePlan_andWhereItWasLastSeen() throws {
        XCTAssertEqual(plain(try facts(seenUntil: "10:50", now: "11:01").cardSummary(now: at("11:01"), pilotName: "Alex")),
                       "TST1 to E20, about 10 minutes ahead of schedule, over Bravo, last seen over Alpha. Lands about 9:11 AM your time.")
        XCTAssertEqual(plain(try facts(seenUntil: "11:03", now: "11:13").cardSummary(now: at("11:13"), pilotName: "Alex")),
                       "TST1 to E20, about 10 minutes ahead of schedule, over Bravo, last seen near Testville. Lands about 9:11 AM your time.")
        XCTAssertEqual(plain(try facts(seenUntil: "11:10", now: "11:20", hasStory: false).cardSummary(now: at("11:20"), pilotName: "Alex")),
                       "TST1 to E20, about 10 minutes ahead of schedule, last seen 10 minutes ago. Lands about 9:11 AM your time.")
    }
}
