//
//  MapFlightTests.swift
//  CrewluvTests
//
//  A flight as the trip map measures and draws it: its plan, path and record made together (Stage 3 spec §11),
//  held to the shared cases in Fixtures/TripMap.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class MapFlightTests: XCTestCase {

    private let departure = TripMapTestLegs.tripStart
    private var arrival: Date { departure.addingTimeInterval(8 * 3600) }
    private let louisville = TripMapTestLegs.airports["SDF"]!
    private let cologne = TripMapTestLegs.airports["CGN"]!

    func test_init_withNoLiveData_hasTheSchedulesPlan_theGreatCircle_andNoRecord() throws {
        let flight = try XCTUnwrap(MapFlight(departure: departure, arrival: arrival, from: louisville, to: cologne))
        XCTAssertEqual(flight.plan.departure, departure)
        XCTAssertEqual(flight.plan.arrival, arrival)
        XCTAssertEqual(flight.plan.distance, GreatCircle.distance(from: louisville, to: cologne), accuracy: 1e-6)
        XCTAssertFalse(flight.path.isReal)
        XCTAssertEqual(flight.path.stretches.map(\.kind), [.planned])
        XCTAssertNil(flight.record)
        XCTAssertNil(flight.live)
        XCTAssertEqual(flight.progress(at: departure.addingTimeInterval(3600)).phase, .notLive)
    }

    func test_init_aLegThatArrivesNoLaterThanItLeaves_isNil() {
        XCTAssertNil(MapFlight(departure: departure, arrival: departure, from: louisville, to: cologne))
        XCTAssertNil(MapFlight(departure: arrival, arrival: departure, from: louisville, to: cologne))
    }

    func test_init_everySharedCase_makesThePathAndTheRecordTheCaseExpects() throws {
        let cases = try TripMapFixtures.liveCases()
        XCTAssertFalse(cases.flights.isEmpty)
        for flightCase in cases.flights {
            let flight = try cases.mapFlight(flightCase)
            XCTAssertEqual(flight.path.isReal, flightCase.path.isReal, flightCase.name)
            XCTAssertEqual(flight.path.stretches.map(\.kind.rawValue), flightCase.path.stretchKinds, flightCase.name)
            XCTAssertEqual(flight.record != nil, flightCase.record != nil, flightCase.name)
        }
    }

    func test_progress_everySharedMoment_matchesTheCase() throws {
        let cases = try TripMapFixtures.liveCases()
        var checked = 0
        for flightCase in cases.flights {
            let flight = try cases.mapFlight(flightCase)
            for moment in flightCase.moments {
                let name = "\(flightCase.name) at \(moment.at)"
                let progress = flight.progress(at: moment.at)
                XCTAssertEqual(progress.phase.rawValue, moment.phase, name)
                XCTAssertEqual(progress.label.map(TripMapWording.liveLabel), moment.label, name)
                XCTAssertEqual(progress.start.timeIntervalSince1970, moment.start.timeIntervalSince1970, accuracy: 0.05, name)
                XCTAssertEqual(progress.end.timeIntervalSince1970, moment.end.timeIntervalSince1970, accuracy: 0.05, name)
                checked += 1
            }
        }
        XCTAssertGreaterThanOrEqual(checked, 20)
    }

    func test_progress_measuresAFixsAgeByCrewluCloudsClock() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        // This phone's clock is 10 minutes slow. By it, the fix would be in the future.
        let flight = try cases.mapFlight(flightCase, clockOffset: 600)
        for moment in flightCase.moments {
            let progress = flight.progress(at: moment.at.addingTimeInterval(-600))
            XCTAssertEqual(progress.phase.rawValue, moment.phase, "\(moment.at)")
        }
    }

    func test_isEstimate_isTrueOfATimeThatIsntThePlans_untilThePlaneHasLanded() throws {
        let cases = try TripMapFixtures.liveCases()
        let inTheAir = try cases.mapFlight(cases.flight(named: "ahead, in the air"))
        XCTAssertFalse(inTheAir.isEstimate(inTheAir.plan.arrival), "the schedule's own time")
        XCTAssertFalse(inTheAir.isEstimate(inTheAir.plan.arrival.addingTimeInterval(0.5)), "the same time, but for rounding")
        XCTAssertTrue(inTheAir.isEstimate(inTheAir.plan.arrival.addingTimeInterval(-13 * 60)))
        let landed = try cases.mapFlight(cases.flight(named: "landed, seen all the way"))
        XCTAssertFalse(landed.isEstimate(landed.plan.arrival.addingTimeInterval(-23 * 60)), "a landing that was seen is no estimate")
        let none = try cases.mapFlight(cases.flight(named: "no live data"))
        XCTAssertFalse(none.isEstimate(none.plan.arrival))
    }
}
