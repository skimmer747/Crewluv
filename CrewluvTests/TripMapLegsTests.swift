//
//  TripMapLegsTests.swift
//  CrewluvTests
//
//  Which legs the status screen's map draws while the pilot is away, as Crewluve Website's tripMapFor picks them: the
//  trip under way, by its id, with the drives and jumpseats within 12 hours of its flights; between trips, the flight
//  or drive in motion.
//

import XCTest
@testable import Crewluv

final class TripMapLegsTests: XCTestCase {

    // MARK: - Fixture

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// The moment `hours` after the fixture's start.
    private func at(_ hours: Double) -> Date {
        start.addingTimeInterval(hours * 3600)
    }

    private func leg(
        _ id: String, _ type: TripLeg.LegType = .flight, trip: String?, _ from: Double, _ to: Double,
        _ departure: String? = nil, _ arrival: String? = nil, delayMinutes: Int? = nil
    ) -> TripLeg {
        TripLeg(
            id: id, tripId: trip, type: type,
            startTime: at(from), endTime: at(to),
            airportCode: nil, city: nil,
            timezoneIdentifier: nil, arrivalTimezoneIdentifier: nil,
            flightNumber: nil, departureAirport: departure, arrivalAirport: arrival,
            departureCity: nil, arrivalCity: nil,
            tripDayNumber: nil, tripTotalDays: nil, delayMinutes: delayMinutes,
            airlineCode: nil, label: nil
        )
    }

    /// A commuter, home Orlando and base Louisville, home for a few hours between trips, so no gap between legs
    /// reaches a day: S1 ends at base, a drive home, a jumpseat back, T2, a jumpseat home, a drive to work, T3.
    private var commuterWeeks: [TripLeg] {
        [
            leg("s1-out", trip: "S1", -30, -24, "SDF", "ANC"),
            leg("s1-layover", .layover, trip: "S1", -24, 6),
            leg("s1-last", trip: "S1", 6, 12, "ANC", "SDF"),
            leg("drive-home", .drive, trip: nil, 12.5, 14.5, "SDF", "MCO"),
            leg("commute-back", trip: nil, 18, 19, "MCO", "SDF"),
            leg("t2-out", trip: "T2", 21, 22.5, "SDF", "PHL"),
            leg("t2-turn", .turn, trip: "T2", 22.5, 24),
            leg("t2-back", trip: "T2", 24, 26, "PHL", "SDF"),
            leg("jumpseat-home", trip: nil, 28, 29, "SDF", "MCO"),
            leg("drive-to-work", .drive, trip: nil, 36, 40, "MCO", "SDF"),
            leg("t3-out", trip: "T3", 42, 48, "SDF", "ANC"),
        ]
    }

    private func ids(_ legs: [TripLeg]?) -> [String]? {
        legs?.map(\.id)
    }

    // MARK: - The Trip Under Way

    func test_ofTripUnderWay_onALayover_isThatTripAndItsCommutes_notTheNextTrips() {
        let legs = TripMapLegs.ofTripUnderWay(in: commuterWeeks, at: at(0))
        XCTAssertEqual(ids(legs), ["s1-out", "s1-layover", "s1-last", "drive-home", "commute-back"])
    }

    func test_ofTripUnderWay_inFlight_takesTheJumpseatsAndDrivesWithin12HoursOfItsFlights() {
        let legs = TripMapLegs.ofTripUnderWay(in: commuterWeeks, at: at(22))
        XCTAssertEqual(ids(legs), ["drive-home", "commute-back", "t2-out", "t2-turn", "t2-back", "jumpseat-home"])
    }

    func test_ofTripUnderWay_aDelayedLastFlight_keepsTheTripUnderWayUntilItLands() {
        let legs = [
            leg("a-out", trip: "A", -5, -3, "SDF", "PHL"),
            leg("a-last", trip: "A", -2, 0, "PHL", "SDF", delayMinutes: 40),
        ]
        XCTAssertEqual(ids(TripMapLegs.ofTripUnderWay(in: legs, at: at(0.5))), ["a-out", "a-last"])
        XCTAssertNil(TripMapLegs.ofTripUnderWay(in: legs, at: at(0.75)))
    }

    func test_ofTripUnderWay_betweenTrips_isNil() {
        XCTAssertNil(TripMapLegs.ofTripUnderWay(in: commuterWeeks, at: at(13)))
        XCTAssertNil(TripMapLegs.ofTripUnderWay(in: commuterWeeks, at: at(17)))
    }

    func test_ofTripUnderWay_aTripWithNoFlight_isNil() {
        let reserve = [leg("rsv", .reserve, trip: "R", -2, 10)]
        XCTAssertNil(TripMapLegs.ofTripUnderWay(in: reserve, at: at(0)))
    }

    // MARK: - Between Trips

    func test_inMotion_onTheDriveHome_isTheDrive() {
        XCTAssertEqual(TripMapLegs.inMotion(in: commuterWeeks, at: at(13))?.id, "drive-home")
    }

    func test_inMotion_onAJumpseat_isTheJumpseat() {
        XCTAssertEqual(TripMapLegs.inMotion(in: commuterWeeks, at: at(18.5))?.id, "commute-back")
    }

    func test_inMotion_atHomeBetweenTrips_isNil() {
        XCTAssertNil(TripMapLegs.inMotion(in: commuterWeeks, at: at(17)))
    }

    func test_inMotion_aFlightOverlappingADrive_isTheFlight() {
        let legs = [
            leg("drive", .drive, trip: nil, 0, 4, "SDF", "MCO"),
            leg("flight", trip: nil, 1, 3, "SDF", "MCO"),
        ]
        XCTAssertEqual(TripMapLegs.inMotion(in: legs, at: at(2))?.id, "flight")
    }
}
