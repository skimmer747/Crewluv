//
//  TripMapRecapTests.swift
//  CrewluvTests
//
//  The recap (Stage 2 spec §8): for 24 hours after a trip ends at home, the map is that trip, unless the next trip
//  leaves within 12 hours.
//

import XCTest
@testable import Crewluv

/// Main actor: `TripMap(status:at:)` lives in a plain extension, which this app target isolates to it.
@MainActor
final class TripMapRecapTests: XCTestCase {

    private let now = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { now.addingTimeInterval(value * 3600) }

    /// The Europe trip (72 hours) ending `hoursAgo` hours before now.
    private func trip(endingHoursAgo hoursAgo: Double) -> [TripLeg] {
        TripMapTestLegs.europeTrip(startingAt: hours(-72 - hoursAgo))
    }

    private func nextTrip(leavingIn hoursAhead: Double) -> [TripLeg] {
        [TripMapTestLegs.leg("n1", from: "SDF", to: "ANC", start: hours(hoursAhead), hours: 6, tripId: "T2")]
    }

    func test_initStatus_aTripEnded3HoursAgo_isItsRecap() throws {
        let map = try XCTUnwrap(TripMap(status: status(legs: trip(endingHoursAgo: 3)), at: now))
        XCTAssertEqual(map.mode, .recap)
        XCTAssertEqual(map.legs.map(\.id), ["f1", "f2", "f3"])
    }

    func test_initStatus_aTripEnded30HoursAgo_isNoRecap() {
        XCTAssertNil(TripMap(status: status(legs: trip(endingHoursAgo: 30)), at: now), "nothing ahead either")
    }

    func test_initStatus_theNextTripLeavingWithin12Hours_winsOverTheRecap() throws {
        let map = try XCTUnwrap(TripMap(status: status(legs: trip(endingHoursAgo: 3) + nextTrip(leavingIn: 10)), at: now))
        XCTAssertEqual(map.mode, .nextTrip)
        XCTAssertEqual(map.legs.map(\.id), ["n1"])
    }

    func test_initStatus_theNextTripLeavingLater_leavesTheRecap() throws {
        let map = try XCTUnwrap(TripMap(status: status(legs: trip(endingHoursAgo: 3) + nextTrip(leavingIn: 14)), at: now))
        XCTAssertEqual(map.mode, .recap)
    }

    func test_initStatus_aNightAtHomeMidTrip_isNoRecap() {
        let legs = [
            TripMapTestLegs.leg("h1", from: "SDF", to: "CGN", start: hours(-30), hours: 8),
            TripMapTestLegs.leg("h2", from: "CGN", to: "SDF", start: hours(-14), hours: 9),
            TripMapTestLegs.leg("n", .home, start: hours(-5), hours: 15),
            TripMapTestLegs.leg("h3", from: "SDF", to: "DXB", start: hours(10), hours: 13),
        ]
        XCTAssertNotEqual(TripMap(status: status(legs: legs), at: now)?.mode, .recap)
    }

    func test_initStatus_atBaseNotYetHome_isNoRecap() {
        XCTAssertNotEqual(TripMap(status: status(legs: trip(endingHoursAgo: 3), displayStatus: .base), at: now)?.mode, .recap,
                          "a commuter at base still has the way home ahead")
    }

    func test_initStatus_aLaterTripUnderWay_isNoRecapOfTheLastOne() {
        let underWay = [
            TripMapTestLegs.leg("b1", from: "SDF", to: "CGN", start: hours(-16), hours: 7, tripId: "T2"),
            TripMapTestLegs.leg("b2", from: "CGN", to: "SDF", start: hours(-8), hours: 6, tripId: "T2"),
            TripMapTestLegs.leg("bn", .home, start: hours(-2), hours: 16, tripId: "T2"),
            TripMapTestLegs.leg("b3", from: "SDF", to: "DXB", start: hours(14), hours: 13, tripId: "T2"),
        ]
        XCTAssertNotEqual(TripMap(status: status(legs: trip(endingHoursAgo: 20) + underWay), at: now)?.mode, .recap,
                          "a night at home in the middle of the next trip")
    }

    func test_pilotLocation_afterTheRecapsTrip_isHome() throws {
        let map = try XCTUnwrap(TripMap(status: status(legs: trip(endingHoursAgo: 3)), at: now))
        XCTAssertEqual(map.pilotLocation(at: now)?.code, "SDF")
    }

    func test_dayCount_crewLusCount_elseCalendarDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let counted = TripMapTestLegs.europeTrip().enumerated().map { index, leg in
            index == 0 ? TripMapTestLegs.leg(leg.id, leg.type, from: leg.departureAirport, to: leg.arrivalAirport, start: leg.startTime,
                                             hours: leg.endTime.timeIntervalSince(leg.startTime) / 3600, tripTotalDays: 5) : leg
        }
        XCTAssertEqual(try XCTUnwrap(TripMapTestLegs.map(counted, at: now)).dayCount(in: calendar), 5)
        XCTAssertEqual(try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: now)).dayCount(in: calendar), 4,
                       "Friday 7 AM to Monday 7 AM in Louisville")
    }

    // MARK: - Status

    /// A status at home, as `PartnerStatusReceiver` publishes it.
    private func status(legs: [TripLeg], displayStatus: PilotDisplayStatus = .home) -> SharedPilotStatus {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return SharedPilotStatus(
            pilotId: "pilot", pilotFirstName: "Alex", homeAirportCode: "SDF", baseAirportCode: "SDF",
            homeTimezone: "America/Kentucky/Louisville", displayStatus: displayStatus, isSleeping: false, isHome: true,
            isInFlight: false, isOnDuty: false, currentAirport: "SDF", currentCity: "Louisville",
            currentTimezone: "America/Kentucky/Louisville", localTimeAtPilot: nil, currentLatitude: nil,
            currentLongitude: nil, currentFlightNumber: nil, currentFlightDeparture: nil, currentFlightArrival: nil,
            currentFlightDepartureTime: nil, currentFlightArrivalTime: nil, currentFlightArrivalTimezone: nil,
            homeArrivalTime: nil, homeArrivalLabel: nil, homeArrivalCity: nil, nextDepartureTime: nil,
            nextFlightNumber: nil, nextFlightDestination: nil, nextDepartureLabel: nil, lastTripEndDate: nil,
            lastTripDurationDays: nil, currentTripId: nil, tripDayNumber: nil, tripTotalDays: nil, upcomingCities: [],
            tripLegsJSON: try? encoder.encode(legs), quickStatus: nil, quickStatusIcon: nil, quickStatusExpiry: nil,
            flightDelayMinutes: nil, displayNameByPartnerJSON: nil, lastUpdated: now, appVersion: "test"
        )
    }
}
