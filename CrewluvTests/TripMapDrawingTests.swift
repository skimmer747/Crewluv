//
//  TripMapDrawingTests.swift
//  CrewluvTests
//
//  What the trip map draws at an instant (moving map spec §7.1, §7.2).
//

import XCTest
import CoreLocation
@testable import Crewluv

final class TripMapDrawingTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { start.addingTimeInterval(value * 3600) }
    private func styles(_ drawing: TripMapDrawing) -> [String: RouteSegment.Style] {
        Dictionary(uniqueKeysWithValues: drawing.segments.map { ($0.id, $0.style) })
    }

    func test_init_midFlight_splitsTheLegAtThePlane() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(4)))
        let drawing = TripMapDrawing(tripMap: map, at: hours(4))
        XCTAssertEqual(styles(drawing), ["f1-flying": .flying, "f1-upcoming": .upcoming, "f2-upcoming": .upcoming, "f3-upcoming": .upcoming])
        let plane = try XCTUnwrap(drawing.plane)
        let expected = try XCTUnwrap(map.currentLeg).position(at: hours(4))
        XCTAssertEqual(plane.coordinate.latitude, expected.latitude, accuracy: 1e-9)
        XCTAssertNil(drawing.pilot, "the plane shows where they are")
    }

    func test_init_onTheLayover_greysTheFlownLegAndPutsThePilotOnALayoverInCologne() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        let drawing = TripMapDrawing(tripMap: map, at: hours(12))
        XCTAssertEqual(styles(drawing), ["f1-flown": .flown, "f2-upcoming": .upcoming, "f3-upcoming": .upcoming])
        XCTAssertNil(drawing.plane)
        XCTAssertEqual(drawing.pilot?.place.code, "CGN")
        XCTAssertEqual(drawing.pilot?.kind, .layover)
    }

    func test_init_taxiingOut_showsThePlaneAtTheGateWithTheWholeLegAhead() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(0.1)))
        let drawing = TripMapDrawing(tripMap: map, at: hours(0.1))
        XCTAssertEqual(styles(drawing)["f1-upcoming"], .upcoming)
        XCTAssertNil(styles(drawing)["f1-flying"])
        let plane = try XCTUnwrap(drawing.plane)
        XCTAssertEqual(plane.coordinate.latitude, TripMapTestLegs.airports["SDF"]!.latitude, accuracy: 1e-9)
    }

    func test_init_airports_eachOnce() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        XCTAssertEqual(TripMapDrawing(tripMap: map, at: hours(12)).airports.map(\.code), ["SDF", "CGN", "DXB"])
    }

    func test_init_drive_isDottedWithACar() throws {
        let legs = [TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(0), hours: 2)]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(-1)))
        let drawing = TripMapDrawing(tripMap: map, at: hours(-1))
        XCTAssertEqual(styles(drawing), ["d1-drive": .drive])
        XCTAssertEqual(drawing.segments.first?.isGeodesic, false)
        let car = try XCTUnwrap(drawing.cars.first)
        let middle = try XCTUnwrap(map.legs.first).position(atFraction: 0.5)
        XCTAssertEqual(car.coordinate.longitude, middle.longitude, accuracy: 1e-9, "parked halfway when not driving")
    }

    func test_init_whileDriving_hasNoGroundMarker() throws {
        let legs = [TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(0), hours: 2)]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(1)))
        XCTAssertNil(TripMapDrawing(tripMap: map, at: hours(1)).pilot, "the car shows where they are")
    }
}
