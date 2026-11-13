//
//  MapFitTests.swift
//  CrewluvTests
//
//  The trip map camera's rectangle (moving map spec §6, §12): the short way round, and never empty.
//

import XCTest
import MapKit
@testable import Crewluv

final class MapFitTests: XCTestCase {

    private let sdf = CLLocationCoordinate2D(latitude: 38.1744, longitude: -85.7360)
    private let cgn = CLLocationCoordinate2D(latitude: 50.8659, longitude: 7.1427)
    private let anc = CLLocationCoordinate2D(latitude: 61.1743, longitude: -149.9963)
    private let nrt = CLLocationCoordinate2D(latitude: 35.7720, longitude: 140.3929)
    private let world = MKMapSize.world.width

    func test_rect_noCoordinates_isNil() {
        XCTAssertNil(MapFit.rect(enclosing: []))
    }

    func test_rect_louisvilleAndCologne_holdsBoth() throws {
        let rect = try XCTUnwrap(MapFit.rect(enclosing: [sdf, cgn]))
        XCTAssertTrue(rect.contains(MKMapPoint(sdf)))
        XCTAssertTrue(rect.contains(MKMapPoint(cgn)))
        XCTAssertFalse(rect.spans180thMeridian)
    }

    func test_rect_anchorageToTokyo_framesThePacificNotTheWorld() throws {
        let rect = try XCTUnwrap(MapFit.rect(enclosing: [anc, nrt], padding: 0.1))
        XCTAssertTrue(rect.spans180thMeridian)
        XCTAssertLessThan(rect.size.width, world / 4)
        XCTAssertTrue(rect.contains(MKMapPoint(nrt)))
        let anchorageOnTheNextWorld = MKMapPoint(x: MKMapPoint(anc).x + world, y: MKMapPoint(anc).y)
        XCTAssertTrue(rect.contains(anchorageOnTheNextWorld))
    }

    func test_rect_onePlace_isTheMinimumSize() throws {
        let rect = try XCTUnwrap(MapFit.rect(enclosing: [sdf], minimumSide: 500_000))
        XCTAssertEqual(rect.size.width, 500_000, accuracy: 0.001)
        XCTAssertEqual(rect.size.height, 500_000, accuracy: 0.001)
        XCTAssertEqual(rect.midX, MKMapPoint(sdf).x, accuracy: 0.001)
    }

    func test_rect_padding_growsEachSide() throws {
        let tight = try XCTUnwrap(MapFit.rect(enclosing: [sdf, cgn], padding: 0))
        let padded = try XCTUnwrap(MapFit.rect(enclosing: [sdf, cgn], padding: 0.25))
        XCTAssertEqual(padded.size.width, tight.size.width * 1.5, accuracy: 1)
        XCTAssertEqual(padded.midX, tight.midX, accuracy: 1)
    }

    func test_rect_nearTheMapsLeftEdge_neverStartsBelowZero() throws {
        let nearDateLineWest = CLLocationCoordinate2D(latitude: 20, longitude: -179.9)
        let rect = try XCTUnwrap(MapFit.rect(enclosing: [nearDateLineWest]))
        XCTAssertGreaterThanOrEqual(rect.minX, 0)
    }
}
