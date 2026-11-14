//
//  LegStoryTests.swift
//  CrewluvTests
//
//  A flight's places and closest point to home (Stage 2 spec §4.2), along the equator, where a fraction of the way
//  is a fraction of the longitude.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LegStoryTests: XCTestCase {

    private func at(_ latitude: Double, _ longitude: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func story(_ geography: Geography? = FactsTestData.equator, home: CLLocationCoordinate2D? = nil) -> LegStory {
        LegStory(from: at(0, 0), to: at(0, 20), geography: geography, home: home)
    }

    func test_stretches_alongTheEquator_areEachPlaceFromWhereItStarts() {
        let stretches = story().stretches
        XCTAssertEqual(stretches.map(\.place.name), ["Alpha", "Bravo", "the Test Sea"], "the 21-mile Wedge is dropped")
        XCTAssertEqual(stretches[0].start, 0)
        XCTAssertEqual(stretches[1].start, 0.25, accuracy: 0.001)
        XCTAssertEqual(stretches[2].start, 0.6036, accuracy: 0.001, "the coast snap moves the sea 5 mi offshore: 12.0724° E")
    }

    func test_stretches_aGapWithNoPlace_changesNothing() {
        let geography = Geography(areas: [
            FactsTestData.box("Alpha", .country, west: -1, east: 5),
            FactsTestData.box("Alpha", .country, west: 7, east: 21),
        ], cities: [])
        XCTAssertEqual(story(geography).stretches.map(\.place.name), ["Alpha"])
    }

    func test_stretches_aPlaceHeldFor25MilesOrMore_counts() {
        let geography = Geography(areas: [
            FactsTestData.box("Wide", .country, west: 9, east: 9.5),
            FactsTestData.box("Alpha", .country, west: -1, east: 21),
        ], cities: [])
        // 0.5° is about 35 mi.
        XCTAssertEqual(story(geography).stretches.map(\.place.name), ["Alpha", "Wide", "Alpha"])
    }

    func test_stretches_noGeography_isEmpty() {
        XCTAssertEqual(story(nil).stretches, [])
    }

    func test_placeAtFraction_readsTheStretches() {
        let equatorStory = story()
        XCTAssertEqual(equatorStory.place(atFraction: 0.1)?.name, "Alpha")
        XCTAssertEqual(equatorStory.place(atFraction: 0.46)?.name, "Bravo", "inside the dropped Wedge")
        XCTAssertEqual(equatorStory.place(atFraction: 0.9)?.name, "the Test Sea")
    }

    func test_closestToHome_besideTheRoute_isWhereItPasses() throws {
        let closest = try XCTUnwrap(story(home: at(0.5, 14)).closestToHome)
        XCTAssertEqual(closest.fraction, 0.7, accuracy: 0.001)
        XCTAssertEqual(closest.meters, 55_597, accuracy: 100, "half a degree")
    }

    func test_closestToHome_over100MilesAway_isNil() {
        XCTAssertNil(story(home: at(2, 14)).closestToHome, "2° is about 138 mi")
    }

    func test_closestToHome_atAnEndOfTheRoute_isNil() {
        XCTAssertNil(story(home: at(0.5, 21)).closestToHome, "past the arrival airport")
    }

    func test_initLeg_aFlightFromHome_hasNoClosestPoint() {
        let leg = FactsTestData.equatorFlight(from: 0, to: 20)
        XCTAssertNil(LegStory(leg: leg, geography: nil, home: leg.origin).closestToHome)
        let home = FactsTestData.mark("HOME", latitude: 0.5, longitude: 14)
        XCTAssertNotNil(LegStory(leg: leg, geography: nil, home: home).closestToHome)
    }
}
