//
//  LongGapFactsTests.swift
//  CrewluvTests
//
//  The facts past 2 hours out of tracking range (long gap design §3), in US English for a family in Louisville. The
//  made-up flight is `FactsTestData`'s equator flight, to 24° E: in the air from 10:15 to 13:15 UTC by the schedule,
//  whose cruise is 513.7 kt. The real plane flies a degree every 8 minutes (450 kt) and is last seen at 3.75° E at
//  10:45. From there it's flown on at 450 kt for 2 hours of its cruise and at the plan's after, one speed of 460.2 kt,
//  so it touches down at 13:33.6 by its estimate and is guessed at 19.1° E at 12:45, 2 hours after it was last seen.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LongGapFactsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    /// Along the equator: Alpha to 5° E, Bravo to 10° E, the Atlantic to 20° E, the Test Sea to 21° E and Delta to
    /// 25° E, with Portville 0.1° north of 19.1° E.
    private let geography = Geography(
        areas: [FactsTestData.box("Alpha", .country, west: -1, east: 5),
                FactsTestData.box("Bravo", .country, west: 5, east: 10),
                FactsTestData.box("the Atlantic", .water, west: 10, east: 20),
                FactsTestData.box("the Test Sea", .water, west: 20, east: 21),
                FactsTestData.box("Delta", .country, west: 21, east: 25)],
        cities: [Geography.City(name: "Portville", lat: 0.1, lon: 19.1)]
    )

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    private func plain(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// The facts of a map of the one flight, last seen at `seenUntil` and nobody seeing it over `unseen`, made at `now`.
    private func facts(seenUntil: String = "10:45", now: String, unseen: ClosedRange<Double>? = nil,
                       isReplay: Bool = false) throws -> TripFacts {
        let live = FactsTestData.equatorLive(seenUntil: at(seenUntil), unseen: unseen)
        let leg = try FactsTestData.equatorLiveLeg(live, at: at(now), to: 24)
        let home = FactsTestData.homeByTheEquator
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: home,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        return TripFacts(tripMap: map, geography: geography, comparisons: nil,
                         stories: [leg.id: LegStory(leg: leg, geography: geography, home: home)],
                         sunEvents: [leg.id: SkyFacts.sunEvents(on: leg)], calendar: calendar, locale: locale,
                         isReplay: isReplay)
    }

    private func events(_ facts: TripFacts, at time: String) -> [String?]? {
        facts.tripSoFar(at: at(time)).flights.first?.events.map { plain($0.text) }
    }

    // MARK: - What's below

    func test_below_pastTwoHoursOutOfRange_namesTheOcean_withNoCity() throws {
        // At 12:43, 1 h 58 min after it was last seen, it's guessed at 18.8° E, 20 mi from Portville.
        XCTAssertEqual(try facts(now: "12:43").headline(at: at("12:43")), "Over the Atlantic, near Portville")
        // At 12:48, 2 h 3 min after, at 19.5° E: still 26 mi from Portville, but past 2 hours no city is told.
        XCTAssertEqual(try facts(now: "12:48").headline(at: at("12:48")), "Over the Atlantic")
    }

    func test_below_pastTwoHoursOutOfRange_overASeaOrLand_namesNothing_andTheHeadlineIsTheLandingCountdown() throws {
        // It reaches the gate at 13:40.6 by its estimate. At 12:58 it's guessed at 20.75° E, over the Test Sea.
        XCTAssertEqual(try facts(now: "12:58").headline(at: at("12:58")), "Landing in 43 min")
        // At 13:10, at 22.2° E, over Delta.
        let overDelta = try facts(now: "13:10")
        XCTAssertEqual(overDelta.headline(at: at("13:10")), "Landing in 31 min")
        XCTAssertNil(overDelta.belowText(on: try XCTUnwrap(overDelta.tripMap.currentLeg), at: at("13:10")))
        // Within 2 hours of the last sighting, land is named as before.
        let near = try facts(seenUntil: "11:20", now: "13:10")
        XCTAssertEqual(near.headline(at: at("13:10")), "Over Delta")
    }

    func test_below_inAReplay_pastTwoHoursAfterTheLastSighting_namesOnlyTheOcean() throws {
        let replay = try facts(now: "13:10", isReplay: true)
        XCTAssertEqual(replay.headline(at: at("12:43")), "Over the Atlantic, near Portville")
        XCTAssertEqual(replay.headline(at: at("12:48")), "Over the Atlantic")
    }

    func test_below_inAReplay_ofAGapClosedByANewSighting_isWhatsOnTheStraightJoin() throws {
        // Seen again at 20.5° E at 12:59, the gap is a straight join between two places the plane was seen, so at
        // 12:50, at 19.4° E on it, the city by it is told as ever.
        let replay = try facts(seenUntil: "13:05", now: "13:05", unseen: 3.8...20.5, isReplay: true)
        XCTAssertEqual(replay.headline(at: at("12:50")), "Over the Atlantic, near Portville")
    }

    func test_isPastGuessHorizon_fromTwoHoursOutOfRange() {
        let place = CLLocationCoordinate2D(latitude: 0, longitude: 10)
        func plane(unseenFor: TimeInterval?) -> PlanePosition {
            PlanePosition(distance: 0, coordinate: place, unseenFor: unseenFor, isSeenInAir: false)
        }
        XCTAssertFalse(plane(unseenFor: nil).isPastGuessHorizon)
        XCTAssertFalse(plane(unseenFor: 2 * 60 * 60).isPastGuessHorizon)
        XCTAssertTrue(plane(unseenFor: 2 * 60 * 60 + 1).isPastGuessHorizon)
    }

    // MARK: - Events

    func test_events_guessedPastTwoHoursAfterTheLastSighting_areHeld() throws {
        // By the guess it crosses into Delta at 21° E just before 13:00, over 2 hours after it was last seen: not told. The
        // others were guessed within the 2 hours, and are told with "about".
        let guessed = try facts(now: "13:10")
        XCTAssertEqual(events(guessed, at: "13:10"), [
            "Closest to home, 35 mi · about 8:05 AM L", "Halfway · about 7:49 AM L", "Out over the Atlantic · about 7:34 AM L",
            "Crossed into Bravo · about 6:54 AM L",
        ])
        XCTAssertEqual(guessed.latestEvent(at: at("13:10"))?.title, "Closest to home, 35 mi")
        XCTAssertNotEqual(guessed.headline(at: at("13:02")), "Just crossed into Delta")
    }

    func test_events_neverTrackedAgain_areAllToldAsBestGuesses_onceTheFlightIsOver() throws {
        // It reaches the gate at 13:40.6 by its estimate. After that the crossing into Delta is told too.
        let over = try facts(now: "13:45")
        XCTAssertEqual(events(over, at: "13:45")?.first, "Crossed into Delta · about 8:59 AM L")
        XCTAssertEqual(over.tripSoFar(at: at("13:45")).flights.first?.events.count, 5)
    }

    func test_events_onceThePlaneIsTrackedAgain_areToldOnTheStraightJoin() throws {
        // Nobody saw it from 3.75° E at 10:45 to 20.5° E at 12:59. Seen again, it crossed into Delta just before
        // 13:03, and what it passed in the gap is told on the straight join between the two, with "about".
        let trackedAgain = try facts(seenUntil: "13:05", now: "13:05", unseen: 3.8...20.5)
        XCTAssertEqual(events(trackedAgain, at: "13:05"), [
            "Crossed into Delta · 9:02 AM L", "Closest to home, 35 mi · about 8:06 AM L", "Halfway · about 7:51 AM L",
            "Out over the Atlantic · about 7:35 AM L", "Crossed into Bravo · about 6:55 AM L",
        ])
    }

    // MARK: - The card for VoiceOver

    func test_cardSummary_pastTwoHoursOverLand_leavesOutWhatsBelow() throws {
        XCTAssertEqual(plain(try facts(now: "13:10").cardSummary(now: at("13:10"), pilotName: "Alex")),
                       "TST1 to E24, about 19 minutes behind schedule, last tracked over Alpha. Lands about 9:40 AM your time. Latest: closest to home, 35 miles, about 1 hour 5 minutes ago.")
        XCTAssertTrue(try XCTUnwrap(plain(try facts(now: "12:48").cardSummary(now: at("12:48"), pilotName: "Alex")))
                        .hasPrefix("TST1 to E24, about 19 minutes behind schedule, over the Atlantic, last tracked over Alpha. "))
    }

    // MARK: - The oceans

    func test_isOcean_isTrueOfTheFiveOceansOnly() {
        XCTAssertTrue(Geography.Place(name: "the Pacific", kind: .water, country: nil).isOcean)
        XCTAssertFalse(Geography.Place(name: "the Sea of Okhotsk", kind: .water, country: nil).isOcean)
        XCTAssertFalse(Geography.Place(name: "Japan", kind: .country, country: "Japan").isOcean)
    }

    func test_oceanNames_areAllInTheAppsGeography() throws {
        let waters = Set(try FactsTestData.appGeography().areas.filter { $0.kind == .water }.map(\.name))
        XCTAssertEqual(Geography.Place.oceanNames.subtracting(waters), [])
    }
}
