//
//  LiveOrScheduledWordsTests.swift
//  CrewluvTests
//
//  The pill, the card's bar, the VoiceOver sentences and the line under the timeline say whether a flight is tracked
//  live or shown by the schedule (live or scheduled design §4, §6, §7), in US English for a family in Louisville.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LiveOrScheduledWordsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// A shared case's flight at its moment `time`, as a leg of the map, and that moment.
    private func caseLeg(_ name: String, at time: String) throws -> (leg: MapLeg, at: Date) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let moment = try cases.moment(time, of: flightCase)
        return (try cases.mapLeg(flightCase, at: moment), moment.at)
    }

    /// `leg` while Crewlu Cloud's first answer is on its way.
    private func awaiting(_ leg: MapLeg) -> MapLeg {
        MapLeg(id: leg.id, kind: leg.kind, origin: leg.origin, destination: leg.destination, start: leg.start, end: leg.end,
               flightNumber: leg.flightNumber, flight: leg.flight, isAwaitingLive: true)
    }

    /// `awaiting(leg)` with no flight number.
    private func awaitingWithNoFlightNumber(_ leg: MapLeg) -> MapLeg {
        MapLeg(id: leg.id, kind: leg.kind, origin: leg.origin, destination: leg.destination, start: leg.start, end: leg.end,
               flightNumber: nil, flight: leg.flight, isAwaitingLive: true)
    }

    private func map(of leg: MapLeg) -> TripMap {
        TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: leg.origin,
                span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
    }

    // MARK: - The bar and the pill (§4.1, §6)

    func test_flightStatus_seenLive_saysLiveBeforeTheLabel_orLiveAlone() throws {
        let ahead = try caseLeg("ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(TripMapWording.flightStatus(for: ahead.leg, at: ahead.at), "Live · 14 min ahead")
        let late = try caseLeg("still on the ground twenty minutes after", at: "13T12:35:00")
        XCTAssertEqual(TripMapWording.flightStatus(for: late.leg, at: late.at), "Live · Still on the ground · 20 min behind")
        let back = try caseLeg("an air return, back on the ground", at: "13T12:41:00")
        XCTAssertEqual(TripMapWording.flightStatus(for: back.leg, at: back.at), "Live · Returned to SDF")
        let elsewhere = try caseLeg("on the ground somewhere else", at: "13T13:21:00")
        XCTAssertEqual(TripMapWording.flightStatus(for: elsewhere.leg, at: elsewhere.at), "Live")
        let atGate = try caseLeg("on the ground before the plan's takeoff", at: "13T12:10:00")
        XCTAssertEqual(TripMapWording.flightStatus(for: atGate.leg, at: atGate.at), "Live")
    }

    func test_flightStatus_aBestGuess_isItsLabelAlone() throws {
        let (leg, at) = try caseLeg("ahead, in the air", at: "13T12:45:00")
        XCTAssertEqual(TripMapWording.flightStatus(for: leg, at: at), "About 14 min ahead")
    }

    func test_flightStatus_byTheScheduleAlone_isNotTrackedLive_andNothingWhileWaiting() throws {
        let (leg, at) = try caseLeg("no live data", at: "13T12:30:00")
        XCTAssertEqual(TripMapWording.flightStatus(for: leg, at: at), "Not tracked live")
        XCTAssertEqual(TripMapWording.flightStatus(for: awaiting(leg), at: at), "")
    }

    func test_flightStatus_inAReplay_isInFlightWithARealPath_elseByTheSchedule() throws {
        let ahead = try caseLeg("ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(TripMapWording.flightStatus(for: ahead.leg, at: ahead.at, isReplay: true), "In flight")
        let noLive = try caseLeg("no live data", at: "13T12:30:00")
        XCTAssertEqual(TripMapWording.flightStatus(for: noLive.leg, at: noLive.at, isReplay: true), "By the schedule")
    }

    func test_topPill_putsTheWordsAfterTheFlightNumber_orTheFlightAloneWhileWaiting() throws {
        let ahead = try caseLeg("ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(TripMapWording.topPill(for: map(of: ahead.leg), at: ahead.at, dayNumber: 1, totalDays: 2),
                       "UPS207 · Live · 14 min ahead")
        let (noLive, at) = try caseLeg("no live data", at: "13T12:30:00")
        XCTAssertEqual(TripMapWording.topPill(for: map(of: noLive), at: at, dayNumber: 1, totalDays: 2), "UPS207 · Not tracked live")
        XCTAssertEqual(TripMapWording.topPill(for: map(of: noLive), at: at, dayNumber: 1, totalDays: 2, isReplay: true),
                       "UPS207 · By the schedule")
        XCTAssertEqual(TripMapWording.topPill(for: map(of: awaiting(noLive)), at: at, dayNumber: 1, totalDays: 2), "UPS207")
        XCTAssertEqual(TripMapWording.topPill(for: map(of: awaitingWithNoFlightNumber(noLive)), at: at, dayNumber: 1,
                                              totalDays: 2), "Flight to PHL")
    }

    // MARK: - The card's VoiceOver sentence (§7)

    func test_spokenSource_isTrackedLive_forALivePlane() throws {
        let (leg, at) = try caseLeg("ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(TripMapWording.spokenSource(for: leg, at: at), "Tracked live.")
    }

    func test_spokenSource_isNil_forABestGuess_andWhileWaiting() throws {
        let (guess, guessAt) = try caseLeg("ahead, in the air", at: "13T12:45:00")
        XCTAssertNil(TripMapWording.spokenSource(for: guess, at: guessAt))
        let (noLive, at) = try caseLeg("no live data", at: "13T12:30:00")
        XCTAssertNil(TripMapWording.spokenSource(for: awaiting(noLive), at: at))
    }

    func test_cardSummary_withARealPlane_endsTrackedLive() throws {
        let (leg, at) = try caseLeg("ahead, in the air", at: "13T12:41:50")
        let sentence = plain(TripMapWording.cardSummary(for: map(of: leg), now: at, pilotName: "Alex", calendar: calendar, locale: locale))
        XCTAssertTrue(sentence.hasPrefix("UPS207 to PHL, 14 minutes ahead of schedule. Lands about "), sentence)
        XCTAssertTrue(sentence.hasSuffix(" your time. Tracked live."), sentence)
    }

    func test_cardSummary_byTheScheduleAlone_saysSo_andNothingWhileWaiting() throws {
        let (leg, at) = try caseLeg("no live data", at: "13T12:30:00")
        XCTAssertEqual(plain(TripMapWording.cardSummary(for: map(of: leg), now: at, pilotName: "Alex", calendar: calendar, locale: locale)),
                       "UPS207 to PHL, landing at 8:45 AM your time. Not tracked live, so it's shown where the schedule has it.")
        XCTAssertEqual(plain(TripMapWording.cardSummary(for: map(of: awaiting(leg)), now: at, pilotName: "Alex", calendar: calendar,
                                                        locale: locale)),
                       "UPS207 to PHL, landing at 8:45 AM your time.")
    }

    func test_cardSummary_byTheScheduleAlone_beforeItsTakeoff_saysWhenItsScheduledToTakeOff() throws {
        let (leg, _) = try caseLeg("no live data", at: "13T12:30:00")
        let at = leg.start.addingTimeInterval(5 * 60)
        XCTAssertEqual(plain(TripMapWording.cardSummary(for: map(of: leg), now: at, pilotName: "Alex", calendar: calendar, locale: locale)),
                       "UPS207 to PHL, scheduled to take off about 7:15 AM your time, landing at 8:45 AM your time. " +
                       "Not tracked live, so it's shown where the schedule has it.")
    }

    func test_liveSummary_aRealPlaneAtItsGateBeforeThePlansTakeoff_isOnTheGround() throws {
        let (leg, at) = try caseLeg("on the ground before the plan's takeoff", at: "13T12:10:00")
        let sentence = TripMapWording.liveSummary(for: leg, now: at, calendar: calendar, locale: locale)
        XCTAssertEqual(plain(sentence ?? ""), "UPS207 to PHL, on the ground in SDF. Lands at 8:45 AM your time.")
    }

    // MARK: - Under the timeline (§4.1, §4.2)

    func test_timelineLine_byTheScheduleAlone_isScheduledToFly_thenShouldBeFlying() {
        let honolulu = AirportMark(code: "HNL", city: "Honolulu", coordinate: CLLocationCoordinate2D(latitude: 21.3, longitude: -157.9),
                                   timeZone: TimeZone(identifier: "Pacific/Honolulu"))
        let date = FactsTestData.date("2026-11-25T20:12:00Z")
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: nil, flight: .dueTo(honolulu), calendar: calendar, locale: locale)),
                       "Wed 3:12 PM L · Scheduled to fly to Honolulu")
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: nil, flight: .shouldBeFlyingTo(honolulu), calendar: calendar,
                                                         locale: locale)),
                       "Wed 3:12 PM L · Should be flying to Honolulu")
    }

    func test_flightNow_isTheRealPlaneOnTheGroundFirst_elseTheFlightByTheScheduleAlone() throws {
        let (noLive, _) = try caseLeg("no live data", at: "13T12:30:00")
        let due = noLive.start.addingTimeInterval(5 * 60)
        guard case .dueTo(let to)? = map(of: noLive).flightNow(at: due) else { return XCTFail("due") }
        XCTAssertEqual(to.code, "PHL")
        guard case .shouldBeFlyingTo(let flyingTo)? = map(of: noLive).flightNow(at: due.addingTimeInterval(25 * 60)) else {
            return XCTFail("should be flying")
        }
        XCTAssertEqual(flyingTo.code, "PHL")
        let atGate = try caseLeg("on the ground before the plan's takeoff", at: "13T12:10:00")
        guard case .stillIn(let gate)? = map(of: atGate.leg).flightNow(at: atGate.at) else { return XCTFail("at the gate") }
        XCTAssertEqual(gate.code, "SDF")
        let back = try caseLeg("an air return, back on the ground", at: "13T12:41:00")
        guard case .returnedTo? = map(of: back.leg).flightNow(at: back.at) else { return XCTFail("returned") }
        let ahead = try caseLeg("ahead, in the air", at: "13T12:41:50")
        XCTAssertNil(map(of: ahead.leg).flightNow(at: ahead.at))
    }
}
