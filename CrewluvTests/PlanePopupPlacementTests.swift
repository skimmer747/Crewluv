//
//  PlanePopupPlacementTests.swift
//  CrewluvTests
//
//  A plane's popup on the full-screen map (which plane design §3): which markers open one, and where it goes, just
//  above its plane, under it near the top, and slid in near a side.
//

import XCTest
import CoreGraphics
@testable import Crewluv

final class PlanePopupPlacementTests: XCTestCase {

    private let size = CGSize(width: 180, height: 60)
    private let map = CGRect(x: 0, y: 0, width: 400, height: 600)

    // MARK: - Which markers

    func test_planeKind_onlyThePlanesOpenAPopup() {
        XCTAssertEqual(TripMapMarker.realPlane(angle: 0, isEstimated: false).planeKind, .realPlane)
        XCTAssertEqual(TripMapMarker.realPlane(angle: 1, isEstimated: true).planeKind, .realPlane)
        XCTAssertEqual(TripMapMarker.ghost(angle: 0).planeKind, .ghost)
        XCTAssertEqual(TripMapMarker.plane(angle: 0).planeKind, .schedulePlane)
        XCTAssertNil(TripMapMarker.car.planeKind)
        XCTAssertNil(TripMapMarker.pilot(.layover).planeKind)
        XCTAssertNil(TripMapMarker.airport(code: "SDF", palette: .onDarkMap, isDriveOnly: false).planeKind)
    }

    // MARK: - Where it goes

    func test_frame_justAboveThePlane_centredOnIt() {
        // 18 points from the plane's centre to the popup's bottom edge.
        XCTAssertEqual(PlanePopupPlacement.frame(of: size, over: CGPoint(x: 200, y: 300), inside: map),
                       CGRect(x: 110, y: 222, width: 180, height: 60))
    }

    func test_frame_underThePlane_whereThereIsNoRoomAboveIt() {
        XCTAssertEqual(PlanePopupPlacement.frame(of: size, over: CGPoint(x: 200, y: 70), inside: map),
                       CGRect(x: 110, y: 88, width: 180, height: 60))
        // The map's margins keep it clear of the top bar, the banner and the key.
        let clear = CGRect(x: 0, y: 120, width: 400, height: 480)
        XCTAssertEqual(PlanePopupPlacement.frame(of: size, over: CGPoint(x: 200, y: 190), inside: clear).minY, 208)
        XCTAssertEqual(PlanePopupPlacement.frame(of: size, over: CGPoint(x: 200, y: 198), inside: clear).minY, 120)
    }

    func test_frame_slidesInNearASide() {
        XCTAssertEqual(PlanePopupPlacement.frame(of: size, over: CGPoint(x: 20, y: 300), inside: map).minX, 0)
        XCTAssertEqual(PlanePopupPlacement.frame(of: size, over: CGPoint(x: 390, y: 300), inside: map).maxX, 400)
        // Beside a side panel, the map's leading margin.
        let besidePanel = CGRect(x: 396, y: 0, width: 456, height: 393)
        XCTAssertEqual(PlanePopupPlacement.frame(of: size, over: CGPoint(x: 420, y: 300), inside: besidePanel).minX, 396)
    }

    func test_frame_widerThanTheMap_isCentredOnIt() {
        let narrow = CGRect(x: 10, y: 0, width: 150, height: 600)
        XCTAssertEqual(PlanePopupPlacement.frame(of: size, over: CGPoint(x: 30, y: 300), inside: narrow).midX, 85)
    }
}
