//
//  GreatCircleTests.swift
//  CrewluvTests
//
//  Distances and points along the shortest path (moving map spec §7.1). Expected values were worked out
//  independently with the same sphere (radius 6,371,008.8 m).
//

import XCTest
import CoreLocation
@testable import Crewluv

final class GreatCircleTests: XCTestCase {

    private let jfk = CLLocationCoordinate2D(latitude: 40.6413, longitude: -73.7781)
    private let lhr = CLLocationCoordinate2D(latitude: 51.4700, longitude: -0.4543)
    private let anc = CLLocationCoordinate2D(latitude: 61.1743, longitude: -149.9963)
    private let nrt = CLLocationCoordinate2D(latitude: 35.7720, longitude: 140.3929)

    func test_distance_newYorkToLondon_isAbout5540Kilometers() {
        XCTAssertEqual(GreatCircle.distance(from: jfk, to: lhr) / 1000, 5540.02, accuracy: 0.05)
    }

    func test_distance_isTheSameBothWays() {
        XCTAssertEqual(GreatCircle.distance(from: jfk, to: lhr), GreatCircle.distance(from: lhr, to: jfk), accuracy: 0.001)
    }

    func test_distance_samePlace_isZero() {
        XCTAssertEqual(GreatCircle.distance(from: jfk, to: jfk), 0, accuracy: 0.000_001)
    }

    func test_point_atTheEnds_isTheAirports() {
        let start = GreatCircle.point(from: jfk, to: lhr, fraction: 0)
        let end = GreatCircle.point(from: jfk, to: lhr, fraction: 1)
        XCTAssertEqual(start.latitude, jfk.latitude, accuracy: 1e-9)
        XCTAssertEqual(start.longitude, jfk.longitude, accuracy: 1e-9)
        XCTAssertEqual(end.latitude, lhr.latitude, accuracy: 1e-9)
        XCTAssertEqual(end.longitude, lhr.longitude, accuracy: 1e-9)
    }

    func test_point_halfwayToLondon_curvesNorthOverTheAtlantic() {
        let middle = GreatCircle.point(from: jfk, to: lhr, fraction: 0.5)
        XCTAssertEqual(middle.latitude, 52.2167, accuracy: 0.001)
        XCTAssertEqual(middle.longitude, -41.3027, accuracy: 0.001)
    }

    func test_point_outsideTheLeg_isHeldAtTheEnds() {
        let before = GreatCircle.point(from: jfk, to: lhr, fraction: -0.5)
        let after = GreatCircle.point(from: jfk, to: lhr, fraction: 1.5)
        XCTAssertEqual(before.latitude, jfk.latitude, accuracy: 1e-9)
        XCTAssertEqual(after.longitude, lhr.longitude, accuracy: 1e-9)
    }

    func test_point_anchorageToTokyo_crossesTheDateLineTheShortWay() {
        let middle = GreatCircle.point(from: anc, to: nrt, fraction: 0.5)
        XCTAssertEqual(middle.latitude, 53.557, accuracy: 0.001)
        XCTAssertEqual(middle.longitude, 165.165, accuracy: 0.001)
    }

    func test_point_samePlace_isThatPlace() {
        let point = GreatCircle.point(from: jfk, to: jfk, fraction: 0.5)
        XCTAssertEqual(point.latitude, jfk.latitude, accuracy: 1e-9)
        XCTAssertEqual(point.longitude, jfk.longitude, accuracy: 1e-9)
    }

    func test_points_giveTheCountAsked_withBothEnds() {
        let points = GreatCircle.points(from: jfk, to: lhr, count: 33)
        XCTAssertEqual(points.count, 33)
        XCTAssertEqual(points[0].latitude, jfk.latitude, accuracy: 1e-9)
        XCTAssertEqual(points[32].longitude, lhr.longitude, accuracy: 1e-9)
    }

    func test_points_fewerThanTwo_giveTheTwoEnds() {
        XCTAssertEqual(GreatCircle.points(from: jfk, to: lhr, count: 1).count, 2)
    }
}
