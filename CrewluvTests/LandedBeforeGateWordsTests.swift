//
//  LandedBeforeGateWordsTests.swift
//  CrewluvTests
//
//  The line under the timeline and the card's bar once a real plane is down at its arrival airport, before the gate
//  (landed before the gate design §3), in US English for a family in Louisville.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LandedBeforeGateWordsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private let anchorage = AirportMark(code: "ANC", city: "Anchorage", coordinate: CLLocationCoordinate2D(latitude: 61.2, longitude: -150.0),
                                        timeZone: TimeZone(identifier: "America/Anchorage"))

    func test_timeline_saysWhereTheRealPlaneLanded_inPlaceOfFlying() {
        // 12:45 AM UTC on the 14th is 7:45 PM on the 13th in Louisville.
        let date = FactsTestData.date("2026-11-14T00:45:00Z")
        let flying = TripActivity(kind: .flying, place: anchorage)
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: flying, onGround: .landedIn(anchorage), calendar: calendar, locale: locale)),
                       "Fri 7:45 PM · Landed in Anchorage")
        XCTAssertEqual(plain(TripMapWording.timelineSpokenValue(date, activity: flying, onGround: .landedIn(anchorage), calendar: calendar, locale: locale)),
                       "Friday 7:45 PM, landed in Anchorage")
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: flying, calendar: calendar, locale: locale)),
                       "Fri 7:45 PM · Flying to Anchorage", "without it, flying, as before")
    }

    func test_barArrival_saysAtTheGate_onceTheRealPlaneIsDown_untilTheGate() throws {
        // Down at E20 at 12:55 UTC; at the gate at 13:02, 9:02 AM in Louisville.
        let live = FactsTestData.equatorLive(seenUntil: at("12:53"), landedAt: FactsTestData.liveTime(atLongitude: 20))
        let landed = try FactsTestData.equatorLiveLeg(live, at: at("12:58"))
        XCTAssertEqual(plain(TripMapWording.barArrival(for: landed, at: at("12:58"), calendar: calendar, locale: locale)), "At the gate 9:02 AM")
        XCTAssertEqual(plain(TripMapWording.barArrival(for: landed, at: at("13:02"), calendar: calendar, locale: locale)), "Lands 9:02 AM",
                       "at the gate, as before")
        let flying = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("12:30")), at: at("12:30"))
        XCTAssertEqual(TripMapWording.barArrival(for: flying, at: at("12:30"), calendar: calendar, locale: locale),
                       TripMapWording.landsAt(for: flying, calendar: calendar, locale: locale))
    }
}
