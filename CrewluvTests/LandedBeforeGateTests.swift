//
//  LandedBeforeGateTests.swift
//  CrewluvTests
//
//  When a real plane is down at its arrival airport and not yet at the gate (landed before the gate design §2). The
//  flight is `FactsTestData`'s equator flight, from E0 to E20: its real plane is seen down at E20 at 12:55 UTC and
//  reaches the gate at 13:02, the plan's 7 minutes of taxi in later.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LandedBeforeGateTests: XCTestCase {

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    /// The equator flight with its real plane down at E20 since 12:55, as the status screen's model hands it on at `now`.
    private func landed(at now: String) throws -> MapLeg {
        let live = FactsTestData.equatorLive(seenUntil: at("12:53"), landedAt: FactsTestData.liveTime(atLongitude: 20))
        return try FactsTestData.equatorLiveLeg(live, at: at(now))
    }

    private func map(of leg: MapLeg) -> TripMap {
        TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: leg.origin,
                span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
    }

    // MARK: - When it is

    func test_isLandedBeforeGate_fromTouchdownUntilTheGate() throws {
        XCTAssertTrue(try landed(at: "12:56").isLandedBeforeGate(at: at("12:56")))
        XCTAssertTrue(try landed(at: "13:01").isLandedBeforeGate(at: at("13:01")))
        XCTAssertFalse(try landed(at: "13:02").isLandedBeforeGate(at: at("13:02")), "at the gate")
    }

    func test_isLandedBeforeGate_isNeverAPlaneInTheAir_aFlightWithNoLiveData_norADrive() throws {
        let flying = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("12:30")), at: at("12:30"))
        XCTAssertFalse(flying.isLandedBeforeGate(at: at("12:30")))
        XCTAssertFalse(try FactsTestData.equatorLiveLeg(nil, at: at("12:58")).isLandedBeforeGate(at: at("12:58")))
        let leg = try landed(at: "12:58")
        let drive = MapLeg(id: "d1", kind: .drive, origin: leg.origin, destination: leg.destination, start: leg.start, end: leg.end,
                           flightNumber: nil)
        XCTAssertFalse(drive.isLandedBeforeGate(at: at("12:58")))
    }

    func test_hasLanded_isCrewluCloudsLanded() throws {
        let flight = try XCTUnwrap(try landed(at: "12:58").flight)
        XCTAssertTrue(flight.hasLanded(at: at("12:58")))
        XCTAssertTrue(flight.hasLanded(at: at("13:30")), "after the gate too: the leg's gates bound the words")
        let flying = try XCTUnwrap(try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("12:30")), at: at("12:30")).flight)
        XCTAssertFalse(flying.hasLanded(at: at("12:30")))
    }

    func test_hasLanded_isFalse_forAPlaneSeenOnTheGroundAwayFromItsArrivalAirport() throws {
        // Down at 18° E, 120 nm short of E20: it landed somewhere else, which nothing names.
        let fix = LiveFlight.Fix(latitude: 0, longitude: 18, altitudeFeet: nil, groundSpeedKnots: 20, trackDegrees: nil,
                                 isOnGround: true, registration: "N370UP", typeCode: "B763", seenAt: at("12:55"))
        let elsewhere = LiveFlight(legID: "eq", callsign: "TST1", state: .landed, fix: fix, landedAt: at("12:55"),
                                   trail: FactsTestData.equatorLive(seenUntil: at("12:39")).trail)
        let leg = try FactsTestData.equatorLiveLeg(elsewhere, at: at("12:58"))
        XCTAssertFalse(try XCTUnwrap(leg.flight).hasLanded(at: at("12:58")))
        XCTAssertFalse(leg.isLandedBeforeGate(at: at("12:58")))
    }

    func test_landedAirport_isTheFlightsArrivalAirport_untilTheGate() throws {
        let leg = try landed(at: "12:58")
        XCTAssertEqual(map(of: leg).landedAirport(at: at("12:58"))?.code, "E20")
        XCTAssertNil(map(of: leg).landedAirport(at: at("13:02")), "at the gate")
        let flying = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("12:30")), at: at("12:30"))
        XCTAssertNil(map(of: flying).landedAirport(at: at("12:30")))
    }

    func test_landedFlight_isTheFlightBetweenItsGatesWhoseRealPlaneIsDown_byItsID() throws {
        let cases = try TripMapFixtures.liveCases()
        let landed = try cases.flight(named: "landed, seen all the way")
        let flights = ["f1": try cases.mapFlight(landed)]
        let gate = try XCTUnwrap(flights["f1"]?.progress(at: try cases.moment("13T13:30:00", of: landed).at).liveArrival)
        func flight(at now: Date) -> String? {
            let legs = LiveLegs.replacingTimes(in: [cases.tripLeg(landed)], with: flights, at: now)
            return LiveLegs.landedFlight(in: legs, flights: flights, at: now)
        }
        XCTAssertEqual(flight(at: gate.addingTimeInterval(-60)), "f1")
        XCTAssertNil(flight(at: gate), "at the gate")
        XCTAssertNil(LiveLegs.landedFlight(in: [cases.tripLeg(landed)], flights: [:], at: gate.addingTimeInterval(-60)))

        let flying = try cases.flight(named: "ahead, in the air")
        let now = try cases.moment("13T12:41:50", of: flying).at
        let flyingFlights = ["f1": try cases.mapFlight(flying)]
        let legs = LiveLegs.replacingTimes(in: [cases.tripLeg(flying)], with: flyingFlights, at: now)
        XCTAssertNil(LiveLegs.landedFlight(in: legs, flights: flyingFlights, at: now))
    }
}
