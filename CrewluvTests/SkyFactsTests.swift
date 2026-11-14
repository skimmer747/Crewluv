//
//  SkyFactsTests.swift
//  CrewluvTests
//
//  Sunrises and sunsets from the cockpit, the people below, chasing the sun and the moon (Stage 2 spec §4.5), on
//  Louisville–Cologne flights in mid-November.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class SkyFactsTests: XCTestCase {

    private func flight(_ from: String, _ to: String, departing iso: String, hours: Double) -> MapLeg {
        let start = FactsTestData.date(iso)
        return MapLeg(id: "\(from)\(to)", kind: .flight,
                      origin: AirportMark(code: from, city: nil, coordinate: TripMapTestLegs.airports[from]!, timeZone: nil),
                      destination: AirportMark(code: to, city: nil, coordinate: TripMapTestLegs.airports[to]!, timeZone: nil),
                      start: start, end: start.addingTimeInterval(hours * 3600), flightNumber: nil)
    }

    func test_cockpitHorizon_at35000Feet_isAbout3Point86DegreesDown() {
        XCTAssertEqual(SkyFacts.horizonDip(feet: 35_000), 3.03, accuracy: 0.01)
        XCTAssertEqual(SkyFacts.cockpitHorizon, -3.863, accuracy: 0.001)
    }

    func test_sunEvents_anEveningFlightToEurope_seesOneSunset_about21MinutesAfterThePeopleBelow() throws {
        let events = SkyFacts.sunEvents(on: flight("SDF", "CGN", departing: "2026-11-13T18:00:00Z", hours: 8))
        let sunset = try XCTUnwrap(events.first)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(sunset.kind, .sunset)
        XCTAssertEqual(sunset.time.timeIntervalSince1970, FactsTestData.date("2026-11-13T20:46:17Z").timeIntervalSince1970, accuracy: 60)
        XCTAssertEqual(try XCTUnwrap(sunset.peopleBelowGap) / 60, 21.4, accuracy: 1)
    }

    func test_sunEvents_anOvernightFlightToEurope_seesOneSunrise_about22MinutesBeforeThePeopleBelow() throws {
        let events = SkyFacts.sunEvents(on: flight("SDF", "CGN", departing: "2026-11-13T23:00:00Z", hours: 8))
        let sunrise = try XCTUnwrap(events.first)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(sunrise.kind, .sunrise)
        XCTAssertEqual(sunrise.time.timeIntervalSince1970, FactsTestData.date("2026-11-14T06:38:13Z").timeIntervalSince1970, accuracy: 60)
        XCTAssertEqual(try XCTUnwrap(sunrise.peopleBelowGap) / 60, 22.0, accuracy: 1)
    }

    func test_sunEvents_aDaylightFlightWest_seesNone() {
        XCTAssertEqual(SkyFacts.sunEvents(on: flight("CGN", "SDF", departing: "2026-11-14T13:00:00Z", hours: 9)), [])
    }

    func test_sunEvents_aDrive_isNone() {
        let drive = MapLeg(id: "d", kind: .drive,
                           origin: AirportMark(code: "LEX", city: nil, coordinate: TripMapTestLegs.airports["LEX"]!, timeZone: nil),
                           destination: AirportMark(code: "SDF", city: nil, coordinate: TripMapTestLegs.airports["SDF"]!, timeZone: nil),
                           start: FactsTestData.date("2026-11-13T21:00:00Z"), end: FactsTestData.date("2026-11-13T23:00:00Z"), flightNumber: nil)
        XCTAssertEqual(SkyFacts.sunEvents(on: drive), [])
    }

    func test_chase_westboundOverTheAtlanticInTheAfternoon_isTheAfternoon() {
        let leg = flight("CGN", "SDF", departing: "2026-11-14T13:00:00Z", hours: 9)
        XCTAssertEqual(SkyFacts.chase(on: leg, at: FactsTestData.date("2026-11-14T15:00:00Z")), .afternoon)
    }

    func test_chase_eastbound_isNil() {
        let leg = flight("SDF", "CGN", departing: "2026-11-13T12:00:00Z", hours: 8)
        XCTAssertNil(SkyFacts.chase(on: leg, at: FactsTestData.date("2026-11-13T15:00:00Z")))
    }

    func test_moon_inDaylight_isNil() {
        let leg = flight("CGN", "SDF", departing: "2026-11-14T13:00:00Z", hours: 9)
        XCTAssertNil(SkyFacts.moon(on: leg, at: FactsTestData.date("2026-11-14T15:00:00Z")))
    }

    func test_moon_onANightLeavingCologne_isAWaxingGibbousMoonUp() {
        let leg = flight("CGN", "DXB", departing: "2026-11-20T20:00:00Z", hours: 6)
        XCTAssertEqual(SkyFacts.moon(on: leg, at: FactsTestData.date("2026-11-20T20:30:00Z")),
                       SkyFacts.Moon(phase: .waxingGibbous, isUp: true))
    }

    func test_nextGroundSunEvent_inCologneAtNight_isTomorrowsSunrise() throws {
        let event = try XCTUnwrap(SkyFacts.nextGroundSunEvent(at: TripMapTestLegs.airports["CGN"]!, after: FactsTestData.date("2026-11-13T20:14:00Z")))
        XCTAssertEqual(event.kind, .sunrise)
        XCTAssertEqual(event.time.timeIntervalSince1970, FactsTestData.date("2026-11-14T06:45:24Z").timeIntervalSince1970, accuracy: 60)
    }

    func test_nextGroundSunEvent_inCologneAtNoon_isThatEveningsSunset() throws {
        let event = try XCTUnwrap(SkyFacts.nextGroundSunEvent(at: TripMapTestLegs.airports["CGN"]!, after: FactsTestData.date("2026-11-14T12:00:00Z")))
        XCTAssertEqual(event.kind, .sunset)
        XCTAssertEqual(event.time.timeIntervalSince1970, FactsTestData.date("2026-11-14T15:45:47Z").timeIntervalSince1970, accuracy: 60)
    }
}
