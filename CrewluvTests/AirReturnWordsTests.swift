//
//  AirReturnWordsTests.swift
//  CrewluvTests
//
//  "Returned to Rockford" (air return design §3), in US English for a family in Louisville: on the card's bar, in the
//  plane's popup, in the card's sentence for VoiceOver, under the timeline, and in the facts. The shared case "an air
//  return, back on the ground" is from SDF, and the facts' flight is `FactsTestData`'s equator flight from E0.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class AirReturnWordsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func plain(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// The shared case's plane back at Louisville at 12:41, as a leg of the map.
    private func returned() throws -> (leg: MapLeg, at: Date) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "an air return, back on the ground")
        let moment = try cases.moment("13T12:41:00", of: flightCase)
        return (try cases.mapLeg(flightCase, at: moment), moment.at)
    }

    private func map(of leg: MapLeg) -> TripMap {
        TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: leg.origin,
                span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
    }

    private let rockford = AirportMark(code: "RFD", city: "Rockford", coordinate: CLLocationCoordinate2D(latitude: 42.2, longitude: -89.1),
                                       timeZone: TimeZone(identifier: "America/Chicago"))

    // MARK: - The card and the popup

    func test_bar_saysReturnedToTheDepartureAirport_nowOnly() throws {
        let (leg, at) = try returned()
        XCTAssertEqual(TripMapWording.flightStatus(for: leg, at: at), "Returned to SDF")
        XCTAssertEqual(TripMapWording.flightStatus(for: leg, at: at, isReplay: true), "In flight")
    }

    func test_cardSummary_saysItReturned_andLandsAbout() throws {
        let (leg, at) = try returned()
        // Touchdown is 12:41 plus the plan's 83 minutes in the air, and the gate 7 minutes on: 14:11 UTC, 9:11 AM.
        XCTAssertEqual(plain(TripMapWording.liveSummary(for: leg, over: "Indiana", lastSeen: "near Louisville", now: at,
                                                        calendar: calendar, locale: locale)),
                       "UPS207 to PHL, returned to SDF. Lands about 9:11 AM your time.")
    }

    func test_popup_saysItReturned_andWhenItLands() throws {
        let (leg, at) = try returned()
        let words = PlanePopupWords(leg: leg, plane: .realPlane, at: at, isReplay: false, calendar: calendar, locale: locale)
        XCTAssertEqual(words.lines.map { plain($0) }, ["Returned to SDF", "Lands about 9:11 AM L"])
    }

    // MARK: - The timeline

    func test_flightOnGround_isReturnedToTheDepartureAirport() throws {
        let (leg, at) = try returned()
        let onGround = map(of: leg).flightOnGround(at: at)
        guard case .returnedTo(let airport) = onGround else { return XCTFail("\(String(describing: onGround))") }
        XCTAssertEqual(airport.code, "SDF")
    }

    func test_timeline_saysReturned_inPlaceOfFlying() {
        // 5:21 PM UTC is 12:21 PM in Louisville.
        let date = FactsTestData.date("2026-11-13T17:21:00Z")
        let flying = TripActivity(kind: .flying, place: rockford)
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: flying, onGround: .returnedTo(rockford),
                                                         calendar: calendar, locale: locale)),
                       "Fri 12:21 PM L · Returned to Rockford")
        XCTAssertEqual(plain(TripMapWording.timelineSpokenValue(date, activity: flying, onGround: .returnedTo(rockford),
                                                                calendar: calendar, locale: locale)),
                       "Friday 12:21 PM, returned to Rockford")
    }

    // MARK: - The facts

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    /// The equator flight's real plane back at E0 half a minute before `now`, after flying out 20 nm and back, from
    /// 1,000 ft up to 8,000 and down to 1,500.
    private func backAtE0(_ now: String) -> LiveFlight {
        let trail = [(10.5, 0.05, 1_000.0), (10.6, 0.33, 8_000.0), (10.7, 0.05, 1_500.0)].map { hours, longitude, feet in
            LiveFlight.TrailPoint(time: at("10:00").addingTimeInterval((hours - 10) * 3600), latitude: 0, longitude: longitude,
                                  altitudeFeet: feet)
        }
        let fix = LiveFlight.Fix(latitude: 0, longitude: 0, altitudeFeet: nil, groundSpeedKnots: 0, trackDegrees: nil,
                                 isOnGround: true, registration: "N370UP", typeCode: "B763", seenAt: at(now).addingTimeInterval(-30))
        return LiveFlight(legID: "eq", callsign: "TST1", state: .ground, fix: fix, landedAt: nil, trail: trail)
    }

    private func facts(backAt now: String, isReplay: Bool = false) throws -> TripFacts {
        let leg = try FactsTestData.equatorLiveLeg(backAtE0(now), at: at(now))
        let home = FactsTestData.homeByTheEquator
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: home,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        return TripFacts(tripMap: map, geography: FactsTestData.equator, comparisons: try FactsTestData.appComparisons(),
                         stories: [leg.id: LegStory(leg: leg, geography: FactsTestData.equator, home: home)],
                         sunEvents: [leg.id: SkyFacts.sunEvents(on: leg)], dayNumber: 1, totalDays: 1,
                         calendar: calendar, locale: locale, isReplay: isReplay)
    }

    func test_facts_sayReturned_asStillOnTheGroundWould_withNoSky() throws {
        let facts = try facts(backAt: "11:20")
        XCTAssertEqual(facts.headline(at: at("11:20")), "Returned to E0")
        let rows = facts.rows(at: at("11:20"), now: at("11:20"))
        XCTAssertEqual(try XCTUnwrap(rows.first { $0.kind == .below }).title, "Returned to E0")
        XCTAssertNil(rows.first { $0.kind == .sky })
        XCTAssertEqual(try XCTUnwrap(rows.first { $0.kind == .distance }).title, "1,382 mi to go")
        XCTAssertNil(try XCTUnwrap(rows.first { $0.kind == .plane }).detail, "no height or speed on the ground")
        XCTAssertEqual(facts.tripSoFar(at: at("11:20")).flights.count, 0, "the way out and back isn't the flight")
    }

    func test_facts_inAReplay_areAsBefore() throws {
        let replay = try facts(backAt: "11:20", isReplay: true)
        XCTAssertNotEqual(replay.headline(at: at("11:20")), "Returned to E0")
        XCTAssertNil(replay.flightOnGround(at: at("11:20")))
    }

    func test_factsWords_sayReturnedTo() {
        XCTAssertEqual(FactsWording.returned(to: rockford), "Returned to Rockford")
    }
}
