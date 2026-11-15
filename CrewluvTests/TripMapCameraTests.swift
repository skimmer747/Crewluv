//
//  TripMapCameraTests.swift
//  CrewluvTests
//
//  The trip map's camera (moving map spec §6): each framing is a new request that takes the camera back from the
//  family, and what it frames is the leg in the air or the whole trip and home.
//

import XCTest
import MapKit
@testable import Crewluv

final class TripMapCameraTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { start.addingTimeInterval(value * 3600) }
    private let rect = MKMapRect(x: 1_000, y: 2_000, width: 3_000, height: 4_000)

    func test_init_newCamera_isNotTheFamilysAndHasNotBeenFramedAgain() {
        let camera = TripMapCamera(framing: rect)
        XCTAssertEqual(camera.rect?.minX, 1_000)
        XCTAssertEqual(camera.rect?.minY, 2_000)
        XCTAssertEqual(camera.rect?.width, 3_000)
        XCTAssertEqual(camera.rect?.height, 4_000)
        XCTAssertFalse(camera.isPositionedByUser)
        XCTAssertFalse(camera.isAnimated)
        XCTAssertEqual(camera.framingNumber, 0)
    }

    func test_frame_keepsTheMarkerItsGiven_andANewFramingReplacesIt() {
        let cologne = CLLocationCoordinate2D(latitude: 50.87, longitude: 7.14)
        var camera = TripMapCamera(framing: rect, keeping: cologne)
        XCTAssertEqual(camera.keptInView?.latitude, 50.87)
        camera.frame(rect, animated: false)
        XCTAssertNil(camera.keptInView, "in flight, or with no marker, nothing is kept")
    }

    func test_frame_afterTheFamilyMovedIt_takesTheCameraBackAsANewRequest() {
        var camera = TripMapCamera(framing: rect)
        camera.markPositionedByUser()
        camera.frame(rect, animated: true)
        XCTAssertFalse(camera.isPositionedByUser)
        XCTAssertTrue(camera.isAnimated)
        XCTAssertEqual(camera.framingNumber, 1, "the same rectangle again still moves the map")
    }

    func test_markPositionedByUser_keepsTheRequest() {
        var camera = TripMapCamera(framing: rect)
        camera.frame(nil, animated: false)
        camera.markPositionedByUser()
        XCTAssertTrue(camera.isPositionedByUser)
        XCTAssertEqual(camera.framingNumber, 1)
        XCTAssertNil(camera.rect)
    }

    func test_framingRect_inFlight_holdsTheLegAndNotTheRestOfTheTrip() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(4)))
        let framed = try XCTUnwrap(map.framingRect(focusingOn: map.currentLeg))
        let sdf = try XCTUnwrap(TripMapTestLegs.coordinate("SDF"))
        let cgn = try XCTUnwrap(TripMapTestLegs.coordinate("CGN"))
        let dxb = try XCTUnwrap(TripMapTestLegs.coordinate("DXB"))
        XCTAssertTrue(framed.contains(MKMapPoint(sdf)))
        XCTAssertTrue(framed.contains(MKMapPoint(cgn)))
        XCTAssertFalse(framed.contains(MKMapPoint(dxb)))
    }

    func test_framingRect_onTheGround_holdsTheWholeTripAndHome() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        let framed = try XCTUnwrap(map.framingRect(focusingOn: nil))
        for code in ["SDF", "CGN", "DXB"] {
            let coordinate = try XCTUnwrap(TripMapTestLegs.coordinate(code))
            XCTAssertTrue(framed.contains(MKMapPoint(coordinate)), code)
        }
    }
}
