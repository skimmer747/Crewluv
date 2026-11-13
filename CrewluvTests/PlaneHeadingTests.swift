//
//  PlaneHeadingTests.swift
//  CrewluvTests
//
//  Which way the trip map's plane points (moving map spec §7.2), ported from CrewLu's PlaneHeading tests.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class PlaneHeadingTests: XCTestCase {

    func test_aimFractions_midLeg_aimsJustAheadOfThePlane() {
        let aim = PlaneHeading.aimFractions(at: 0.3, lookAhead: 0.01)
        XCTAssertEqual(aim.from, 0.3, accuracy: 1e-12)
        XCTAssertEqual(aim.to, 0.31, accuracy: 1e-12)
    }

    func test_aimFractions_nearTheEnd_aimsAlongTheLastStretch() {
        let aim = PlaneHeading.aimFractions(at: 0.998, lookAhead: 0.005)
        XCTAssertEqual(aim.from, 0.995, accuracy: 1e-12)
        XCTAssertEqual(aim.to, 1, accuracy: 1e-12)
    }

    func test_aimFractions_beforeTheStart_countsAsTheStart() {
        let aim = PlaneHeading.aimFractions(at: -0.2, lookAhead: 0.005)
        XCTAssertEqual(aim.from, 0, accuracy: 1e-12)
        XCTAssertEqual(aim.to, 0.005, accuracy: 1e-12)
    }

    func test_shortestTurn_acrossDueWest_goesTheShortWayRound() {
        let degree = Double.pi / 180
        XCTAssertEqual(PlaneHeading.shortestTurn(from: 170 * degree, to: -170 * degree), 20 * degree, accuracy: 1e-9)
        XCTAssertEqual(PlaneHeading.shortestTurn(from: -170 * degree, to: 170 * degree), -20 * degree, accuracy: 1e-9)
    }

    func test_shortestTurn_anyPair_isNeverMoreThanHalfATurn() {
        for from in stride(from: -10.0, through: 10.0, by: 0.7) {
            for to in stride(from: -10.0, through: 10.0, by: 0.9) {
                XCTAssertLessThanOrEqual(abs(PlaneHeading.shortestTurn(from: from, to: to)), .pi + 1e-12)
            }
        }
    }

    func test_continuing_pastDueWest_neverSpinsTheLongWay() {
        let next = PlaneHeading.continuing(3.0, toward: -3.0)
        XCTAssertLessThanOrEqual(abs(next - 3.0), .pi)
        XCTAssertEqual(cos(next), cos(-3.0), accuracy: 1e-12)
        XCTAssertEqual(sin(next), sin(-3.0), accuracy: 1e-12)
    }

    func test_flatMapAngle_eastNorthSouth_pointRightUpDown() throws {
        let origin = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let east = try XCTUnwrap(PlaneHeading.flatMapAngle(from: origin, to: CLLocationCoordinate2D(latitude: 0, longitude: 10)))
        let north = try XCTUnwrap(PlaneHeading.flatMapAngle(from: origin, to: CLLocationCoordinate2D(latitude: 10, longitude: 0)))
        let south = try XCTUnwrap(PlaneHeading.flatMapAngle(from: origin, to: CLLocationCoordinate2D(latitude: -10, longitude: 0)))
        XCTAssertEqual(east, 0, accuracy: 1e-12)
        XCTAssertEqual(north, -.pi / 2, accuracy: 1e-12)
        XCTAssertEqual(south, .pi / 2, accuracy: 1e-12)
    }

    func test_flatMapAngle_acrossTheDateLine_matchesTheSameLegElsewhere() throws {
        let acrossLine = try XCTUnwrap(PlaneHeading.flatMapAngle(from: CLLocationCoordinate2D(latitude: 50, longitude: 179),
                                                                 to: CLLocationCoordinate2D(latitude: 51, longitude: -179)))
        let elsewhere = try XCTUnwrap(PlaneHeading.flatMapAngle(from: CLLocationCoordinate2D(latitude: 50, longitude: -1),
                                                                to: CLLocationCoordinate2D(latitude: 51, longitude: 1)))
        XCTAssertEqual(acrossLine, elsewhere, accuracy: 1e-12)
    }

    func test_flatMapAngle_samePlace_givesNoAnswer() {
        let place = CLLocationCoordinate2D(latitude: 38, longitude: -85)
        XCTAssertNil(PlaneHeading.flatMapAngle(from: place, to: place))
    }

    func test_flatMapAngle_atAPole_isStillANumber() throws {
        let angle = try XCTUnwrap(PlaneHeading.flatMapAngle(from: CLLocationCoordinate2D(latitude: 90, longitude: 0),
                                                            to: CLLocationCoordinate2D(latitude: 89, longitude: 10)))
        XCTAssertTrue(angle.isFinite)
    }
}
