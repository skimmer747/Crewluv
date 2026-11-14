//
//  TripTotalsTests.swift
//  CrewluvTests
//
//  A trip's totals (Stage 2 spec §4.8): Louisville to Cologne to Dubai and home, from 2026-11-13 12:00 UTC.
//  Its one cockpit sunset is on the first flight, at 17:45 UTC.
//

import XCTest
@testable import Crewluv

final class TripTotalsTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart

    private func europe() throws -> (map: TripMap, sunEvents: [String: [SkyFacts.SunEvent]]) {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: start))
        let sunEvents = Dictionary(uniqueKeysWithValues: map.legs.map { ($0.id, SkyFacts.sunEvents(on: $0)) })
        return (map, sunEvents)
    }

    func test_whole_theEuropeTrip() throws {
        let trip = try europe()
        XCTAssertEqual(TripTotals.whole(trip.map, sunEvents: trip.sunEvents),
                       TripTotals(cities: 2, miles: 14_819, timeZones: 18, cockpitSunsets: 1))
    }

    func test_soFar_afterTheFirstFlight_countsIt() throws {
        let trip = try europe()
        XCTAssertEqual(TripTotals.soFar(on: trip.map, at: start.addingTimeInterval(12 * 3600), sunEvents: trip.sunEvents),
                       TripTotals(cities: 1, miles: 4_351, timeZones: 6, cockpitSunsets: 1))
    }

    func test_soFar_midFirstFlightBeforeSunset_countsOnlyMiles() throws {
        let trip = try europe()
        let totals = TripTotals.soFar(on: trip.map, at: start.addingTimeInterval(4 * 3600), sunEvents: trip.sunEvents)
        XCTAssertEqual(totals.cities, 0)
        XCTAssertEqual(totals.timeZones, 0)
        XCTAssertEqual(totals.cockpitSunsets, 0)
        XCTAssertGreaterThan(totals.miles, 0)
    }

    func test_timeZonesCrossed_halfHours_roundAtTheEnd() {
        func leg(_ id: String, from: String, to: String) -> MapLeg {
            MapLeg(id: id, kind: .flight,
                   origin: FactsTestData.mark("A", latitude: 0, longitude: 0, zone: from),
                   destination: FactsTestData.mark("B", latitude: 0, longitude: 10, zone: to),
                   start: start, end: start.addingTimeInterval(3600), flightNumber: nil)
        }
        XCTAssertEqual(TripTotals.timeZonesCrossed(by: [leg("1", from: "America/New_York", to: "Asia/Kolkata")]), 11, "10½ hours")
        XCTAssertEqual(TripTotals.timeZonesCrossed(by: [leg("1", from: "Asia/Kolkata", to: "Asia/Dubai"),
                                                        leg("2", from: "Asia/Dubai", to: "Asia/Kolkata")]), 3, "1½ and 1½")
    }

    func test_timeZonesCrossed_anUnknownZone_addsNothing() {
        let leg = MapLeg(id: "1", kind: .flight,
                         origin: FactsTestData.mark("A", latitude: 0, longitude: 0, zone: "America/New_York"),
                         destination: FactsTestData.mark("B", latitude: 0, longitude: 10),
                         start: start, end: start.addingTimeInterval(3600), flightNumber: nil)
        XCTAssertEqual(TripTotals.timeZonesCrossed(by: [leg]), 0)
    }

    func test_longestFlight_isDubaiToLouisville() throws {
        XCTAssertEqual(TripTotals.longestFlight(of: try europe().map.legs)?.id, "f3")
    }
}
