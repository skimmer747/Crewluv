//
//  LiveWordingTests.swift
//  CrewluvTests
//
//  The trip map's words for a flight with a real plane (Stage 3 spec §9, §15), in US English for a family in
//  Louisville, on the shared cases' flights.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LiveWordingTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    /// iOS writes a narrow no-break space before AM and PM; the tests read it as a plain space.
    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// A shared case's flight at one of its moments, as a leg of the map between named airports.
    private func leg(of name: String, at time: String) throws -> (leg: MapLeg, at: Date) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let moment = try cases.moment(time, of: flightCase)
        let cities = ["SDF": ("Louisville", "America/New_York"), "PHL": ("Philadelphia", "America/New_York"), "CGN": ("Cologne", "Europe/Berlin")]
        func mark(_ code: String) throws -> AirportMark {
            AirportMark(code: code, city: cities[code]?.0, coordinate: try cases.coordinate(of: code),
                        timeZone: cities[code].flatMap { TimeZone(identifier: $0.1) })
        }
        let leg = MapLeg(id: "f1", kind: .flight, origin: try mark(flightCase.from), destination: try mark(flightCase.to),
                         start: moment.start, end: moment.end, flightNumber: "UPS207", flight: try cases.mapFlight(flightCase))
        return (leg, moment.at)
    }

    /// The map of that one flight.
    private func map(of name: String, at time: String) throws -> (map: TripMap, at: Date) {
        let (leg, at) = try leg(of: name, at: time)
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: leg.origin,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        return (map, at)
    }

    // MARK: - The card's bar and the pill

    func test_flightStatus_isLiveAndTheRealPlanesLabel_whileSeen_orTheBestGuessAlone() throws {
        func status(_ name: String, _ time: String) throws -> String {
            let (leg, at) = try leg(of: name, at: time)
            return TripMapWording.flightStatus(for: leg, at: at)
        }
        XCTAssertEqual(try status("ahead, in the air", "13T12:41:50"), "Live · 14 min ahead")
        XCTAssertEqual(try status("ahead, in the air", "13T12:45:00"), "About 14 min ahead")
        XCTAssertEqual(try status("off early and the long way round", "13T12:15:20"), "Live · On schedule")
        XCTAssertEqual(try status("behind, with a late first point and an unseen ocean", "14T00:13:00"), "Live · 55 min behind")
        XCTAssertEqual(try status("still on the ground just after the plan's takeoff", "13T12:18:00"), "Live · Still on the ground")
        XCTAssertEqual(try status("still on the ground twenty minutes after", "13T12:35:00"), "Live · Still on the ground · 20 min behind")
    }

    func test_flightStatus_withNoLabel_isLiveAlone_whileSeen_elseNotTrackedLive() throws {
        for (name, time) in [("on the ground somewhere else", "13T13:21:00"), ("on the ground before the plan's takeoff", "13T12:10:00")] {
            let (leg, at) = try leg(of: name, at: time)
            XCTAssertEqual(TripMapWording.flightStatus(for: leg, at: at), "Live", name)
        }
        for (name, time) in [("no live data", "13T12:30:00"), ("waiting to be seen", "13T12:30:00")] {
            let (leg, at) = try leg(of: name, at: time)
            XCTAssertEqual(TripMapWording.flightStatus(for: leg, at: at), "Not tracked live", name)
        }
    }

    func test_flightStatus_inAReplay_isInFlight() throws {
        let (leg, at) = try leg(of: "ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(TripMapWording.flightStatus(for: leg, at: at, isReplay: true), "In flight")
    }

    func test_topPill_withARealPlane_saysHowItsDoing_andInAReplayInFlight() throws {
        let (map, at) = try map(of: "ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(TripMapWording.topPill(for: map, at: at, dayNumber: 1, totalDays: 4), "UPS207 · Live · 14 min ahead")
        XCTAssertEqual(TripMapWording.topPill(for: map, at: at, dayNumber: 1, totalDays: 4, isReplay: true), "UPS207 · In flight")
    }

    func test_topPill_withNoLiveData_isNotTrackedLive() throws {
        let (map, at) = try map(of: "no live data", at: "13T12:30:00")
        XCTAssertEqual(TripMapWording.topPill(for: map, at: at, dayNumber: 1, totalDays: 4), "UPS207 · Not tracked live")
    }

    // MARK: - "About"

    func test_landsAt_theRealPlanesEstimate_saysAbout() throws {
        let (ahead, _) = try leg(of: "ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(plain(TripMapWording.landsAt(for: ahead, calendar: calendar, locale: locale)), "Lands about 8:30 AM L")
        let (late, _) = try leg(of: "still on the ground twenty minutes after", at: "13T12:35:00")
        XCTAssertEqual(plain(TripMapWording.landsAt(for: late, calendar: calendar, locale: locale)), "Lands about 9:05 AM L")
    }

    func test_landsAt_theSchedulesTime_andALandedFlights_haveNoAbout() throws {
        let (scheduled, _) = try leg(of: "no live data", at: "13T12:30:00")
        XCTAssertEqual(plain(TripMapWording.landsAt(for: scheduled, calendar: calendar, locale: locale)), "Lands 8:45 AM L")
        let (early, _) = try leg(of: "on the ground before the plan's takeoff", at: "13T12:10:00")
        XCTAssertEqual(plain(TripMapWording.landsAt(for: early, calendar: calendar, locale: locale)), "Lands 8:45 AM L")
        let (landed, _) = try leg(of: "landed, seen all the way", at: "13T13:30:00")
        XCTAssertEqual(plain(TripMapWording.landsAt(for: landed, calendar: calendar, locale: locale)), "Lands 8:21 AM L")
    }

    func test_landingLine_theRealPlanesEstimate_saysAboutOnce() throws {
        let (toCologne, _) = try leg(of: "behind, with a late first point and an unseen ocean", at: "14T00:13:00")
        XCTAssertEqual(plain(TripMapWording.landingLine(for: toCologne, calendar: calendar, locale: locale)),
                       "Lands Cologne about 3:54 AM · 9:54 PM L")
        let (toPhiladelphia, _) = try leg(of: "ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(plain(TripMapWording.landingLine(for: toPhiladelphia, calendar: calendar, locale: locale)),
                       "Lands Philadelphia about 8:30 AM L")
    }

    func test_factsLands_theRealPlanesEstimate_saysAbout() throws {
        let (toCologne, _) = try leg(of: "behind, with a late first point and an unseen ocean", at: "14T00:13:00")
        XCTAssertEqual(plain(FactsWording.lands(toCologne, calendar: calendar, locale: locale)), "lands about 3:54 AM Cologne")
        let (toPhiladelphia, _) = try leg(of: "ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(plain(FactsWording.lands(toPhiladelphia, calendar: calendar, locale: locale)), "lands about 8:30 AM L")
    }

    func test_landingCountdown_countsToTheRealPlanesArrival() throws {
        let (map, at) = try map(of: "ahead, in the air", at: "13T12:41:50")
        // The schedule says 64 minutes. The real plane reaches the gate in 50 and a bit.
        XCTAssertEqual(TripMapWording.cardChips(for: map, at: at, calendar: calendar, locale: locale).bottom, "Landing in 49 min")
    }

    // MARK: - VoiceOver

    func test_spokenLiveLabel_saysEachLabelInFull() {
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.onSchedule), "on schedule")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.ahead(minutes: 12, isEstimated: false)), "12 minutes ahead of schedule")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.ahead(minutes: 12, isEstimated: true)), "about 12 minutes ahead of schedule")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.behind(minutes: 75, isEstimated: false)), "1 hour 15 minutes behind schedule")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.behind(minutes: 20, isEstimated: true)), "about 20 minutes behind schedule")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.stillOnGround(minutesBehind: nil)), "still on the ground")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.stillOnGround(minutesBehind: 20)), "still on the ground, 20 minutes behind schedule")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.landedOnTime), "landed on time")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.landedEarly(minutes: 8)), "landed 8 minutes early")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.landedLate(minutes: 15)), "landed 15 minutes late")
    }

    func test_spokenMinutes_countsHoursAndMinutes() {
        XCTAssertEqual(TripMapWording.spokenMinutes(0), "0 minutes")
        XCTAssertEqual(TripMapWording.spokenMinutes(1), "1 minute")
        XCTAssertEqual(TripMapWording.spokenMinutes(45), "45 minutes")
        XCTAssertEqual(TripMapWording.spokenMinutes(60), "1 hour")
        XCTAssertEqual(TripMapWording.spokenMinutes(61), "1 hour 1 minute")
        XCTAssertEqual(TripMapWording.spokenMinutes(120), "2 hours")
        XCTAssertEqual(TripMapWording.spokenMinutes(130), "2 hours 10 minutes")
    }

    func test_liveSummary_saysHowThePlaneIsDoing_andWhatsBelow() throws {
        let (leg, at) = try leg(of: "behind, with a late first point and an unseen ocean", at: "14T00:13:00")
        XCTAssertEqual(plain(try XCTUnwrap(TripMapWording.liveSummary(for: leg, over: "Québec", now: at, calendar: calendar, locale: locale))),
                       "UPS207 to Cologne, 55 minutes behind schedule, over Québec. Lands about 9:54 PM your time.")
        XCTAssertEqual(plain(try XCTUnwrap(TripMapWording.liveSummary(for: leg, now: at, calendar: calendar, locale: locale))),
                       "UPS207 to Cologne, 55 minutes behind schedule. Lands about 9:54 PM your time.")
    }

    func test_liveSummary_whileEstimated_saysAbout() throws {
        let (leg, at) = try leg(of: "ahead, in the air", at: "13T12:45:00")
        XCTAssertEqual(plain(try XCTUnwrap(TripMapWording.liveSummary(for: leg, now: at, calendar: calendar, locale: locale))),
                       "UPS207 to Philadelphia, about 14 minutes ahead of schedule. Lands about 8:30 AM your time.")
    }

    func test_liveSummary_whileOutOfSight_saysWhatsBelowByThePlan_andWhereItWasLastSeen() throws {
        let (leg, at) = try leg(of: "ahead, in the air", at: "13T12:45:00")
        let summary = TripMapWording.liveSummary(for: leg, over: "Ohio", lastSeen: "near Columbus", now: at, calendar: calendar, locale: locale)
        XCTAssertEqual(plain(try XCTUnwrap(summary)),
                       "UPS207 to Philadelphia, about 14 minutes ahead of schedule, over Ohio, last tracked near Columbus. Lands about 8:30 AM your time.")
        let noPlace = TripMapWording.liveSummary(for: leg, lastSeen: "12 minutes ago", now: at, calendar: calendar, locale: locale)
        XCTAssertEqual(plain(try XCTUnwrap(noPlace)),
                       "UPS207 to Philadelphia, about 14 minutes ahead of schedule, last tracked 12 minutes ago. Lands about 8:30 AM your time.")
    }

    func test_liveSummary_stillOnTheGround_saysSo_andWhenItWillLand() throws {
        let (leg, at) = try leg(of: "still on the ground twenty minutes after", at: "13T12:35:00")
        XCTAssertEqual(plain(try XCTUnwrap(TripMapWording.liveSummary(for: leg, now: at, calendar: calendar, locale: locale))),
                       "UPS207 to Philadelphia, still on the ground, 20 minutes behind schedule. Lands about 9:05 AM your time.")
    }

    func test_liveSummary_onceItHasLanded_saysWhenItReachesTheGate_notThatItLands() throws {
        let (leg, at) = try leg(of: "landed, seen all the way", at: "13T13:30:00")
        let summary = plain(try XCTUnwrap(TripMapWording.liveSummary(for: leg, now: at, calendar: calendar, locale: locale)))
        XCTAssertEqual(summary, "UPS207 to Philadelphia, landed 23 minutes early. Reaches the gate at 8:21 AM your time.")
        XCTAssertFalse(summary.contains("Lands"))
    }

    func test_liveSummary_saysWhatsBelowAndWhereItWasLastSeen_onlyWhileItFlies() throws {
        let (atTheGate, gateTime) = try leg(of: "still on the ground twenty minutes after", at: "13T12:35:00")
        XCTAssertEqual(plain(try XCTUnwrap(TripMapWording.liveSummary(for: atTheGate, over: "Kentucky", lastSeen: "near Louisville",
                                                                      now: gateTime, calendar: calendar, locale: locale))),
                       "UPS207 to Philadelphia, still on the ground, 20 minutes behind schedule. Lands about 9:05 AM your time.")
        let (landed, landedTime) = try leg(of: "landed, seen all the way", at: "13T13:30:00")
        XCTAssertEqual(plain(try XCTUnwrap(TripMapWording.liveSummary(for: landed, over: "Pennsylvania", lastSeen: "near Philadelphia",
                                                                      now: landedTime, calendar: calendar, locale: locale))),
                       "UPS207 to Philadelphia, landed 23 minutes early. Reaches the gate at 8:21 AM your time.")
    }

    func test_liveSummary_withNoLabel_isNil() throws {
        for (name, time) in [("no live data", "13T12:30:00"), ("on the ground somewhere else", "13T13:21:00")] {
            let (leg, at) = try leg(of: name, at: time)
            XCTAssertNil(TripMapWording.liveSummary(for: leg, now: at, calendar: calendar, locale: locale), name)
        }
    }

    func test_cardSummary_withARealPlane_isTheLiveSentence_thenTrackedLive() throws {
        let (map, at) = try map(of: "ahead, in the air", at: "13T12:41:50")
        let expected = "UPS207 to Philadelphia, 14 minutes ahead of schedule. Lands about 8:30 AM your time. Tracked live."
        XCTAssertEqual(plain(TripMapWording.cardSummary(for: map, now: at, pilotName: "Alex", calendar: calendar, locale: locale)), expected)
        var facts = TripFacts(tripMap: map, geography: nil, comparisons: nil, stories: [:], sunEvents: [:])
        facts.calendar = calendar
        facts.locale = locale
        XCTAssertEqual(plain(facts.cardSummary(now: at, pilotName: "Alex")), expected)
    }

    func test_cardSummary_withNoLiveData_isTheSchedulesSentence_thenNotTrackedLive() throws {
        let (map, at) = try map(of: "no live data", at: "13T12:30:00")
        XCTAssertEqual(plain(TripMapWording.cardSummary(for: map, now: at, pilotName: "Alex", calendar: calendar, locale: locale)),
                       "UPS207 to Philadelphia, landing at 8:45 AM your time. Not tracked live, so it's shown where the schedule has it.")
        var facts = TripFacts(tripMap: map, geography: nil, comparisons: nil, stories: [:], sunEvents: [:])
        facts.calendar = calendar
        facts.locale = locale
        XCTAssertEqual(plain(facts.cardSummary(now: at, pilotName: "Alex")),
                       "UPS207 to Philadelphia. Lands at 8:45 AM your time. Not tracked live, so it's shown where the schedule has it.")
    }
}
