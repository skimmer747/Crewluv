//
//  LegStoryStoreTests.swift
//  CrewluvTests
//
//  Building and keeping the stories (Stage 2 spec §3.2), with the repository's data files.
//

import XCTest
@testable import Crewluv

@MainActor
final class LegStoryStoreTests: XCTestCase {

    private func makeStore() -> LegStoryStore {
        LegStoryStore(loadFiles: { (try? FactsTestData.appGeography(), try? FactsTestData.appComparisons()) })
    }

    private func europe(firstDelayMinutes: Int? = nil) throws -> TripMap {
        try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(firstDelayMinutes: firstDelayMinutes), at: TripMapTestLegs.tripStart))
    }

    func test_facts_beforePrepare_haveNoStoriesOrSunEvents() throws {
        let facts = makeStore().facts(for: try europe())
        XCTAssertTrue(facts.stories.isEmpty)
        XCTAssertTrue(facts.sunEvents.isEmpty)
        XCTAssertNil(facts.geography)
    }

    func test_prepare_buildsEveryFlight() async throws {
        let store = makeStore()
        let map = try europe()
        await store.prepare(map)
        let facts = store.facts(for: map)
        XCTAssertEqual(Set(facts.stories.keys), ["f1", "f2", "f3"])
        XCTAssertEqual(facts.sunEvents["f1"]?.count, 1, "the cockpit sunset over the Atlantic")
        XCTAssertNotNil(facts.geography)
        XCTAssertNotNil(facts.comparisons)
    }

    func test_prepare_aNewDelay_keepsTheRouteButRedoesTheSun() async throws {
        let store = makeStore()
        await store.prepare(try europe())
        let delayed = try europe(firstDelayMinutes: 90)

        let before = store.facts(for: delayed)
        XCTAssertNotNil(before.stories["f1"], "same route")
        XCTAssertNil(before.sunEvents["f1"], "new times")

        await store.prepare(delayed)
        XCTAssertNotNil(store.facts(for: delayed).sunEvents["f1"])
    }

    func test_facts_passTheForecastsAndDay() throws {
        let forecast = LandingForecast(temperature: "48°F", condition: "rain")
        let facts = makeStore().facts(for: try europe(), forecasts: ["f1": forecast], dayNumber: 1, totalDays: 4)
        XCTAssertEqual(facts.forecasts["f1"], forecast)
        XCTAssertEqual(facts.dayNumber, 1)
        XCTAssertEqual(facts.totalDays, 4)
    }

    func test_routeKey_namesHomeOnlyWhenTheFlightPassesIt() throws {
        let map = try europe()
        XCTAssertEqual(LegStoryStore.routeKey(for: map.legs[0], home: map.home), "SDF-CGN")
        XCTAssertEqual(LegStoryStore.routeKey(for: map.legs[1], home: map.home), "CGN-DXB|SDF")
    }
}
