//
//  TripMapMarkerTests.swift
//  CrewluvTests
//
//  Which markers the trip map shows at an instant, by names that stay the same while each is on the map (moving map
//  spec §5.1, §7.2).
//

import XCTest
import CoreLocation
@testable import Crewluv

final class TripMapMarkerTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { start.addingTimeInterval(value * 3600) }

    func test_placements_inFlight_areTheAirportsAndThePlane() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(4)))
        let drawing = TripMapDrawing(tripMap: map, at: hours(4))
        let placements = TripMapMarker.placements(for: drawing, palette: .onDarkMap)
        XCTAssertEqual(Set(placements.keys), ["airport-SDF", "airport-CGN", "airport-DXB", "plane"])
        let plane = try XCTUnwrap(drawing.plane)
        XCTAssertEqual(placements["plane"]?.marker, .plane(angle: plane.angle))
        XCTAssertEqual(placements["plane"]?.coordinate.latitude ?? 0, plane.coordinate.latitude, accuracy: 1e-12)
    }

    func test_placements_onTheLayover_putTheHeartOnCologne() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        let placements = TripMapMarker.placements(for: TripMapDrawing(tripMap: map, at: hours(12)), palette: .onDarkMap)
        XCTAssertEqual(Set(placements.keys), ["airport-SDF", "airport-CGN", "airport-DXB", "heart"])
        let cgn = try XCTUnwrap(TripMapTestLegs.coordinate("CGN"))
        XCTAssertEqual(placements["heart"]?.marker, .heart)
        XCTAssertEqual(placements["heart"]?.coordinate.latitude ?? 0, cgn.latitude, accuracy: 1e-12)
    }

    func test_placements_drive_nameTheCarByItsDrive() throws {
        let legs = [TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(0), hours: 2)]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(-1)))
        let placements = TripMapMarker.placements(for: TripMapDrawing(tripMap: map, at: hours(-1)), palette: .onDarkMap)
        XCTAssertEqual(placements["d1-car"]?.marker, .car)
    }

    func test_placements_airport_carriesTheMapsPalette() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        let placements = TripMapMarker.placements(for: TripMapDrawing(tripMap: map, at: hours(12)), palette: .onLightMap)
        XCTAssertEqual(placements["airport-CGN"]?.marker, .airport(code: "CGN", palette: .onLightMap))
        XCTAssertNotEqual(placements["airport-CGN"]?.marker, .airport(code: "CGN", palette: .onDarkMap))
    }
}
