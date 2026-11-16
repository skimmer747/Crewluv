//
//  MapLegCourseTests.swift
//  CrewluvTests
//
//  A leg as the facts follow it (Stage 3 spec §8): its path, and its times by its record or by the schedule.
//  The made-up real plane is `FactsTestData`'s: a degree of longitude every 8 minutes from 10:15 UTC.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class MapLegCourseTests: XCTestCase {

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    private let schedule = FactsTestData.equatorFlight(from: 0, to: 20)

    /// The real plane, last seen at `seenUntil`, with the leg as it's handed on then.
    private func live(seenUntil: String, unseen: ClosedRange<Double>? = nil) throws -> MapLeg {
        try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at(seenUntil), unseen: unseen), at: at(seenUntil))
    }

    private func meters(_ degrees: Double) -> Double { degrees * FactsTestData.metersADegree }

    // MARK: - The path

    func test_path_withNoFlight_isTheGreatCircle() {
        XCTAssertFalse(schedule.path.isReal)
        XCTAssertEqual(schedule.path.length, schedule.distance)
        XCTAssertEqual(schedule.pathLength, schedule.distance)
    }

    func test_pathLength_ofARealPathThatLeavesTheGreatCircle_isLonger() throws {
        let seenUntil = FactsTestData.liveTime(atLongitude: 13)
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: seenUntil, latitude: FactsTestData.dogLeg), at: seenUntil)
        XCTAssertTrue(leg.path.isReal)
        // Each ramp is the long side of a 1° by 2° triangle: about 1.24° more than the degree it covers.
        XCTAssertEqual(leg.pathLength - leg.distance, meters(2 * (5.0.squareRoot() - 1)), accuracy: meters(0.05))
    }

    func test_kindAtDistance_readsThePathsStretches() throws {
        let leg = try live(seenUntil: "11:10", unseen: 4...6.5)
        XCTAssertEqual(leg.path.kind(atDistance: meters(3)), .seen)
        XCTAssertEqual(leg.path.kind(atDistance: meters(5)), .unseen, "nobody saw it from 4° E to 6.5° E")
        XCTAssertEqual(leg.path.kind(atDistance: meters(6.7)), .seen)
        XCTAssertEqual(leg.path.kind(atDistance: meters(15)), .planned, "the way ahead")
        XCTAssertEqual(schedule.path.kind(atDistance: meters(5)), .planned)
    }

    func test_hasLiveData_onceCrewluCloudHasSeenTheFlight() throws {
        XCTAssertFalse(schedule.hasLiveData, "a leg made by hand")
        XCTAssertFalse(try FactsTestData.equatorLiveLeg(nil, at: at("11:10")).hasLiveData, "no answer for the leg")
        let waiting = LiveFlight(legID: "eq", callsign: "TST1", state: .waiting, fix: nil, landedAt: nil, trail: [])
        XCTAssertFalse(try FactsTestData.equatorLiveLeg(waiting, at: at("11:10")).hasLiveData, "watched, and never seen")
        XCTAssertTrue(try live(seenUntil: "11:10").hasLiveData)
    }

    // MARK: - Its times

    func test_timeAtDistance_withARecord_isTheRecords_forEverySharedCase() throws {
        let cases = try TripMapFixtures.liveCases()
        var checked = 0
        for flightCase in cases.flights {
            guard let record = flightCase.record, let moment = flightCase.moments.first else { continue }
            let leg = try cases.mapLeg(flightCase, at: moment)
            for time in record.times {
                let found = try XCTUnwrap(leg.time(atDistance: time.alongNm * TripMapFixtures.nauticalMile), flightCase.name)
                XCTAssertEqual(found.timeIntervalSince1970, time.at.timeIntervalSince1970, accuracy: 0.5, "\(flightCase.name) at \(time.alongNm) nm")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 15, "the cases' times")
    }

    func test_timeAtDistance_onTheSchedule_isThatShareOfItsTimeInTheAir() {
        XCTAssertEqual(schedule.time(atDistance: schedule.distance / 4), at("11:00"), "a quarter of three hours after 10:15")
        XCTAssertEqual(schedule.time(atDistance: 0), at("10:15"))
        XCTAssertEqual(schedule.time(atDistance: schedule.distance), at("13:15"))
    }

    func test_timeAtDistance_ofALegThatGoesNowhere_isItsTakeoff() {
        let nowhere = FactsTestData.equatorFlight(from: 0, to: 0)
        XCTAssertEqual(nowhere.pathLength, 0)
        XCTAssertEqual(nowhere.time(atDistance: 0), at("10:15"))
        XCTAssertEqual(nowhere.halfwayTime, at("11:45"), "halfway through its time in the air, as before")
    }

    func test_timeAtDistance_withARecord_isWhenTheRealPlaneWasThere() throws {
        let leg = try live(seenUntil: "11:10")
        XCTAssertEqual(try XCTUnwrap(leg.time(atDistance: meters(5))).timeIntervalSince1970, at("10:55").timeIntervalSince1970, accuracy: 2)
        XCTAssertEqual(schedule.time(atDistance: meters(5)), at("11:00"), "the schedule's plane is there five minutes later")
    }

    func test_halfwayTime_onTheSchedule_isTheMiddleOfItsTimeInTheAir() {
        XCTAssertEqual(schedule.halfwayTime, at("11:45"))
    }

    func test_halfwayTime_withARecord_isWhenTheRealPlaneIsHalfwayAlongItsPath() throws {
        // Seen as far as 6.875° E. At its own 450 kt it's at 10° E 25 minutes later.
        let leg = try live(seenUntil: "11:10")
        XCTAssertEqual(try XCTUnwrap(leg.halfwayTime).timeIntervalSince1970, at("11:35").timeIntervalSince1970, accuracy: 30)
    }

    func test_isTimeEstimated_aheadOfWhereTheRealPlaneWasLastSeen() throws {
        let leg = try live(seenUntil: "11:10")
        XCTAssertFalse(leg.isTimeEstimated(atDistance: meters(5)), "it was seen there")
        XCTAssertTrue(leg.isTimeEstimated(atDistance: meters(10)), "it isn't there yet")
        XCTAssertFalse(schedule.isTimeEstimated(atDistance: meters(10)), "the schedule's times aren't the real plane's estimate")

        let landedAt = FactsTestData.liveTime(atLongitude: 20)
        let landed = try FactsTestData.equatorLiveLeg(
            FactsTestData.equatorLive(seenUntil: FactsTestData.liveTime(atLongitude: 19.75), landedAt: landedAt), at: landedAt)
        XCTAssertFalse(landed.isTimeEstimated(atDistance: meters(19.9)), "it has landed: every time is real")
    }

    func test_isSeen_onlyWhereTheRealPlaneWasSeen() throws {
        let leg = try live(seenUntil: "11:10", unseen: 4...6.5)
        XCTAssertTrue(leg.isSeen(atDistance: meters(3)))
        XCTAssertFalse(leg.isSeen(atDistance: meters(5)), "nobody saw it cross 5° E")
        XCTAssertTrue(leg.isSeen(atDistance: meters(6.7)))
        XCTAssertFalse(leg.isSeen(atDistance: meters(15)), "it isn't there yet")
        XCTAssertTrue(schedule.isSeen(atDistance: meters(5)), "the schedule tells every crossing")
    }

    // MARK: - The sky's questions

    func test_airborne_onTheSchedule_isItsTimeInTheAir() {
        XCTAssertEqual(schedule.airborne, DateInterval(start: at("10:15"), end: at("13:15")))
    }

    func test_airborne_withARecord_isFromLeavingTheAirportToItsTouchdown() throws {
        let leg = try live(seenUntil: "11:10")
        let record = try XCTUnwrap(leg.flight?.record)
        let airborne = try XCTUnwrap(leg.airborne)
        // The first place it was seen is 15 nm out at 10:17. At the plan's 420 kt it left about two minutes before.
        XCTAssertEqual(airborne.start.timeIntervalSince1970, at("10:15").timeIntervalSince1970, accuracy: 30)
        XCTAssertEqual(airborne.end, record.touchdown)
        XCTAssertLessThan(airborne.end, at("13:15"), "it's ahead of the schedule")
    }

    func test_coursePosition_keepsMovingAfterThePlaneWasLastSeen() throws {
        let leg = try live(seenUntil: "11:10")
        XCTAssertEqual(leg.coursePosition(at: at("11:10")).longitude, 6.875, accuracy: 0.001)
        XCTAssertEqual(leg.coursePosition(at: at("11:12")).longitude, 7.125, accuracy: 0.01, "two more minutes at 450 kt")
        XCTAssertEqual(leg.plane(at: at("11:12"), isReplay: false).coordinate.longitude, 6.875, accuracy: 0.001,
                       "while the plane the map draws waits where it was last seen")
    }

    func test_coursePosition_onTheSchedule_isTheSchedulesPlane() {
        XCTAssertEqual(schedule.coursePosition(at: at("11:45")).longitude, 10, accuracy: 1e-6)
    }
}
