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

    func test_prepare_aNewDelay_keepsTheRoute_andShowsTheSunEventsItHasUntilTheNewAreReady() async throws {
        let store = makeStore()
        let onTime = try europe()
        await store.prepare(onTime)
        let sunset = try XCTUnwrap(store.facts(for: onTime).sunEvents["f1"]?.first)
        let delayed = try europe(firstDelayMinutes: 90)

        // Nothing blinks: what it has shows while the new times' events are worked out.
        let before = store.facts(for: delayed)
        XCTAssertNotNil(before.stories["f1"], "same route")
        XCTAssertEqual(before.sunEvents["f1"], [sunset], "the old times', for a moment")

        await store.prepare(delayed)
        let after = try XCTUnwrap(store.facts(for: delayed).sunEvents["f1"]?.first)
        XCTAssertNotEqual(after.time, sunset.time, "the new times'")
    }

    func test_facts_passTheForecastsAndDay() throws {
        let forecast = LandingForecast(temperature: "48°F", condition: "rain")
        let facts = makeStore().facts(for: try europe(), forecasts: ["f1": forecast], dayNumber: 1, totalDays: 4)
        XCTAssertEqual(facts.forecasts["f1"], forecast)
        XCTAssertEqual(facts.dayNumber, 1)
        XCTAssertEqual(facts.totalDays, 4)
    }

    // MARK: - A real path (Stage 3 spec §8)

    /// A clock the tests move by hand, and the waits the store asked for.
    private final class TestClock {
        var now = FactsTestData.equinox
        var waits: [TimeInterval] = []
        /// The task that's waiting has been stopped, as when the path changes again.
        var isStopped = false
    }

    private func liveStore(_ clock: TestClock) -> LegStoryStore {
        LegStoryStore(loadFiles: { (FactsTestData.equator, nil) }, now: { clock.now }, sleep: { seconds in
            clock.waits.append(seconds)
            // A store that carries on after its wait was stopped is let through on the fifth, so its test fails
            // instead of hanging.
            if clock.isStopped, clock.waits.count < 5 { throw CancellationError() }
            clock.now = clock.now.addingTimeInterval(seconds)
        })
    }

    /// The equator flight alone, with a real plane that left the great circle and was last seen at `longitude`° E.
    private func liveMap(seenUntil longitude: Double, altitudeFeet: Double = 36_000) throws -> TripMap {
        let seenUntil = FactsTestData.liveTime(atLongitude: longitude)
        let live = FactsTestData.equatorLive(seenUntil: seenUntil, altitudeFeet: altitudeFeet, latitude: FactsTestData.dogLeg)
        let leg = try FactsTestData.equatorLiveLeg(live, at: seenUntil)
        return TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: nil, span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
    }

    func test_prepare_aRealPath_hasAStoryOfItsOwn_alongThePath() async throws {
        let clock = TestClock()
        let store = liveStore(clock)
        let map = try liveMap(seenUntil: 13)
        await store.prepare(map)

        let facts = store.facts(for: map)
        XCTAssertEqual(facts.stories["eq"]?.length, map.legs[0].pathLength)
        XCTAssertGreaterThan(try XCTUnwrap(facts.stories["eq"]).length, map.legs[0].distance, "not the route's, along the great circle")
        XCTAssertNotNil(facts.sunEvents["eq"])
        XCTAssertEqual(clock.waits, [])
    }

    func test_prepare_whenThePathGrowsWithinAMinute_waitsTheMinuteOut_thenMakesTheStoryAgain() async throws {
        let clock = TestClock()
        let store = liveStore(clock)
        let first = try liveMap(seenUntil: 8)
        await store.prepare(first)

        // A new place 20 seconds later.
        clock.now = clock.now.addingTimeInterval(20)
        let grown = try liveMap(seenUntil: 8.25)
        XCTAssertEqual(store.facts(for: grown).stories["eq"]?.length, first.legs[0].pathLength, "the story it has shows meanwhile")

        await store.prepare(grown)
        XCTAssertEqual(clock.waits, [40], "the rest of the minute")
        XCTAssertEqual(store.facts(for: grown).stories["eq"]?.length, grown.legs[0].pathLength)
    }

    func test_prepare_anotherHome_makesARealPathsStoryAgain_withItsClosestPoint() async throws {
        let clock = TestClock()
        let store = liveStore(clock)
        let map = try liveMap(seenUntil: 8)
        await store.prepare(map)
        XCTAssertNil(store.facts(for: map).stories["eq"]?.closestToHome)

        clock.now = clock.now.addingTimeInterval(60)
        let withHome = TripMap(mode: map.mode, legs: map.legs, home: FactsTestData.homeByTheEquator, span: map.span, tripDays: nil)
        await store.prepare(withHome)
        XCTAssertNotNil(store.facts(for: withHome).stories["eq"]?.closestToHome, "the same path, made again for the new home")
    }

    func test_prepare_whenThePathGrowsAMinuteLater_makesTheStoryAtOnce() async throws {
        let clock = TestClock()
        let store = liveStore(clock)
        await store.prepare(try liveMap(seenUntil: 8))

        clock.now = clock.now.addingTimeInterval(60)
        let grown = try liveMap(seenUntil: 9)
        await store.prepare(grown)
        XCTAssertEqual(clock.waits, [])
        XCTAssertEqual(store.facts(for: grown).stories["eq"]?.length, grown.legs[0].pathLength)
    }

    func test_prepare_stoppedWhileItWaits_makesNothing_andTheNextOneDoes() async throws {
        let clock = TestClock()
        let store = liveStore(clock)
        let first = try liveMap(seenUntil: 8)
        await store.prepare(first)

        clock.now = clock.now.addingTimeInterval(20)
        clock.isStopped = true
        let grown = try liveMap(seenUntil: 8.25)
        await store.prepare(grown)
        XCTAssertEqual(clock.waits, [40])
        XCTAssertEqual(store.facts(for: grown).stories["eq"]?.length, first.legs[0].pathLength, "still the story it had")

        // The path changes again, which starts `prepare` afresh: it waits what's left of the minute.
        clock.isStopped = false
        clock.now = clock.now.addingTimeInterval(10)
        let grownAgain = try liveMap(seenUntil: 8.5)
        await store.prepare(grownAgain)
        XCTAssertEqual(clock.waits, [40, 30])
        XCTAssertEqual(store.facts(for: grownAgain).stories["eq"]?.length, grownAgain.legs[0].pathLength)
    }

    func test_prepare_theSamePathAgain_makesNothing() async throws {
        let clock = TestClock()
        let store = liveStore(clock)
        let map = try liveMap(seenUntil: 8)
        await store.prepare(map)
        clock.now = clock.now.addingTimeInterval(5)
        await store.prepare(try liveMap(seenUntil: 8))
        XCTAssertEqual(clock.waits, [], "nothing to wait for: the path is the one its story was made from")
    }

    func test_facts_aFlightBackOnTheSchedule_hasItsRoutesStoryAgain() async throws {
        // Its live data is gone, as after Disconnect: the leg flies the great circle again.
        let clock = TestClock()
        let store = liveStore(clock)
        await store.prepare(try liveMap(seenUntil: 13))

        let leg = FactsTestData.equatorFlight(from: 0, to: 20)
        let scheduled = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: nil, span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        await store.prepare(scheduled)
        XCTAssertEqual(store.facts(for: scheduled).stories["eq"]?.length, leg.distance)
    }

    func test_prepare_aFlightBackOnItsRealPath_afterATurnOnTheSchedule_hasItsOwnSunEventsAgain() async throws {
        // The equator flight seven hours later, into the evening: the real plane and the schedule's each see the
        // sun set, at different times. Its live data goes, and comes back with the very same path.
        let evening: TimeInterval = 7 * 3600
        let flown = FactsTestData.equatorLive(seenUntil: FactsTestData.liveTime(atLongitude: 13))
        let fix = try XCTUnwrap(flown.fix)
        let live = LiveFlight(
            legID: flown.legID, callsign: flown.callsign, state: flown.state,
            fix: LiveFlight.Fix(latitude: fix.latitude, longitude: fix.longitude, altitudeFeet: fix.altitudeFeet,
                                groundSpeedKnots: fix.groundSpeedKnots, trackDegrees: fix.trackDegrees, isOnGround: false,
                                registration: fix.registration, typeCode: fix.typeCode, seenAt: fix.seenAt.addingTimeInterval(evening)),
            landedAt: nil,
            trail: flown.trail.map {
                LiveFlight.TrailPoint(time: $0.time.addingTimeInterval(evening), latitude: $0.latitude, longitude: $0.longitude,
                                      altitudeFeet: $0.altitudeFeet)
            })
        func map(_ live: LiveFlight?) throws -> TripMap {
            let scheduled = FactsTestData.equatorFlight(from: 0, to: 20, departure: FactsTestData.equinox.addingTimeInterval(evening))
            let flight = try XCTUnwrap(MapFlight(departure: scheduled.start, arrival: scheduled.end, from: scheduled.origin.coordinate,
                                                 to: scheduled.destination.coordinate, live: live))
            let progress = flight.progress(at: fix.seenAt.addingTimeInterval(evening))
            let leg = MapLeg(id: scheduled.id, kind: .flight, origin: scheduled.origin, destination: scheduled.destination,
                             start: progress.start, end: progress.end, flightNumber: scheduled.flightNumber, flight: flight)
            return TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: nil, span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        }
        let clock = TestClock()
        let store = liveStore(clock)

        await store.prepare(try map(live))
        let real = try XCTUnwrap(store.facts(for: try map(live)).sunEvents["eq"])
        XCTAssertEqual(real.map(\.kind), [.sunset])

        await store.prepare(try map(nil))
        let planned = try XCTUnwrap(store.facts(for: try map(nil)).sunEvents["eq"])
        XCTAssertNotEqual(planned.first?.time, real.first?.time, "the schedule's plane is elsewhere when the sun sets")

        clock.now = clock.now.addingTimeInterval(5)
        await store.prepare(try map(live))
        XCTAssertEqual(store.facts(for: try map(live)).sunEvents["eq"], real, "its own again, not the schedule's")
        XCTAssertEqual(clock.waits, [], "and at once: it's a flight newly seen")
    }

    func test_prepare_whenTheClockWasSetBack_doesntHoldTheStoryUp() async throws {
        let clock = TestClock()
        let store = liveStore(clock)
        await store.prepare(try liveMap(seenUntil: 8))

        // The phone's clock goes back five minutes. The last story now looks as if it were made in the future.
        clock.now = clock.now.addingTimeInterval(-300)
        let grown = try liveMap(seenUntil: 8.25)
        await store.prepare(grown)
        XCTAssertEqual(clock.waits, [])
        XCTAssertEqual(store.facts(for: grown).stories["eq"]?.length, grown.legs[0].pathLength)
    }

    func test_facts_handOnWhetherItsAReplay() throws {
        XCTAssertFalse(makeStore().facts(for: try europe()).isReplay)
        XCTAssertTrue(makeStore().facts(for: try europe(), isReplay: true).isReplay)
    }

    func test_preparationKey_changesWhenARealPathGrows_orItsSkyIsSeenFromAnotherHeight() throws {
        let key = LegStoryStore.preparationKey(for: try liveMap(seenUntil: 8))
        XCTAssertEqual(key, LegStoryStore.preparationKey(for: try liveMap(seenUntil: 8)))
        XCTAssertNotEqual(key, LegStoryStore.preparationKey(for: try liveMap(seenUntil: 8.25)))
        XCTAssertNotEqual(key, LegStoryStore.preparationKey(for: try liveMap(seenUntil: 8, altitudeFeet: 38_000)))
    }

    func test_pathKey_isOnlyForAFlightWithARealPath() throws {
        XCTAssertNil(LegStoryStore.pathKey(for: FactsTestData.equatorFlight(from: 0, to: 20)))
        XCTAssertNil(LegStoryStore.pathKey(for: try FactsTestData.equatorLiveLeg(nil, at: FactsTestData.equinox)))
        XCTAssertNotNil(LegStoryStore.pathKey(for: try liveMap(seenUntil: 8).legs[0]))
    }

    func test_routeKey_namesHomeOnlyWhenTheFlightPassesIt() throws {
        let map = try europe()
        XCTAssertEqual(LegStoryStore.routeKey(for: map.legs[0], home: map.home), "SDF-CGN")
        XCTAssertEqual(LegStoryStore.routeKey(for: map.legs[1], home: map.home), "CGN-DXB|SDF")
    }

    func test_preparationKey_changesWithADelayOrAnotherHome() throws {
        let map = try europe()
        let noHome = try XCTUnwrap(TripMap.make(tripLegs: TripMapTestLegs.europeTrip(), isNextTrip: false, homeAirportCode: nil,
                                                legacyDelayMinutes: nil, at: TripMapTestLegs.tripStart,
                                                coordinate: TripMapTestLegs.coordinate))
        XCTAssertEqual(LegStoryStore.preparationKey(for: map), LegStoryStore.preparationKey(for: try europe()))
        XCTAssertNotEqual(LegStoryStore.preparationKey(for: map), LegStoryStore.preparationKey(for: try europe(firstDelayMinutes: 90)))
        XCTAssertNotEqual(LegStoryStore.preparationKey(for: map), LegStoryStore.preparationKey(for: noHome))
    }
}
