//
//  TripMapMarkerTests.swift
//  CrewluvTests
//
//  Which markers the trip map shows at an instant, by names that stay the same while each is on the map (moving map
//  spec §5.1, §7.2), with the pilot's marker showing what they're doing (activity markers design §2).
//

import XCTest
import CoreLocation
@testable import Crewluv

final class TripMapMarkerTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { start.addingTimeInterval(value * 3600) }

    private func markers(_ map: TripMap, at hour: Double, palette: TripMapPalette = .onDarkMap) -> [String: TripMapMarker.Placement] {
        TripMapMarker.placements(for: TripMapDrawing(tripMap: map, at: hours(hour)), palette: palette)
    }

    func test_placements_inFlight_areTheAirportsAndThePlane() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(4)))
        let drawing = TripMapDrawing(tripMap: map, at: hours(4))
        let placements = TripMapMarker.placements(for: drawing, palette: .onDarkMap)
        XCTAssertEqual(Set(placements.keys), ["airport-SDF", "airport-CGN", "airport-DXB", "plane"])
        let plane = try XCTUnwrap(drawing.plane)
        XCTAssertEqual(placements["plane"]?.marker, .plane(angle: plane.angle))
        XCTAssertEqual(placements["plane"]?.coordinate.latitude ?? 0, plane.coordinate.latitude, accuracy: 1e-12)
    }

    func test_placements_onTheLayover_putTheLayoverMarkerOnCologne() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        let placements = markers(map, at: 12)
        XCTAssertEqual(Set(placements.keys), ["airport-SDF", "airport-CGN", "airport-DXB", "pilot"])
        let cgn = try XCTUnwrap(TripMapTestLegs.coordinate("CGN"))
        XCTAssertEqual(placements["pilot"]?.marker, .pilot(.layover))
        XCTAssertEqual(placements["pilot"]?.coordinate.latitude ?? 0, cgn.latitude, accuracy: 1e-12)
    }

    func test_placements_beforeANextTrip_putTheHomeMarkerAtHome() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), isNextTrip: true, at: hours(-48)))
        let sdf = try XCTUnwrap(TripMapTestLegs.coordinate("SDF"))
        let pilot = try XCTUnwrap(markers(map, at: -48)["pilot"])
        XCTAssertEqual(pilot.marker, .pilot(.home))
        XCTAssertEqual(pilot.coordinate.latitude, sdf.latitude, accuracy: 1e-12)
    }

    func test_placements_pilot_keepsItsNameAsWhatTheyreDoingChanges() throws {
        // On the layover in Cologne, then home after the trip: one marker by one name, so MapKit keeps its annotation
        // and the coordinator refreshes its view.
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        XCTAssertEqual(markers(map, at: 12)["pilot"]?.marker, .pilot(.layover))
        XCTAssertEqual(markers(map, at: 80)["pilot"]?.marker, .pilot(.home))
    }

    func test_placements_drive_nameTheCarByItsDrive() throws {
        let legs = [TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(0), hours: 2)]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(-1)))
        XCTAssertEqual(markers(map, at: 1)["d1-car"]?.marker, .car)
        XCTAssertNil(markers(map, at: -1)["d1-car"], "no car before the drive")
        XCTAssertEqual(markers(map, at: -1)["airport-LEX"]?.marker,
                       .airport(code: "LEX", palette: .onDarkMap, isDriveOnly: true))
    }

    func test_placements_airport_carriesTheMapsPalette() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        let placements = markers(map, at: 12, palette: .onLightMap)
        XCTAssertEqual(placements["airport-CGN"]?.marker, .airport(code: "CGN", palette: .onLightMap, isDriveOnly: false))
        XCTAssertNotEqual(placements["airport-CGN"]?.marker, .airport(code: "CGN", palette: .onDarkMap, isDriveOnly: false))
    }
}
