//
//  FlightRecordTests.swift
//  CrewluvTests
//
//  Where a flight was at any moment, and when it was any distance along (Stage 3 spec §7.2), held to the shared
//  cases in Fixtures/TripMap.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class FlightRecordTests: XCTestCase {

    private let nauticalMile = TripMapFixtures.nauticalMile

    func test_records_everySharedCase_matches() throws {
        let cases = try TripMapFixtures.liveCases()
        XCTAssertTrue(cases.flights.contains { $0.record != nil })
        var placesChecked = 0
        var timesChecked = 0
        for flightCase in cases.flights {
            let record = try cases.made(flightCase).record
            guard let expected = flightCase.record else {
                XCTAssertNil(record, flightCase.name)
                continue
            }
            let made = try XCTUnwrap(record, flightCase.name)
            XCTAssertEqual(made.takeoff == nil, expected.takeoff == nil, flightCase.name)
            if let takeoff = made.takeoff, let expectedTakeoff = expected.takeoff {
                XCTAssertEqual(takeoff.timeIntervalSince1970, expectedTakeoff.timeIntervalSince1970, accuracy: 0.05, flightCase.name)
            }
            XCTAssertEqual(made.touchdown.timeIntervalSince1970, expected.touchdown.timeIntervalSince1970, accuracy: 0.05, flightCase.name)
            for place in expected.places {
                let name = "\(flightCase.name) at \(place.at)"
                XCTAssertEqual(made.distance(at: place.at) / nauticalMile, place.alongNm, accuracy: 0.01, name)
                let position = made.position(at: place.at)
                XCTAssertEqual(position.latitude, place.point[0], accuracy: 0.0001, name)
                XCTAssertEqual(position.longitude, place.point[1], accuracy: 0.0001, name)
                placesChecked += 1
            }
            for time in expected.times {
                XCTAssertEqual(made.time(atDistance: time.alongNm * nauticalMile).timeIntervalSince1970, time.at.timeIntervalSince1970,
                               accuracy: 0.05, "\(flightCase.name) at \(time.alongNm) nm")
                timesChecked += 1
            }
        }
        XCTAssertGreaterThan(placesChecked, 0)
        XCTAssertGreaterThan(timesChecked, 0)
    }

    /// Two places seen at one time are a jump, and no moment is part way across it. Everywhere else, the record's two
    /// answers are each other's inverse.
    func test_time_isTheInverseOfDistance_whereverThePlaneDidntJump() throws {
        let cases = try TripMapFixtures.liveCases()
        for flightCase in cases.flights {
            guard let record = try cases.made(flightCase).record else { continue }
            let knots = record.path.knots
            let jumps = zip(knots, knots.dropFirst()).filter { $0.time == $1.time }.map { $0.distance...$1.distance }
            for share in stride(from: 0.01, through: 0.99, by: 0.07) {
                let distance = record.path.length * share
                guard !jumps.contains(where: { $0.contains(distance) }) else { continue }
                XCTAssertEqual(record.distance(at: record.time(atDistance: distance)), distance, accuracy: 0.5,
                               "\(flightCase.name) at \(share)")
            }
        }
    }

    func test_distance_neverGoesBackwards() throws {
        let cases = try TripMapFixtures.liveCases()
        for flightCase in cases.flights {
            guard let record = try cases.made(flightCase).record else { continue }
            var last = -1.0
            var date = flightCase.departure.addingTimeInterval(-3600)
            // To three hours past the schedule's arrival, or past the record's touchdown for a plane later than that.
            let end = max(flightCase.arrival.addingTimeInterval(3 * 3600), record.touchdown.addingTimeInterval(97))
            while date < end {
                let distance = record.distance(at: date)
                XCTAssertGreaterThanOrEqual(distance, last, "\(flightCase.name) at \(date)")
                last = distance
                date.addTimeInterval(97)
            }
            XCTAssertEqual(last, record.path.length, accuracy: 1e-6, flightCase.name)
        }
    }

    func test_flownPlan_everySharedCase_isThePlanFlownAlongThePath() throws {
        let cases = try TripMapFixtures.liveCases()
        var records = 0
        for flightCase in cases.flights {
            let made = try cases.made(flightCase)
            guard let record = made.record else { continue }
            XCTAssertEqual(record.flownPlan, made.plan.flown(along: made.path), flightCase.name)
            XCTAssertEqual(record.plan, made.plan, flightCase.name)
            records += 1
        }
        XCTAssertGreaterThan(records, 0)
    }

    func test_init_aPathWithNoPlaceSeen_isNil() throws {
        let origin = CLLocationCoordinate2D(latitude: 38.1744, longitude: -85.736)
        let destination = CLLocationCoordinate2D(latitude: 39.8719, longitude: -75.2411)
        let path = FlightPath(from: origin, to: destination)
        let departure = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try XCTUnwrap(FlightPlan(departure: departure, arrival: departure.addingTimeInterval(6300), distance: path.length))
        XCTAssertNil(FlightRecord(path: path, plan: plan))
    }
}
