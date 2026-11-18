//
//  LiveTripMapTests.swift
//  CrewluvTests
//
//  The trip map with a real plane (Stage 3 spec §6.2, §11): each flight carries its plan, path and record, and the
//  camera frames the real path.
//

import XCTest
import CoreLocation
import MapKit
@testable import Crewluv

final class LiveTripMapTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { start.addingTimeInterval(value * 3600) }

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

    // MARK: - What each leg carries

    func test_make_aFlightWithNoLiveData_carriesTheSchedulesPlanAndTheGreatCircle() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(firstDelayMinutes: 20), at: hours(4)))
        let leg = try XCTUnwrap(map.legs.first)
        let flight = try XCTUnwrap(leg.flight)
        XCTAssertEqual(flight.plan.departure, leg.start, "the plan is the schedule moved by the delay")
        XCTAssertEqual(flight.plan.arrival, leg.end)
        XCTAssertFalse(flight.path.isReal)
        XCTAssertNil(flight.record)
        XCTAssertNil(flight.live)
        XCTAssertFalse(leg.isArrivalEstimated)
    }

    func test_make_aDrive_carriesNoFlight() throws {
        let legs = [TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(0), hours: 2)]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(1)))
        XCTAssertNil(map.legs.first?.flight)
    }

    func test_make_aFlightWithLiveData_carriesItsRealPath_atTheRealPlanesTimes() throws {
        let (map, moment) = try map(of: "ahead, in the air", at: "13T12:41:50")
        let leg = try XCTUnwrap(map.legs.first)
        XCTAssertEqual(map.mode, .inFlight(legID: "f1"))
        XCTAssertEqual(leg.start.timeIntervalSince1970, moment.start.timeIntervalSince1970, accuracy: 0.05)
        XCTAssertEqual(leg.end.timeIntervalSince1970, moment.end.timeIntervalSince1970, accuracy: 0.05)
        let flight = try XCTUnwrap(leg.flight)
        XCTAssertTrue(flight.path.isReal)
        XCTAssertNotNil(flight.record)
        XCTAssertNotEqual(flight.plan.arrival, leg.end, "the plan keeps the schedule's times")
        XCTAssertTrue(leg.isArrivalEstimated)
    }

    func test_make_aLandedFlight_hasNoEstimate() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "landed, seen all the way")
        let moment = flightCase.moments[0]
        let leg = try cases.mapLeg(flightCase, at: moment)
        XCTAssertNotEqual(leg.end, flightCase.arrival)
        XCTAssertFalse(leg.isArrivalEstimated)
    }

    // MARK: - The camera

    func test_framingCoordinates_ofAFlightWithNoLiveData_areTheGreatCirclesOfBefore() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(4)))
        let leg = try XCTUnwrap(map.currentLeg)
        let before = GreatCircle.points(from: leg.origin.coordinate, to: leg.destination.coordinate, count: 33)
        let places = map.framingCoordinates(focusingOn: leg)
        XCTAssertEqual(places.count, 33)
        for (place, expected) in zip(places, before) {
            XCTAssertEqual(place.latitude, expected.latitude, accuracy: 1e-9)
            XCTAssertEqual(place.longitude, expected.longitude, accuracy: 1e-9)
        }
    }

    func test_framingRect_ofAFlightWithARealPath_holdsEveryPlaceItWasSeen() throws {
        let (map, _) = try map(of: "off early and the long way round", at: "13T12:15:20")
        let leg = try XCTUnwrap(map.currentLeg)
        let path = try XCTUnwrap(leg.flight?.path)
        let rect = try XCTUnwrap(map.framingRect(focusingOn: leg))
        for stretch in path.stretches {
            XCTAssertTrue(rect.contains(MKMapPoint(stretch.start)), "\(stretch.start)")
        }
    }

    func test_framingRect_ofAPathFarFromTheGreatCircle_reachesIt() throws {
        // Louisville to Cologne by way of Iceland, well north of the straight line between them.
        let louisville = try XCTUnwrap(TripMapTestLegs.coordinate("SDF"))
        let cologne = try XCTUnwrap(TripMapTestLegs.coordinate("CGN"))
        let iceland = CLLocationCoordinate2D(latitude: 66, longitude: -20)
        let seen = LiveFlight.TrailPoint(time: hours(4), latitude: iceland.latitude, longitude: iceland.longitude, altitudeFeet: 38_000)
        let live = LiveFlight(legID: "f1", callsign: "UPS207", state: .airborne, fix: nil, landedAt: nil, trail: [seen])
        let flight = try XCTUnwrap(MapFlight(departure: hours(0), arrival: hours(8), from: louisville, to: cologne, live: live))
        let legs = [TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(0), hours: 8)]
        let map = try XCTUnwrap(TripMap.make(tripLegs: legs, isNextTrip: false, homeAirportCode: "SDF", legacyDelayMinutes: nil,
                                             flights: ["f1": flight], at: hours(4), coordinate: TripMapTestLegs.coordinate))
        let leg = try XCTUnwrap(map.currentLeg)

        let straight = try XCTUnwrap(MapFit.rect(enclosing: GreatCircle.points(from: louisville, to: cologne, count: 33)))
        XCTAssertFalse(straight.contains(MKMapPoint(iceland)), "the straight line's frame leaves Iceland out")
        XCTAssertTrue(try XCTUnwrap(map.framingRect(focusingOn: leg)).contains(MKMapPoint(iceland)))
        XCTAssertTrue(try XCTUnwrap(map.framingRect(focusingOn: nil)).contains(MKMapPoint(iceland)), "and so does the whole trip's")
    }

    func test_framingKey_isTheFramingRectAsNumbers_andChangesWhenItDoes() throws {
        let (straight, _) = try map(of: "ahead, in the air", at: "13T12:41:50")
        let (longWay, _) = try map(of: "off early and the long way round", at: "13T12:15:20")
        let leg = try XCTUnwrap(straight.currentLeg)
        let rect = try XCTUnwrap(straight.framingRect(focusingOn: leg))
        XCTAssertEqual(straight.framingKey(focusingOn: leg), [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height])
        XCTAssertNotEqual(straight.framingKey(focusingOn: leg), longWay.framingKey(focusingOn: try XCTUnwrap(longWay.currentLeg)))
    }
}
