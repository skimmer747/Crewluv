//
//  MilestoneTests.swift
//  CrewluvTests
//
//  A flight's milestones (Stage 2 spec §4.3). The flights along the equator are in the air from 10:15 UTC for three
//  hours, so each tenth of the way is 18 minutes.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class MilestoneTests: XCTestCase {

    private func milestones(_ leg: MapLeg, _ geography: Geography, home: AirportMark? = nil) -> [Milestone] {
        Milestone.milestones(on: leg, story: LegStory(leg: leg, geography: geography, home: home))
    }

    private func assertMilestone(_ milestone: Milestone, _ kind: Milestone.Kind, at iso: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(milestone.kind, kind, file: file, line: line)
        XCTAssertEqual(milestone.time.timeIntervalSince1970, FactsTestData.date(iso).timeIntervalSince1970, accuracy: 5, file: file, line: line)
    }

    func test_milestones_alongTheEquator_areTheCrossingsHalfwayAndHome() {
        let home = FactsTestData.mark("HOME", latitude: 0.5, longitude: 14)
        let found = milestones(FactsTestData.equatorFlight(from: 0, to: 20), FactsTestData.equator, home: home)
        XCTAssertEqual(found.count, 4)
        assertMilestone(found[0], .crossedInto("Bravo"), at: "2026-03-20T11:00:00Z")
        assertMilestone(found[1], .halfway, at: "2026-03-20T11:45:00Z")
        assertMilestone(found[2], .outOver("the Test Sea"), at: "2026-03-20T12:03:39Z") // 5 mi offshore, by the coast snap
        assertMilestone(found[3], .closestToHome(miles: 35), at: "2026-03-20T12:21:00Z")
    }

    func test_milestones_aStateLineInOneCountry_namesTheState_aBorderNamesTheCountry() {
        let geography = Geography(areas: [
            FactsTestData.box("North", .state, country: "Delta", west: 29, east: 35.5),
            FactsTestData.box("South", .state, country: "Delta", west: 35.5, east: 37),
            FactsTestData.box("Delta", .country, west: 29, east: 37),
            FactsTestData.box("Echo", .country, west: 37, east: 41),
        ], cities: [])
        let leg = FactsTestData.equatorFlight(from: 30, to: 40, departure: FactsTestData.equinox.addingTimeInterval(4 * 3600))
        let found = milestones(leg, geography)
        XCTAssertEqual(found.map(\.kind), [.halfway, .crossedInto("South"), .crossedInto("Echo")])
        assertMilestone(found[1], .crossedInto("South"), at: "2026-03-20T15:54:00Z")
        assertMilestone(found[2], .crossedInto("Echo"), at: "2026-03-20T16:21:00Z")
    }

    func test_milestones_oneSeaIntoAnother_isNone_butLandAfterIt_isTheCountry() {
        let geography = Geography(areas: [
            FactsTestData.box("the Test Sea", .water, west: 49, east: 53),
            FactsTestData.box("the Other Sea", .water, west: 53, east: 56),
            FactsTestData.box("Foxtrot", .country, west: 56, east: 61),
        ], cities: [])
        let leg = FactsTestData.equatorFlight(from: 50, to: 60, departure: FactsTestData.equinox.addingTimeInterval(8 * 3600))
        let found = milestones(leg, geography)
        XCTAssertEqual(found.map(\.kind), [.halfway, .crossedInto("Foxtrot")])
        assertMilestone(found[1], .crossedInto("Foxtrot"), at: "2026-03-20T20:01:42Z") // 5 mi before the coast, by the coast snap
    }

    func test_milestones_aGapWhereOnlyTheCountryIsKnown_isNotAMilestone() {
        let geography = Geography(areas: [
            FactsTestData.box("Kansas", .state, country: "the United States", west: -1, east: 5),
            FactsTestData.box("Nebraska", .state, country: "the United States", west: 6, east: 21),
            FactsTestData.box("the United States", .country, west: -1, east: 21),
        ], cities: [])
        let found = milestones(FactsTestData.equatorFlight(from: 0, to: 20), geography)
        XCTAssertEqual(found.map(\.kind), [.crossedInto("Nebraska"), .halfway])
    }

    func test_milestones_backIntoTheSameStateAfterAGap_isNotACrossing() {
        let geography = Geography(areas: [
            FactsTestData.box("Kansas", .state, country: "the United States", west: -1, east: 5),
            FactsTestData.box("Kansas", .state, country: "the United States", west: 6, east: 21),
            FactsTestData.box("the United States", .country, west: -1, east: 21),
        ], cities: [])
        XCTAssertEqual(milestones(FactsTestData.equatorFlight(from: 0, to: 20), geography).map(\.kind), [.halfway])
    }

    func test_roundedMiles_toTheNearest5_neverUnder5() {
        let mile = GreatCircle.metersPerMile
        XCTAssertEqual(Milestone.roundedMiles(34.55 * mile), 35)
        XCTAssertEqual(Milestone.roundedMiles(52 * mile), 50)
        XCTAssertEqual(Milestone.roundedMiles(53 * mile), 55)
        XCTAssertEqual(Milestone.roundedMiles(2 * mile), 5)
    }
}
