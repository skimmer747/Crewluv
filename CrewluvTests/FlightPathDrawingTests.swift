//
//  FlightPathDrawingTests.swift
//  CrewluvTests
//
//  A flight's path as the trip map draws and frames it (Stage 3 spec §6.2), on the shared cases' paths.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class FlightPathDrawingTests: XCTestCase {

    private let louisville = TripMapTestLegs.airports["SDF"]!
    private let cologne = TripMapTestLegs.airports["CGN"]!
    private var greatCircle: FlightPath { FlightPath(from: louisville, to: cologne) }

    private func assertSame(_ place: CLLocationCoordinate2D?, _ expected: CLLocationCoordinate2D?, _ name: String = "",
                            file: StaticString = #filePath, line: UInt = #line) {
        guard let place, let expected else {
            XCTFail("a place is missing: \(name)", file: file, line: line)
            return
        }
        XCTAssertEqual(place.latitude, expected.latitude, accuracy: 1e-9, name, file: file, line: line)
        XCTAssertEqual(place.longitude, expected.longitude, accuracy: 1e-9, name, file: file, line: line)
    }

    /// The kinds of a path's stretches with neighbours of one kind counted once.
    private func kindsInOrder(_ path: FlightPath) -> [FlightPath.Kind] {
        path.stretches.map(\.kind).reduce(into: []) { kinds, kind in
            if kinds.last != kind { kinds.append(kind) }
        }
    }

    // MARK: - The places it passes

    func test_coordinates_aGreatCircle_isItsTwoAirports() {
        let places = greatCircle.coordinates
        XCTAssertEqual(places.count, 2)
        assertSame(places.first, louisville)
        assertSame(places.last, cologne)
    }

    func test_coordinates_aRealPath_passesEveryPlaceThePlaneWasSeen() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let path = try cases.made(flightCase).path
        let places = path.coordinates
        XCTAssertEqual(places.count, path.stretches.count + 1)
        assertSame(places.first, path.origin)
        assertSame(places.last, path.destination)
        for (place, stretch) in zip(places, path.stretches) {
            assertSame(place, stretch.start)
        }
    }

    // MARK: - Runs

    func test_runs_ofTheWholePath_areItsKindsInOrder_eachBeginningWhereTheLastEnded() throws {
        let cases = try TripMapFixtures.liveCases()
        for flightCase in cases.flights {
            let path = try cases.made(flightCase).path
            let runs = path.runs(from: 0, to: path.length)
            XCTAssertEqual(runs.map(\.kind), kindsInOrder(path), flightCase.name)
            assertSame(runs.first?.coordinates.first, path.origin, flightCase.name)
            assertSame(runs.last?.coordinates.last, path.destination, flightCase.name)
            for (earlier, later) in zip(runs, runs.dropFirst()) {
                assertSame(later.coordinates.first, earlier.coordinates.last, flightCase.name)
            }
            XCTAssertEqual(runs.reduce(0) { $0 + $1.coordinates.count - 1 }, path.stretches.count, flightCase.name)
        }
    }

    func test_runs_cutInsideAStretch_endAtThePlaceThatFarAlong() throws {
        let cases = try TripMapFixtures.liveCases()
        let path = try cases.made(cases.flight(named: "behind, with a late first point and an unseen ocean")).path
        let cut = path.flownLength * 0.4
        let behind = path.runs(from: 0, to: cut)
        let ahead = path.runs(from: cut, to: path.length)
        assertSame(behind.last?.coordinates.last, path.point(atDistance: cut))
        assertSame(ahead.first?.coordinates.first, path.point(atDistance: cut))
        XCTAssertEqual(behind.first?.kind, .unseen, "the first place it was seen was far from the airport")
        XCTAssertEqual(ahead.last?.kind, .planned)
        XCTAssertFalse(behind.contains { $0.kind == .planned }, "nothing behind the cut is the way ahead")
    }

    func test_runs_upToWhereThePlaneWasLastSeen_leaveOutTheWayAhead() throws {
        let cases = try TripMapFixtures.liveCases()
        let path = try cases.made(cases.flight(named: "ahead, in the air")).path
        XCTAssertEqual(path.runs(from: 0, to: path.flownLength).map(\.kind), [.seen])
        XCTAssertEqual(path.runs(from: path.flownLength, to: path.length).map(\.kind), [.planned])
        XCTAssertEqual(path.runs(from: path.flownLength, to: path.length).first?.coordinates.count, 2)
    }

    func test_runs_ofACutWithNoLength_orBackwards_areEmpty() {
        XCTAssertTrue(greatCircle.runs(from: 0, to: 0).isEmpty)
        XCTAssertTrue(greatCircle.runs(from: 500_000, to: 500_000).isEmpty)
        XCTAssertTrue(greatCircle.runs(from: 500_000, to: 100_000).isEmpty)
        XCTAssertTrue(greatCircle.runs(from: greatCircle.length, to: greatCircle.length * 2).isEmpty)
        XCTAssertTrue(greatCircle.coordinates(from: 0, to: 0).isEmpty)
    }

    func test_runs_ofAPathThatGoesNowhere_areEmpty() {
        let nowhere = FlightPath(from: louisville, to: louisville)
        XCTAssertTrue(nowhere.runs(from: 0, to: 1_000).isEmpty)
        XCTAssertTrue(nowhere.coordinates(from: 0, to: 1_000).isEmpty)
        XCTAssertEqual(nowhere.coordinates.count, 2)
    }

    func test_runs_ofALongRealPath_keepEveryPlaceInOrder() throws {
        // 600 places seen two minutes apart: one run of 601 joins, built without copying it 600 times over.
        let cases = try TripMapFixtures.liveCases()
        let start = try cases.flight(named: "ahead, in the air").departure
        let trail = (1...600).map { minute in
            LiveFlight.TrailPoint(time: start.addingTimeInterval(Double(minute) * 120), latitude: 38.2 + Double(minute) * 0.02,
                                  longitude: -85.7 + Double(minute) * 0.15, altitudeFeet: 38_000)
        }
        let live = LiveFlight(legID: "f1", callsign: "UPS207", state: .airborne, fix: nil, landedAt: nil, trail: trail)
        let path = FlightPath(from: louisville, to: cologne, flight: live)
        let flown = path.runs(from: 0, to: path.flownLength)
        XCTAssertEqual(flown.map(\.kind), [.seen])
        XCTAssertEqual(flown.first?.coordinates.count, 601)
        for (place, point) in zip(flown[0].coordinates.dropFirst(), trail) {
            XCTAssertEqual(place.latitude, point.latitude, accuracy: 1e-9)
            XCTAssertEqual(place.longitude, point.longitude, accuracy: 1e-9)
        }
    }

    func test_coordinatesFromTo_areTheRunsJoined_withoutTheirSharedPlacesTwice() throws {
        let cases = try TripMapFixtures.liveCases()
        let path = try cases.made(cases.flight(named: "behind, with a late first point and an unseen ocean")).path
        let whole = path.coordinates(from: 0, to: path.length)
        XCTAssertEqual(whole.count, path.stretches.count + 1)
        for (place, expected) in zip(whole, path.coordinates) {
            assertSame(place, expected)
        }
    }

    // MARK: - Framing

    func test_framingCoordinates_aGreatCircle_areThe33PlacesOfBefore() {
        let places = greatCircle.framingCoordinates
        let before = GreatCircle.points(from: louisville, to: cologne, count: 33)
        XCTAssertEqual(places.count, 33)
        for (place, expected) in zip(places, before) {
            assertSame(place, expected)
        }
    }

    func test_framingCoordinates_aRealPath_holdEveryPlaceThePlaneWasSeen() throws {
        let cases = try TripMapFixtures.liveCases()
        let path = try cases.made(cases.flight(named: "off early and the long way round")).path
        let places = path.framingCoordinates
        for stretch in path.stretches {
            XCTAssertTrue(places.contains { abs($0.latitude - stretch.start.latitude) < 1e-9 && abs($0.longitude - stretch.start.longitude) < 1e-9 })
        }
        assertSame(places.first, path.origin)
        assertSame(places.last, path.destination)
    }

    func test_framingCoordinates_aPathThatGoesNowhere_isItsAirport() {
        let places = FlightPath(from: louisville, to: louisville).framingCoordinates
        XCTAssertEqual(places.count, 2)
        assertSame(places.first, louisville)
    }

    // MARK: - Which way a plane on it points

    func test_heading_alongAGreatCircle_isTheWayAhead() throws {
        let path = greatCircle
        let look = PlaneHeading.lookAhead * path.length
        let expected = try XCTUnwrap(PlaneHeading.flatMapAngle(from: path.point(atDistance: path.length / 2),
                                                               to: path.point(atDistance: path.length / 2 + look)))
        XCTAssertEqual(try XCTUnwrap(path.heading(atDistance: path.length / 2)), expected, accuracy: 1e-9)
    }

    func test_heading_atTheEnd_isAlongTheLastOfThePath() throws {
        let path = greatCircle
        let look = PlaneHeading.lookAhead * path.length
        let expected = try XCTUnwrap(PlaneHeading.flatMapAngle(from: path.point(atDistance: path.length - look), to: cologne))
        XCTAssertEqual(try XCTUnwrap(path.heading(atDistance: path.length)), expected, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(path.heading(atDistance: path.length * 2)), expected, accuracy: 1e-9)
    }

    func test_heading_beforeThePathsStart_isTheHeadingAtIt() throws {
        let path = greatCircle
        XCTAssertEqual(try XCTUnwrap(path.heading(atDistance: -5_000)), try XCTUnwrap(path.heading(atDistance: 0)), accuracy: 1e-12)
    }

    func test_heading_onARealPath_isAlongThePathFlown_notTowardsTheAirport() throws {
        let cases = try TripMapFixtures.liveCases()
        let path = try cases.made(cases.flight(named: "off early and the long way round")).path
        let along = path.flownLength / 2
        let look = PlaneHeading.lookAhead * path.length
        let expected = try XCTUnwrap(PlaneHeading.flatMapAngle(from: path.point(atDistance: along), to: path.point(atDistance: along + look)))
        let heading = try XCTUnwrap(path.heading(atDistance: along))
        XCTAssertEqual(heading, expected, accuracy: 1e-9)
        let straightThere = try XCTUnwrap(PlaneHeading.flatMapAngle(from: path.point(atDistance: along), to: path.destination))
        XCTAssertGreaterThan(abs(PlaneHeading.shortestTurn(from: heading, to: straightThere)), 0.05, "the long way round isn't the way straight there")
    }

    func test_heading_aPathThatGoesNowhere_isNil() {
        XCTAssertNil(FlightPath(from: louisville, to: louisville).heading(atDistance: 0))
    }
}
