//
//  LiveMarkerTests.swift
//  CrewluvTests
//
//  The trip map's markers with a real plane (Stage 3 spec §5.4): the real plane and its ghost, by names that stay
//  the same while each is on the map.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LiveMarkerTests: XCTestCase {

    /// The map the status screen would make of a shared case's flight at one of its moments: the model's flights,
    /// its legs at their real times, and the map from both.
    private func map(of name: String, at time: String) throws -> (map: TripMap, moment: TripMapFixtures.LiveCases.Flight.Moment) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let moment = try cases.moment(time, of: flightCase)
        let after = cases.wait("w2", .layover, at: flightCase.to, from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(86_400))
        let legs = [cases.tripLeg(flightCase), after]
        let flights = LiveLegs.flights(for: legs, legacyDelayMinutes: nil, answered: cases.live(flightCase).map { ["f1": $0] } ?? [:],
                                       clockOffset: 0, coordinate: cases.coordinateOrNil)
        let replaced = LiveLegs.replacingTimes(in: legs, with: flights, at: moment.at)
        let map = try XCTUnwrap(TripMap.make(tripLegs: replaced, isNextTrip: false, homeAirportCode: "SDF", legacyDelayMinutes: nil,
                                             flights: flights, at: moment.at, coordinate: cases.coordinateOrNil))
        return (map, moment)
    }

    func test_placements_withARealPlane_areItAndItsGhost_andNoSchedulesPlane() throws {
        let (map, moment) = try map(of: "ahead, in the air", at: "13T12:41:50")
        let drawing = TripMapDrawing(tripMap: map, at: moment.at)
        let placements = TripMapMarker.placements(for: drawing, palette: .onDarkMap)
        XCTAssertEqual(Set(placements.keys), ["airport-SDF", "airport-PHL", "real-plane", "ghost"])
        let realPlane = try XCTUnwrap(drawing.realPlane)
        let ghost = try XCTUnwrap(drawing.ghost)
        XCTAssertEqual(placements["real-plane"]?.marker, .realPlane(angle: realPlane.angle, isEstimated: false))
        XCTAssertEqual(placements["ghost"]?.marker, .ghost(angle: ghost.angle))
        let plane = try XCTUnwrap(moment.plane)
        XCTAssertEqual(placements["real-plane"]?.coordinate.latitude ?? 0, plane[0], accuracy: 0.0001)
        XCTAssertEqual(placements["real-plane"]?.coordinate.longitude ?? 0, plane[1], accuracy: 0.0001)
        XCTAssertNil(drawing.pilot, "the plane shows where they are")
    }

    func test_placements_anEstimatedPlane_isMarkedAsOne() throws {
        let (map, moment) = try map(of: "ahead, in the air", at: "13T12:45:00")
        let placements = TripMapMarker.placements(for: TripMapDrawing(tripMap: map, at: moment.at), palette: .onDarkMap)
        guard case .realPlane(_, isEstimated: true)? = placements["real-plane"]?.marker else {
            return XCTFail("the plane hasn't been seen for over three minutes")
        }
    }

    func test_placements_inAReplay_areTheRealPlaneAlone() throws {
        let (map, moment) = try map(of: "ahead, in the air", at: "13T12:41:50")
        let earlier = moment.at.addingTimeInterval(-600)
        let placements = TripMapMarker.placements(for: TripMapDrawing(tripMap: map, at: earlier, isReplay: true), palette: .onDarkMap)
        XCTAssertEqual(Set(placements.keys), ["airport-SDF", "airport-PHL", "real-plane"])
    }

    func test_placements_legsThatAreOneFlight_areOneRealPlane_andNoSchedulesPlane() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let legs = [cases.tripLeg(flightCase, id: "twin-a"), cases.tripLeg(flightCase, id: "twin-b")]
        let flights = LiveLegs.flights(for: legs, legacyDelayMinutes: nil, answered: cases.live(flightCase).map { ["twin-a": $0] } ?? [:],
                                       clockOffset: 0, coordinate: cases.coordinateOrNil)
        let replaced = LiveLegs.replacingTimes(in: legs, with: flights, at: moment.at)
        let map = try XCTUnwrap(TripMap.make(tripLegs: replaced, isNextTrip: false, homeAirportCode: "SDF", legacyDelayMinutes: nil,
                                             flights: flights, at: moment.at, coordinate: cases.coordinateOrNil))
        let drawing = TripMapDrawing(tripMap: map, at: moment.at)
        XCTAssertNil(drawing.plane, "no leg of the flight is left on the schedule beside the real plane")
        XCTAssertNotNil(drawing.realPlane)
        let placements = TripMapMarker.placements(for: drawing, palette: .onDarkMap)
        XCTAssertEqual(Set(placements.keys), ["airport-SDF", "airport-PHL", "real-plane", "ghost"])
    }

    func test_markers_thePlanesAreOneSize() {
        XCTAssertEqual(TripMapMarker.realPlane(angle: 1, isEstimated: false).sizeKey, TripMapMarker.plane(angle: 0).sizeKey)
        XCTAssertEqual(TripMapMarker.ghost(angle: 1).sizeKey, TripMapMarker.plane(angle: 0).sizeKey)
    }
}
