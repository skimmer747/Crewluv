//
//  FlightPathTests.swift
//  CrewluvTests
//
//  The path a flight is drawn and measured along (Stage 3 spec §6.1), held to the shared cases in Fixtures/TripMap.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class FlightPathTests: XCTestCase {

    private let nauticalMile = TripMapFixtures.nauticalMile
    private let louisville = CLLocationCoordinate2D(latitude: 38.1744, longitude: -85.736)
    private let philadelphia = CLLocationCoordinate2D(latitude: 39.8719, longitude: -75.2411)
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func point(_ minutes: Double, _ latitude: Double, _ longitude: Double) -> LiveFlight.TrailPoint {
        LiveFlight.TrailPoint(time: start.addingTimeInterval(minutes * 60), latitude: latitude, longitude: longitude, altitudeFeet: 30_000)
    }

    private func flight(state: LiveFlight.State = .airborne, fix: LiveFlight.Fix? = nil, landedAt: Date? = nil,
                        trail: [LiveFlight.TrailPoint]) -> LiveFlight {
        LiveFlight(legID: "leg", callsign: "UPS1234", state: state, fix: fix, landedAt: landedAt, trail: trail)
    }

    private func fix(_ minutes: Double, _ latitude: Double, _ longitude: Double, isOnGround: Bool = false) -> LiveFlight.Fix {
        LiveFlight.Fix(latitude: latitude, longitude: longitude, altitudeFeet: isOnGround ? nil : 30_000, groundSpeedKnots: 430,
                       trackDegrees: 80, isOnGround: isOnGround, registration: nil, typeCode: nil,
                       seenAt: start.addingTimeInterval(minutes * 60))
    }

    func test_constants_matchTheSharedCases() throws {
        let constants = try TripMapFixtures.liveCases().constants
        XCTAssertEqual(FlightPath.unseenGap, constants.unseenGapMinutes * 60)
        XCTAssertEqual(FlightPath.firstPointRadius, constants.firstPointRadiusNm * nauticalMile)
    }

    func test_paths_everySharedCase_matches() throws {
        let cases = try TripMapFixtures.liveCases()
        XCTAssertFalse(cases.flights.isEmpty)
        for flightCase in cases.flights {
            let path = try cases.made(flightCase).path
            let expected = flightCase.path
            XCTAssertEqual(path.isReal, expected.isReal, flightCase.name)
            XCTAssertEqual(path.length / nauticalMile, expected.lengthNm, accuracy: 0.01, flightCase.name)
            XCTAssertEqual(path.flownLength / nauticalMile, expected.flownNm, accuracy: 0.01, flightCase.name)
            XCTAssertEqual(path.stretches.map(\.kind.rawValue), expected.stretchKinds, flightCase.name)
            func total(_ kind: FlightPath.Kind) -> Double {
                path.stretches.filter { $0.kind == kind }.map(\.length).reduce(0, +) / nauticalMile
            }
            XCTAssertEqual(total(.seen), expected.seenNm, accuracy: 0.01, flightCase.name)
            XCTAssertEqual(total(.unseen), expected.unseenNm, accuracy: 0.01, flightCase.name)
            XCTAssertEqual(total(.planned), expected.plannedNm, accuracy: 0.01, flightCase.name)
        }
    }

    func test_init_noFlight_isTheGreatCircle() {
        let path = FlightPath(from: louisville, to: philadelphia)
        XCTAssertFalse(path.isReal)
        XCTAssertEqual(path.stretches.map(\.kind), [.planned])
        XCTAssertEqual(path.length, GreatCircle.distance(from: louisville, to: philadelphia), accuracy: 1e-6)
        XCTAssertEqual(path.flownLength, 0)
        XCTAssertEqual(path.knots, [])
    }

    func test_init_stretchesFollowOneAnother() {
        let path = FlightPath(from: louisville, to: philadelphia,
                              flight: flight(trail: [point(0, 38.3, -85.4), point(2, 38.6, -85.0), point(4, 38.9, -84.6)]))
        XCTAssertEqual(path.stretches.count, 4)
        var distance = 0.0
        for stretch in path.stretches {
            XCTAssertEqual(stretch.startDistance, distance, accuracy: 1e-6)
            distance += stretch.length
        }
        XCTAssertEqual(path.length, distance, accuracy: 1e-6)
        XCTAssertEqual(path.knots.map(\.distance), path.stretches.dropLast().map { $0.startDistance + $0.length })
    }

    func test_init_aTrailOutOfOrder_isSortedByTime() {
        let inOrder = [point(0, 38.3, -85.4), point(2, 38.6, -85.0), point(4, 38.9, -84.6)]
        let sorted = FlightPath(from: louisville, to: philadelphia, flight: flight(trail: inOrder))
        let shuffled = FlightPath(from: louisville, to: philadelphia, flight: flight(trail: [inOrder[2], inOrder[0], inOrder[1]]))
        XCTAssertEqual(shuffled.knots, sorted.knots)
        XCTAssertEqual(shuffled.length, sorted.length, accuracy: 1e-6)
    }

    func test_init_aFixInTheAirNewerThanTheTrail_isTheLastPlaceSeen() {
        let trail = [point(0, 38.3, -85.4), point(2, 38.6, -85.0)]
        let path = FlightPath(from: louisville, to: philadelphia, flight: flight(fix: fix(2.5, 38.7, -84.9), trail: trail))
        XCTAssertEqual(path.knots.count, 3)
        XCTAssertEqual(path.knots.last?.time, start.addingTimeInterval(150))
        XCTAssertEqual(path.stretches.map(\.kind), [.seen, .seen, .seen, .planned])
    }

    func test_init_aFixNoNewerThanTheTrail_addsNothing() {
        let trail = [point(0, 38.3, -85.4), point(2, 38.6, -85.0)]
        let path = FlightPath(from: louisville, to: philadelphia, flight: flight(fix: fix(2, 38.6, -85.0), trail: trail))
        XCTAssertEqual(path.knots.count, 2)
    }

    func test_init_aFixOnTheGround_addsNothing() {
        let trail = [point(0, 38.3, -85.4), point(2, 38.6, -85.0)]
        let path = FlightPath(from: louisville, to: philadelphia,
                              flight: flight(state: .ground, fix: fix(30, 38.18, -85.73, isOnGround: true), trail: trail))
        XCTAssertEqual(path.knots.count, 2)
        XCTAssertEqual(path.stretches.last?.kind, .planned)
    }

    func test_init_inTheAirWithNoTrailYet_startsFromTheFix() {
        let path = FlightPath(from: louisville, to: philadelphia, flight: flight(fix: fix(1, 38.3, -85.4), trail: []))
        XCTAssertTrue(path.isReal)
        XCTAssertEqual(path.stretches.map(\.kind), [.seen, .planned])
    }

    func test_init_onTheGroundWithNoTrail_isTheGreatCircle() {
        let path = FlightPath(from: louisville, to: philadelphia,
                              flight: flight(state: .ground, fix: fix(1, 38.18, -85.73, isOnGround: true), trail: []))
        XCTAssertFalse(path.isReal)
    }

    func test_init_landed_endsAtTheArrivalAirport_withNothingPlanned() {
        let trail = [point(0, 38.3, -85.4), point(2, 38.6, -85.0)]
        let landed = flight(state: .landed, fix: fix(9, 39.87, -75.24, isOnGround: true), landedAt: start.addingTimeInterval(8 * 60), trail: trail)
        let path = FlightPath(from: louisville, to: philadelphia, flight: landed)
        XCTAssertTrue(path.hasLanded)
        XCTAssertEqual(path.stretches.map(\.kind), [.seen, .seen, .seen])
        XCTAssertEqual(path.flownLength, path.length)
        XCTAssertEqual(path.knots.last, FlightPath.Knot(time: start.addingTimeInterval(8 * 60), distance: path.length))
    }

    func test_init_landedLongAfterTheLastPoint_endsUnseen() {
        let trail = [point(0, 38.3, -85.4), point(2, 38.6, -85.0)]
        let landed = flight(state: .landed, fix: fix(40, 39.87, -75.24, isOnGround: true), landedAt: start.addingTimeInterval(13 * 60), trail: trail)
        XCTAssertEqual(FlightPath(from: louisville, to: philadelphia, flight: landed).stretches.map(\.kind), [.seen, .seen, .unseen])
    }

    func test_init_landedExactlyTenMinutesAfterTheLastPoint_endsSeen() {
        let trail = [point(0, 38.3, -85.4), point(2, 38.6, -85.0)]
        let landed = flight(state: .landed, fix: fix(13, 39.87, -75.24, isOnGround: true), landedAt: start.addingTimeInterval(12 * 60), trail: trail)
        XCTAssertEqual(FlightPath(from: louisville, to: philadelphia, flight: landed).stretches.map(\.kind), [.seen, .seen, .seen])
    }

    func test_init_twoPointsOfOneTime_keepTheOrderTheyCameIn() {
        let first = point(2, 38.6, -85.0)
        let second = point(2, 38.7, -84.9)
        let path = FlightPath(from: louisville, to: philadelphia, flight: flight(trail: [point(4, 38.9, -84.6), first, second, point(0, 38.3, -85.4)]))
        XCTAssertEqual(path.knots.count, 4)
        XCTAssertEqual(path.knots[1].time, path.knots[2].time)
        let earlier = path.point(atDistance: path.knots[1].distance)
        let later = path.point(atDistance: path.knots[2].distance)
        XCTAssertEqual(earlier.latitude, 38.6, accuracy: 1e-6)
        XCTAssertEqual(later.latitude, 38.7, accuracy: 1e-6)
    }

    func test_init_pointsExactlyTenMinutesApart_areSeen() {
        let path = FlightPath(from: louisville, to: philadelphia, flight: flight(trail: [point(0, 38.3, -85.4), point(10, 39.0, -83.0)]))
        XCTAssertEqual(path.stretches.map(\.kind), [.seen, .seen, .planned])
    }

    func test_point_atEachEndAndBeyond_isAnAirport() {
        let path = FlightPath(from: louisville, to: philadelphia, flight: flight(trail: [point(0, 38.3, -85.4), point(2, 38.6, -85.0)]))
        for (distance, airport) in [(-10.0, louisville), (0, louisville), (path.length, philadelphia), (path.length + 10, philadelphia)] {
            let place = path.point(atDistance: distance)
            XCTAssertEqual(place.latitude, airport.latitude, accuracy: 1e-9)
            XCTAssertEqual(place.longitude, airport.longitude, accuracy: 1e-9)
        }
    }

    func test_point_atAKnot_isThePlaceSeen() {
        let path = FlightPath(from: louisville, to: philadelphia, flight: flight(trail: [point(0, 38.3, -85.4), point(2, 38.6, -85.0)]))
        let place = path.point(atDistance: path.knots[1].distance)
        XCTAssertEqual(place.latitude, 38.6, accuracy: 1e-6)
        XCTAssertEqual(place.longitude, -85.0, accuracy: 1e-6)
    }
}
