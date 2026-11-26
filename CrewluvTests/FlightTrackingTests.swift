//
//  FlightTrackingTests.swift
//  CrewluvTests
//
//  How the flight between its gates is known now, and whether it's on the ground at its departure airport (live or
//  scheduled design §2, §3), held to the shared live cases.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class FlightTrackingTests: XCTestCase {

    /// A shared case's flight at its moment `time`, as a leg of the map, and that moment.
    private func caseLeg(_ name: String, at time: String) throws -> (leg: MapLeg, at: Date) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let moment = try cases.moment(time, of: flightCase)
        return (try cases.mapLeg(flightCase, at: moment), moment.at)
    }

    /// `leg` while Crewlu Cloud's first answer is on its way.
    private func awaiting(_ leg: MapLeg) -> MapLeg {
        MapLeg(id: leg.id, kind: leg.kind, origin: leg.origin, destination: leg.destination, start: leg.start, end: leg.end,
               flightNumber: leg.flightNumber, flight: leg.flight, isAwaitingLive: true)
    }

    // MARK: - How it's known (§2)

    func test_tracking_isLive_whileCrewluCloudSawThePlaneInTheLastThreeMinutes() throws {
        for (name, time) in [("on the ground before the plan's takeoff", "13T12:10:00"), ("ahead, in the air", "13T12:41:50"),
                             ("still on the ground twenty minutes after", "13T12:35:00"),
                             ("an air return, back on the ground", "13T12:41:00"), ("landed, seen all the way", "13T13:30:00"),
                             ("on the ground somewhere else", "13T13:21:00")] {
            let (leg, at) = try caseLeg(name, at: time)
            XCTAssertEqual(leg.tracking(at: at), .live, name)
        }
    }

    func test_tracking_isABestGuess_onceAPlaneLastSeenInTheAirHasntBeenForOverThreeMinutes() throws {
        let (leg, at) = try caseLeg("ahead, in the air", at: "13T12:45:00")
        XCTAssertEqual(leg.tracking(at: at), .bestGuess)
    }

    func test_tracking_isNotTracked_withNoLiveData_orAGroundFixOverThreeMinutesOld() throws {
        for (name, time) in [("no live data", "13T12:30:00"), ("on the ground before the plan's takeoff", "13T12:13:00"),
                             ("an air return, back on the ground", "13T12:43:01")] {
            let (leg, at) = try caseLeg(name, at: time)
            XCTAssertEqual(leg.tracking(at: at), .notTracked, name)
        }
    }

    func test_tracking_isWaiting_whileTheFirstAnswerIsOnItsWay_andEitherIsByTheSchedule() throws {
        let (leg, at) = try caseLeg("no live data", at: "13T12:30:00")
        XCTAssertEqual(awaiting(leg).tracking(at: at), .waiting)
        XCTAssertTrue(FlightTracking.waiting.isBySchedule)
        XCTAssertTrue(FlightTracking.notTracked.isBySchedule)
        XCTAssertFalse(FlightTracking.live.isBySchedule)
        XCTAssertFalse(FlightTracking.bestGuess.isBySchedule)
    }

    func test_make_marksOnlyAFlightCrewluCloudHasntAnsweredFor_asWaiting() throws {
        let cases = try TripMapFixtures.liveCases()
        let noLive = try cases.flight(named: "no live data")
        let ahead = try cases.flight(named: "ahead, in the air")
        let at = try cases.moment("13T12:30:00", of: noLive).at
        func map(flights: [String: MapFlight]) -> TripMap? {
            TripMap.make(tripLegs: [cases.tripLeg(noLive)], isNextTrip: false, homeAirportCode: "SDF", legacyDelayMinutes: nil,
                         flights: flights, isAwaitingLive: true, at: at, coordinate: cases.coordinateOrNil)
        }
        XCTAssertEqual(map(flights: [:])?.legs.first?.isAwaitingLive, true)
        let answered = try cases.mapFlight(ahead)
        XCTAssertEqual(map(flights: ["f1": answered])?.legs.first?.isAwaitingLive, false)
    }

    // MARK: - On the ground at departure (§3)

    func test_atDeparture_isDue_byTheScheduleAlone_untilTheSchedulesTakeoff() throws {
        let (leg, _) = try caseLeg("no live data", at: "13T12:30:00")
        XCTAssertEqual(leg.scheduledTakeoff, leg.start.addingTimeInterval(15 * 60))
        XCTAssertEqual(leg.atDeparture(at: leg.start.addingTimeInterval(5 * 60)), .due)
        XCTAssertEqual(awaiting(leg).atDeparture(at: leg.start.addingTimeInterval(14 * 60)), .due)
        XCTAssertNil(leg.atDeparture(at: leg.scheduledTakeoff))
        // A fix on the ground gone stale is the schedule's again.
        let stale = try caseLeg("on the ground before the plan's takeoff", at: "13T12:13:00")
        XCTAssertEqual(stale.leg.atDeparture(at: stale.at), .due)
    }

    func test_atDeparture_isTheRealPlaneAtItsGate_stillThere_orBackAfterAnAirReturn() throws {
        let atGate = try caseLeg("on the ground before the plan's takeoff", at: "13T12:10:00")
        XCTAssertEqual(atGate.leg.atDeparture(at: atGate.at), .atGate)
        let late = try caseLeg("still on the ground twenty minutes after", at: "13T12:35:00")
        XCTAssertEqual(late.leg.atDeparture(at: late.at), .stillAtGate)
        let back = try caseLeg("an air return, back on the ground", at: "13T12:41:00")
        XCTAssertEqual(back.leg.atDeparture(at: back.at), .returned)
        XCTAssertTrue(AtDeparture.atGate.isSeen)
        XCTAssertTrue(AtDeparture.stillAtGate.isSeen)
        XCTAssertTrue(AtDeparture.returned.isSeen)
        XCTAssertFalse(AtDeparture.due.isSeen)
    }

    func test_atDeparture_isNil_inTheAir_outOfSight_landed_orByTheScheduleAfterItsTakeoff() throws {
        for (name, time) in [("ahead, in the air", "13T12:41:50"), ("ahead, in the air", "13T12:45:00"),
                             ("landed, seen all the way", "13T13:30:00"), ("no live data", "13T12:30:00"),
                             ("an air return, back on the ground", "13T12:43:01")] {
            let (leg, at) = try caseLeg(name, at: time)
            XCTAssertNil(leg.atDeparture(at: at), "\(name) at \(time)")
        }
        let (leg, _) = try caseLeg("no live data", at: "13T12:30:00")
        XCTAssertNil(leg.atDeparture(at: leg.start.addingTimeInterval(-60)), "before its gate time")
    }

    func test_atDeparture_aBlockTooShortForTheTaxiAllowances_takesOffAtTheGate() throws {
        let (long, _) = try caseLeg("no live data", at: "13T12:30:00")
        let short = MapLeg(id: long.id, kind: .flight, origin: long.origin, destination: long.destination, start: long.start,
                           end: long.start.addingTimeInterval(20 * 60), flightNumber: long.flightNumber)
        XCTAssertEqual(short.scheduledTakeoff, short.start)
        XCTAssertNil(short.atDeparture(at: short.start.addingTimeInterval(5 * 60)))
    }

    func test_seenAtDeparture_agreesWithHasReturned() throws {
        for (name, time) in [("on the ground before the plan's takeoff", "13T12:10:00"),
                             ("still on the ground twenty minutes after", "13T12:35:00"),
                             ("an air return, back on the ground", "13T12:41:00"), ("ahead, in the air", "13T12:41:50")] {
            let (leg, at) = try caseLeg(name, at: time)
            let flight = try XCTUnwrap(leg.flight)
            XCTAssertEqual(flight.hasReturned(at: at), flight.seenAtDeparture(at: at) == .returned, name)
        }
    }
}
