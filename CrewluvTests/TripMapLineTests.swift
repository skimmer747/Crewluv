//
//  TripMapLineTests.swift
//  CrewluvTests
//
//  Route lines as the trip map's own drawing takes them (moving map spec §7.1, §10): drives straight, flights along
//  their great circle in short stretches, and in one piece across the date line.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class TripMapLineTests: XCTestCase {

    private func airport(_ code: String) throws -> CLLocationCoordinate2D {
        try XCTUnwrap(TripMapTestLegs.coordinate(code))
    }

    private func degreesOfArc(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        GreatCircle.distance(from: start, to: end) / GreatCircle.earthRadius * 180 / .pi
    }

    func test_init_drive_isItsTwoEndsDrawnStraight() throws {
        let lex = try airport("LEX")
        let sdf = try airport("SDF")
        let line = TripMapLine(segment: RouteSegment(id: "d1-drive", coordinates: [lex, sdf], style: .drive))
        XCTAssertEqual(line.points, [MapProjection.point(for: lex), MapProjection.point(for: sdf)])
        XCTAssertEqual(line.style, .drive)
    }

    func test_init_flight_followsItsGreatCircleInStretchesOfADegreeAtMost() throws {
        let sdf = try airport("SDF")
        let cgn = try airport("CGN")
        let line = TripMapLine(segment: RouteSegment(id: "f1-upcoming", coordinates: [sdf, cgn], style: .upcoming))
        XCTAssertEqual(line.points.first, MapProjection.point(for: sdf))
        XCTAssertEqual(line.points.last, MapProjection.point(for: cgn))
        // Every point is on the great circle: going through it adds nothing to the distance.
        let total = GreatCircle.distance(from: sdf, to: cgn)
        for point in line.points {
            let place = MapProjection.coordinate(for: point)
            XCTAssertEqual(GreatCircle.distance(from: sdf, to: place) + GreatCircle.distance(from: place, to: cgn), total,
                           accuracy: 1, "\(place) is off the great circle")
        }
        for (a, b) in zip(line.points, line.points.dropFirst()) {
            XCTAssertLessThanOrEqual(degreesOfArc(from: MapProjection.coordinate(for: a), to: MapProjection.coordinate(for: b)),
                                     TripMapLine.arcStep + 1e-9)
        }
    }

    func test_init_anchorageToTokyo_runsOnPastTheDateLineInOnePiece() throws {
        let anc = try airport("ANC")
        let nrt = try airport("NRT")
        let line = TripMapLine(segment: RouteSegment(id: "f1-upcoming", coordinates: [anc, nrt], style: .upcoming))
        for (a, b) in zip(line.points, line.points.dropFirst()) {
            XCTAssertLessThan(abs(b.x - a.x), 0.5, "a jump back across the map")
        }
        // West over the date line, so Tokyo is laid out one world west of where it is.
        XCTAssertEqual(line.points.last?.x ?? 0, MapProjection.point(for: nrt).x - 1, accuracy: 1e-12)
    }

    func test_init_legSplitAtThePlane_joinsWhereThePlaneIs() throws {
        let now = TripMapTestLegs.tripStart.addingTimeInterval(4 * 3600)
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: now))
        let drawing = TripMapDrawing(tripMap: map, at: now)
        let flying = try XCTUnwrap(drawing.segments.first { $0.id == "f1-flying" })
        let upcoming = try XCTUnwrap(drawing.segments.first { $0.id == "f1-upcoming" })
        let flown = TripMapLine(segment: flying)
        let ahead = TripMapLine(segment: upcoming)
        XCTAssertEqual(flown.points.last, ahead.points.first)
        XCTAssertEqual(flown.style, .flying)
        XCTAssertEqual(ahead.style, .upcoming)
    }

    func test_equality_sameSegment_givesTheSameLine() throws {
        let sdf = try airport("SDF")
        let cgn = try airport("CGN")
        let segment = RouteSegment(id: "f1-flown", coordinates: [sdf, cgn], style: .flown)
        let other = RouteSegment(id: "f1-upcoming", coordinates: [sdf, cgn], style: .upcoming)
        XCTAssertEqual(TripMapLine(segment: segment), TripMapLine(segment: segment))
        XCTAssertNotEqual(TripMapLine(segment: segment), TripMapLine(segment: other))
    }
}
