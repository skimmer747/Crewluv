//
//  HomeArrivalTests.swift
//  CrewluvTests
//
//  When the pilot gets home: trip by trip, as Crewluve Website finds it (`arrivalTarget`).
//

import XCTest
@testable import Crewluv

final class HomeArrivalTests: XCTestCase {

    // MARK: - Fixture

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// The moment `hours` after the fixture's start.
    private func at(_ hours: Double) -> Date {
        start.addingTimeInterval(hours * 3600)
    }

    private func flight(
        _ id: String, trip: String?, _ from: Double, _ to: Double,
        _ departure: String, _ arrival: String, delayMinutes: Int? = nil
    ) -> TripLeg {
        leg(id, .flight, trip: trip, from, to, airport: departure,
            departure: departure, arrival: arrival, delayMinutes: delayMinutes)
    }

    private func drive(_ id: String, _ from: Double, _ to: Double, _ departure: String, _ arrival: String) -> TripLeg {
        leg(id, .drive, trip: nil, from, to, airport: departure, departure: departure, arrival: arrival)
    }

    private func ground(_ id: String, _ type: TripLeg.LegType, trip: String, _ from: Double, _ to: Double, at airport: String) -> TripLeg {
        leg(id, type, trip: trip, from, to, airport: airport)
    }

    private func leg(
        _ id: String, _ type: TripLeg.LegType, trip: String?, _ from: Double, _ to: Double,
        airport: String?, departure: String? = nil, arrival: String? = nil, delayMinutes: Int? = nil
    ) -> TripLeg {
        TripLeg(
            id: id, tripId: trip, type: type,
            startTime: at(from), endTime: at(to),
            airportCode: airport, city: nil,
            timezoneIdentifier: nil, arrivalTimezoneIdentifier: nil,
            flightNumber: nil, departureAirport: departure, arrivalAirport: arrival,
            departureCity: nil, arrivalCity: nil,
            tripDayNumber: nil, tripTotalDays: nil, delayMinutes: delayMinutes,
            airlineCode: nil, label: nil
        )
    }

    /// A commuter's two weeks, home Orlando and base Louisville. Each trip ends at base, and the pilot goes
    /// home for a few hours before commuting back for the next, so no gap between legs reaches a day until
    /// the third trip's drive home.
    private var commuterWeeks: [TripLeg] {
        [
            ground("S1-layover", .layover, trip: "S1", -17, 6.5, at: "ANC"),
            flight("S1-last", trip: "S1", 6.5, 12.6, "ANC", "SDF"),
            drive("drive-home-1", 13.1, 15.1, "SDF", "MCO"),
            flight("commute-back", trip: nil, 18.8, 19.5, "MCO", "SDF"),
            flight("T2-out", trip: "T2", 22, 23.5, "SDF", "PHL"),
            flight("T2-back", trip: "T2", 25, 26.5, "PHL", "SDF"),
            ground("T2-base", .base, trip: "T2", 26.5, 50, at: "SDF"),
            flight("T2-out-2", trip: "T2", 50, 51, "SDF", "CAE"),
            flight("T2-last", trip: "T2", 54, 55, "CAE", "SDF"),
            flight("jumpseat-home", trip: nil, 57.5, 58, "SDF", "MCO"),
            drive("drive-to-work", 65.5, 69.5, "MCO", "SDF"),
            flight("T3-out", trip: "T3", 71.5, 80.5, "SDF", "HNL"),
            ground("T3-layover", .layover, trip: "T3", 80.5, 100, at: "HNL"),
            flight("T3-last", trip: "T3", 100, 110, "HNL", "SDF"),
            drive("drive-home-2", 110.5, 112.5, "SDF", "MCO"),
            drive("drive-to-work-2", 180, 182, "MCO", "SDF"),
        ]
    }

    private func homeArrival(_ legs: [TripLeg], home: String = "MCO", at hours: Double) -> TripEndInfo? {
        TripStateResolver.resolveHomeArrival(legs: legs, homeAirportCode: home, at: at(hours))
    }

    // MARK: - A Commuter's Short Stops at Home

    func test_resolveHomeArrival_commuterHomeForAFewHoursBeforeTheNextTrip_countsToThisTripsRideHome() {
        let info = homeArrival(commuterWeeks, at: 0)
        XCTAssertEqual(info?.arrivalTime, at(15.1))
        XCTAssertEqual(info?.arrivalLabel, "Back Home In")
        XCTAssertEqual(info?.trips, ["S1"])
    }

    func test_resolveHomeArrival_onTheRideHome_countsToItsEnd() {
        let info = homeArrival(commuterWeeks, at: 14)
        XCTAssertEqual(info?.arrivalTime, at(15.1))
        XCTAssertEqual(info?.trips, ["S1"])
    }

    func test_resolveHomeArrival_homeBetweenTrips_returnsNil() {
        XCTAssertNil(homeArrival(commuterWeeks, at: 17))
    }

