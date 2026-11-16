//
//  LiveTripTotalsTests.swift
//  CrewluvTests
//
//  The trip's miles along real paths (Stage 3 spec §8). The made-up real plane is `FactsTestData`'s: a degree of
//  longitude every 8 minutes from 10:15 UTC. One degree along the equator is 69.09 mi, and the flight is 1,382 mi.
//

import XCTest
@testable import Crewluv

final class LiveTripTotalsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    func test_totalMiles_andTheLongestFlight_countAlongTheRealPath() throws {
        // The flight north to 2° N and back is about 171 mi longer than its great circle: longer than a flight to
        // 20.5° E, whose airports are further apart.
        let seenUntil = FactsTestData.liveTime(atLongitude: 13)
        let wandering = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: seenUntil, latitude: FactsTestData.dogLeg), at: seenUntil)
        let straight = FactsTestData.equatorFlight(from: 0, to: 20.5, id: "straight")
        XCTAssertLessThan(wandering.distance, straight.distance)

        XCTAssertEqual(TripTotals.longestFlight(of: [straight, wandering])?.id, wandering.id)
        XCTAssertEqual(TripMapWording.totalMiles(of: [wandering]), Int((wandering.pathLength / GreatCircle.metersPerMile).rounded()))
        XCTAssertGreaterThan(TripMapWording.totalMiles(of: [wandering]), 1_382 + 150)
        XCTAssertEqual(TripMapWording.milesFlown(by: wandering.end, on: [wandering]), TripMapWording.totalMiles(of: [wandering]),
                       "once it's in, every mile of its path counts")
        XCTAssertEqual(FactsWording.longest(wandering, locale: locale), "E0 → E20, \(TripMapWording.milesText(TripMapWording.totalMiles(of: [wandering]), locale: locale))")
    }

    func test_milesFlown_ofAFlightInTheAir_isAsFarAsTheRealPlaneIs() throws {
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("11:10")), at: at("11:10"))
        XCTAssertEqual(TripMapWording.milesFlown(by: at("11:10"), on: [leg]), 475)
        XCTAssertEqual(TripMapWording.milesFlown(by: at("10:35"), on: [leg], isReplay: true), 173)
        XCTAssertEqual(TripMapWording.milesFlown(by: leg.start.addingTimeInterval(-60), on: [leg]), 0)
        XCTAssertEqual(TripMapWording.milesFlown(by: leg.end, on: [leg]), 1_382)
    }

    func test_soFar_inAReplay_countsAsFarAsTheRecordHasThePlane() throws {
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("11:10")), at: at("11:10"))
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: nil, span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        XCTAssertEqual(TripTotals.soFar(on: map, at: at("11:10"), sunEvents: [:]).miles, 475)
        XCTAssertEqual(TripTotals.soFar(on: map, at: at("10:35"), sunEvents: [:], isReplay: true).miles, 173)
    }
}
