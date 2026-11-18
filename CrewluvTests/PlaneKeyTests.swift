//
//  PlaneKeyTests.swift
//  CrewluvTests
//
//  When the map shows the key to its two planes (which plane design §2): while it draws a real plane and its ghost,
//  now only, on the shared cases' flights.
//

import XCTest
@testable import Crewluv

final class PlaneKeyTests: XCTestCase {

    /// A shared case's flight at one of its moments, as the map of that one flight.
    private func map(of name: String, at time: String) throws -> (map: TripMap, at: Date) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let moment = try cases.moment(time, of: flightCase)
        let leg = try cases.mapLeg(flightCase, at: moment)
        return (TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: leg.origin,
                        span: DateInterval(start: leg.start, end: leg.end), tripDays: nil), moment.at)
    }

    func test_showsPlaneKey_whileTheRealPlaneAndItsGhostShow() throws {
        for (name, time) in [("ahead, in the air", "13T12:41:50"), ("ahead, in the air", "13T12:45:00"),
                             ("still on the ground twenty minutes after", "13T12:35:00")] {
            let (map, at) = try map(of: name, at: time)
            XCTAssertTrue(TripMapDrawing(tripMap: map, at: at).showsPlaneKey, "\(name) at \(time)")
        }
    }

    func test_showsPlaneKey_notForAPlaneWithNoGhost_norInAReplay() throws {
        for (name, time) in [("landed, seen all the way", "13T13:30:00"), ("on the ground somewhere else", "13T13:21:00"),
                             ("no live data", "13T12:30:00"), ("waiting to be seen", "13T12:30:00")] {
            let (map, at) = try map(of: name, at: time)
            XCTAssertFalse(TripMapDrawing(tripMap: map, at: at).showsPlaneKey, "\(name) at \(time)")
        }
        let (map, at) = try map(of: "ahead, in the air", at: "13T12:41:50")
        XCTAssertFalse(TripMapDrawing(tripMap: map, at: at, isReplay: true).showsPlaneKey)
        XCTAssertFalse(TripMapDrawing.showsPlaneKey(on: map, at: at, isReplay: true))
    }

    func test_showsPlaneKey_atEverySharedMoment_isWhetherTheCaseHasBothPlanes_withoutDrawingTheRest() throws {
        let cases = try TripMapFixtures.liveCases()
        var shown = 0
        for flightCase in cases.flights {
            for moment in flightCase.moments {
                let leg = try cases.mapLeg(flightCase, at: moment)
                let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: leg.origin,
                                  span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
                // The map draws a flight's planes between its gates.
                let expected = moment.plane != nil && moment.ghost != nil && leg.isMoving(at: moment.at)
                XCTAssertEqual(TripMapDrawing(tripMap: map, at: moment.at).showsPlaneKey, expected, "\(flightCase.name) at \(moment.at)")
                XCTAssertEqual(TripMapDrawing.showsPlaneKey(on: map, at: moment.at, isReplay: false), expected,
                               "\(flightCase.name) at \(moment.at)")
                if expected { shown += 1 }
            }
        }
        XCTAssertGreaterThan(shown, 20)
    }

    func test_showsPlaneKey_notOnTheGround_beforeOrAfterTheFlight() throws {
        let (map, _) = try map(of: "ahead, in the air", at: "13T12:41:50")
        let leg = try XCTUnwrap(map.legs.first)
        for date in [leg.start.addingTimeInterval(-60), leg.end] {
            XCTAssertFalse(TripMapDrawing(tripMap: map, at: date).showsPlaneKey)
            XCTAssertFalse(TripMapDrawing.showsPlaneKey(on: map, at: date, isReplay: false))
        }
    }
}
