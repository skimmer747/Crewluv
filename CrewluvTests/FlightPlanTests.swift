//
//  FlightPlanTests.swift
//  CrewluvTests
//
//  The schedule's flight plan (Stage 3 spec §4), held to the shared cases in Fixtures/TripMap.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class FlightPlanTests: XCTestCase {

    private let nauticalMile = TripMapFixtures.nauticalMile

    func test_constants_matchTheSharedCases() throws {
        let constants = try TripMapFixtures.liveCases().constants
        XCTAssertEqual(FlightProgress.taxiOutAllowance, constants.taxiOutMinutes * 60)
        XCTAssertEqual(FlightProgress.taxiInAllowance, constants.taxiInMinutes * 60)
        XCTAssertEqual(FlightProgress.shortestCruise, constants.shortestCruiseMinutes * 60)
        XCTAssertEqual(FlightPlan.descentDistance, constants.descentDistanceNm * nauticalMile)
        XCTAssertEqual(FlightPlan.descentSpeed, constants.descentSpeedKt * nauticalMile / 3600, accuracy: 1e-9)
        XCTAssertEqual(FlightPlan.ownSpeedShares, constants.ownSpeedLeastShare...constants.ownSpeedMostShare)
    }

    func test_flown_everySharedCase_fliesItsSpeed_andKeepsTheSchedulesTimes() throws {
        let cases = try TripMapFixtures.liveCases()
        var ownSpeeds = 0
        for flightCase in cases.flights {
            let made = try cases.made(flightCase)
            let flown = made.plan.flown(along: made.path)
            XCTAssertEqual(flown.speed * 3600 / nauticalMile, flightCase.flownSpeedKt, accuracy: 0.01, flightCase.name)
            XCTAssertEqual([flown.departure, flown.takeoff, flown.touchdown, flown.arrival],
                           [made.plan.departure, made.plan.takeoff, made.plan.touchdown, made.plan.arrival], flightCase.name)
            XCTAssertEqual(flown.distance, made.plan.distance, flightCase.name)
            XCTAssertEqual(flown.isSteady, made.plan.isSteady, flightCase.name)
            if flown != made.plan { ownSpeeds += 1 }
        }
        XCTAssertGreaterThan(ownSpeeds, 0)
    }

    func test_flown_alongAPathNobodySaw_isThePlan() throws {
        let origin = CLLocationCoordinate2D(latitude: 38.1744, longitude: -85.736)
        let destination = CLLocationCoordinate2D(latitude: 39.8719, longitude: -75.2411)
        let path = FlightPath(from: origin, to: destination)
        let departure = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try XCTUnwrap(FlightPlan(departure: departure, arrival: departure.addingTimeInterval(6300), distance: path.length))
        XCTAssertEqual(plan.flown(along: path), plan)
    }

    func test_plans_everySharedCase_matches() throws {
        let cases = try TripMapFixtures.liveCases()
        XCTAssertFalse(cases.plans.isEmpty)
        for planCase in cases.plans {
            let distance = GreatCircle.distance(from: try cases.coordinate(of: planCase.from), to: try cases.coordinate(of: planCase.to))
            let plan = try XCTUnwrap(FlightPlan(departure: planCase.departure, arrival: planCase.arrival, distance: distance), planCase.name)
            XCTAssertEqual(plan.distance / nauticalMile, planCase.lengthNm, accuracy: 0.01, planCase.name)
            XCTAssertEqual(plan.takeoff.timeIntervalSince1970, planCase.takeoff.timeIntervalSince1970, accuracy: 0.05, planCase.name)
            XCTAssertEqual(plan.touchdown.timeIntervalSince1970, planCase.touchdown.timeIntervalSince1970, accuracy: 0.05, planCase.name)
            XCTAssertEqual(plan.isSteady, planCase.isShort, planCase.name)
            XCTAssertEqual(plan.speed * 3600 / nauticalMile, planCase.speedKt, accuracy: 0.01, planCase.name)
            for check in planCase.timeToFly {
                XCTAssertEqual(plan.timeToFly(check.distanceNm * nauticalMile), check.seconds, accuracy: 0.05,
                               "\(planCase.name): \(check.distanceNm) nm")
            }
            for check in planCase.distanceLeft {
                XCTAssertEqual(plan.distanceLeft(check.minutes * 60) / nauticalMile, check.distanceNm, accuracy: 0.01,
                               "\(planCase.name): \(check.minutes) min")
            }
        }
    }

    func test_timeToFly_theWholeLeg_isThePlansTimeInTheAir() throws {
        let departure = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try XCTUnwrap(FlightPlan(departure: departure, arrival: departure.addingTimeInterval(8 * 3600), distance: 7_000_000))
        XCTAssertFalse(plan.isSteady)
        XCTAssertEqual(plan.timeToFly(plan.distance), plan.timeInAir, accuracy: 1e-6)
        XCTAssertEqual(plan.distanceLeft(plan.timeInAir), plan.distance, accuracy: 1e-6)
    }

    func test_distanceLeft_isTheInverseOfTimeToFly() throws {
        let departure = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try XCTUnwrap(FlightPlan(departure: departure, arrival: departure.addingTimeInterval(8 * 3600), distance: 7_000_000))
        for distance in [50_000.0, 222_240, 1_000_000, 7_000_000, 7_500_000] {
            XCTAssertEqual(plan.distanceLeft(plan.timeToFly(distance)), distance, accuracy: 1e-6)
        }
    }

    func test_taxi_aLongBlock_hasBothAllowances() throws {
        let departure = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try XCTUnwrap(FlightPlan(departure: departure, arrival: departure.addingTimeInterval(8 * 3600), distance: 7_000_000))
        XCTAssertEqual(plan.taxiOut, 15 * 60)
        XCTAssertEqual(plan.taxiIn, 7 * 60)
        XCTAssertEqual(plan.timeInAir, 8 * 3600 - 22 * 60)
    }

    func test_taxi_aBlockTooShortForTheAllowances_hasNone() throws {
        let departure = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try XCTUnwrap(FlightPlan(departure: departure, arrival: departure.addingTimeInterval(30 * 60), distance: 100_000))
        XCTAssertEqual(plan.taxiOut, 0)
        XCTAssertEqual(plan.taxiIn, 0)
    }

    func test_init_arrivalNoLaterThanDeparture_isNil() {
        let departure = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertNil(FlightPlan(departure: departure, arrival: departure, distance: 1_000_000))
        XCTAssertNil(FlightPlan(departure: departure, arrival: departure.addingTimeInterval(-60), distance: 1_000_000))
    }
}