    func test_resolveHomeArrival_commutingBackForTheNextTrip_countsToThatTripsRideHome() {
        let info = homeArrival(commuterWeeks, at: 19)
        XCTAssertEqual(info?.arrivalTime, at(58))
        XCTAssertEqual(info?.trips, ["S1", "T2"])
    }

    func test_resolveHomeArrival_midTrip_countsToTheRideHomeAfterIt() {
        let info = homeArrival(commuterWeeks, at: 30)
        XCTAssertEqual(info?.arrivalTime, at(58))
        XCTAssertEqual(info?.trips, ["T2"])
    }

    // MARK: - Trips That End at Home

    func test_resolveHomeArrival_nextTripLessThanADayLater_countsToThisTripsLastFlightHome() {
        let legs = [
            flight("A-out", trip: "A", -5, -3, "MCO", "ATL"),
            ground("A-layover", .layover, trip: "A", -3, 10, at: "ATL"),
            flight("A-home", trip: "A", 10, 12, "ATL", "MCO"),
            flight("B-out", trip: "B", 30, 33, "MCO", "BOS"),
            flight("B-home", trip: "B", 40, 43, "BOS", "MCO"),
        ]
        let info = homeArrival(legs, at: 0)
        XCTAssertEqual(info?.arrivalTime, at(12))
        XCTAssertEqual(info?.trips, ["A"])
    }

    func test_resolveHomeArrival_nightTurnThroughHome_countsToTheTripsRideHomeAfterItsEnd() {
        let legs = [
            flight("T-to-home", trip: "T", 2, 4, "SDF", "MCO"),
            ground("T-turn", .turn, trip: "T", 4, 5, at: "MCO"),
            flight("T-from-home", trip: "T", 5, 7, "MCO", "SDF"),
            ground("T-base", .base, trip: "T", 7, 30, at: "SDF"),
            flight("T-out", trip: "T", 30, 31, "SDF", "RFD"),
            flight("T-last", trip: "T", 32, 33, "RFD", "SDF"),
            drive("drive-home", 33.5, 35.5, "SDF", "MCO"),
        ]
        for moment in [0, 3, 4.5, 6] {
            XCTAssertEqual(homeArrival(legs, at: moment)?.arrivalTime, at(35.5), "at \(moment) h")
        }
    }

    func test_resolveHomeArrival_delayedFlightHome_countsToItsDelayedLanding() {
        let legs = [flight("A-home", trip: "A", 2, 4, "ATL", "MCO", delayMinutes: 40)]
        let info = homeArrival(legs, at: 0)
        XCTAssertEqual(info?.arrivalTime, at(4).addingTimeInterval(40 * 60))
        XCTAssertEqual(info?.trips, ["A"])
    }

    // MARK: - From One Trip to the Next

    func test_resolveHomeArrival_nextTripFromBaseWithinADay_carriesOnToItsRideHome() {
        let legs = [
            flight("A-last", trip: "A", -1, 4, "SEA", "SDF"),
            flight("B-out", trip: "B", 20, 24, "SDF", "DEN"),
            flight("B-last", trip: "B", 30, 34, "DEN", "SDF"),
            drive("drive-home", 35, 37, "SDF", "MCO"),
        ]
        let info = homeArrival(legs, at: 0)
        XCTAssertEqual(info?.arrivalTime, at(37))
        XCTAssertEqual(info?.trips, ["A", "B"])
    }

    func test_resolveHomeArrival_nextTripLeavesFromHome_returnsNil() {
        let legs = [
            flight("A-last", trip: "A", -1, 4, "SEA", "SDF"),
            flight("B-out", trip: "B", 20, 22, "MCO", "ATL"),
            flight("B-home", trip: "B", 26, 28, "ATL", "MCO"),
        ]
        XCTAssertNil(homeArrival(legs, at: 0))
    }

    // MARK: - An Upcoming Trip's Homecoming

    func test_resolveHomeArrivalForTrip_tripAfterAFewHoursHome_countsToItsOwnRideHome() {
        let info = TripStateResolver.resolveHomeArrival(forTrip: "T2", legs: commuterWeeks, homeAirportCode: "MCO")
        XCTAssertEqual(info?.arrivalTime, at(58))
        XCTAssertEqual(info?.trips, ["T2"])
    }

    func test_resolveHomeArrivalForTrip_tripNotOnTheSchedule_returnsNil() {
        XCTAssertNil(TripStateResolver.resolveHomeArrival(forTrip: "gone", legs: commuterWeeks, homeAirportCode: "MCO"))
    }

    // MARK: - With No Trip Near

    func test_resolveHomeArrival_noTripWithinADay_countsToARideHomeWithinThreeDays() {
        let info = homeArrival([drive("drive-home", 30, 32, "SDF", "MCO")], at: 0)
        XCTAssertEqual(info?.arrivalTime, at(32))
        XCTAssertEqual(info?.trips, [])
    }

    func test_resolveHomeArrival_noTripWithinADay_rideHomeOverThreeDaysAway_returnsNil() {
        XCTAssertNil(homeArrival([drive("drive-home", 80, 82, "SDF", "MCO")], at: 0))
    }
}
