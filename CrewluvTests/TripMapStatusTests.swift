//
//  TripMapStatusTests.swift
//  CrewluvTests
//
//  Which trip the status screen's map shows (TripMap+Status, moving map spec §5.1, §12): at home or base, the next
//  trip; a night at home or base in the middle of a trip, that trip under way; away, the trip under way, never the
//  trips chained after it.
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
struct TripMapStatusTests {

    private let start = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { start.addingTimeInterval(value * 3600) }

    // MARK: - A night at home or base mid-trip

    @Test func test_initStatus_aNightAtHomeMidTrip_isTheTripUnderWay() throws {
        let map = try #require(TripMap(status: status(.home, legs: tripThrough(.home)), at: hours(36)))

        #expect(map.mode == .onTrip)
        #expect(map.legs.map(\.id) == ["h1", "h2", "h3"], "the whole trip, flown legs too")
        #expect(map.pilotLocation(at: hours(36))?.code == "SDF", "the pilot is at home, where the last leg landed")
        #expect(map.nextFlight(after: hours(36))?.id == "h3")
    }

    @Test func test_initStatus_aNightAtBaseMidTrip_isTheTripUnderWay() throws {
        let atBase = status(.base, legs: tripThrough(.base), homeAirportCode: "LEX", baseAirportCode: "SDF")
        let map = try #require(TripMap(status: atBase, at: hours(36)))

        #expect(map.mode == .onTrip)
        #expect(map.legs.map(\.id) == ["h1", "h2", "h3"])
        #expect(map.pilotLocation(at: hours(36))?.code == "SDF")
    }

    // MARK: - A trip still ahead

    @Test func test_initStatus_atHomeBetweenTrips_isTheNextTrip() throws {
        let map = try #require(TripMap(status: status(.home, legs: lastTrip + tripThrough(.home)), at: hours(-24)))

        #expect(map.mode == .nextTrip)
        #expect(map.legs.map(\.id) == ["h1", "h2", "h3"], "only the trip ahead, not the one just flown")
        #expect(map.pilotLocation(at: hours(-24))?.code == "SDF")
    }

    @Test func test_initStatus_atBaseBeforeATrip_waitsAtBase() throws {
        let status = status(.base, legs: lastTrip + tripThrough(.base), homeAirportCode: "LEX")
        let map = try #require(TripMap(status: status, at: hours(-24)))

        #expect(map.mode == .nextTrip)
        #expect(map.isWaitingAtBase)
        #expect(map.pilotLocation(at: hours(-24))?.code == "SDF")
        #expect(map.activity(at: hours(-24))?.kind == .base)
    }

    @Test func test_initStatus_atHomeBeforeATrip_isntWaitingAtBase() throws {
        let status = status(.home, legs: lastTrip + tripThrough(.base), homeAirportCode: "LEX")
        let map = try #require(TripMap(status: status, at: hours(-24)))

        #expect(!map.isWaitingAtBase)
        #expect(map.activity(at: hours(-24))?.kind == .home)
    }

    // MARK: - Away, with the next trip hours later

    @Test func test_initStatus_onALayover_isTheTripUnderWay_notTheTripsChainedAfterIt() throws {
        let away = status(.layover, legs: commuterWeeks, homeAirportCode: "MCO")
        let map = try #require(TripMap(status: away, at: hours(0)))

        #expect(map.mode == .onTrip)
        #expect(map.legs.map(\.id) == ["s1-out", "s1-last", "drive-home", "commute-back"],
                "the trip and its commutes, though the next trip starts hours after them")
    }

    @Test func test_initStatus_onTheDriveHomeBetweenTrips_isTheDrive() throws {
        let driving = status(.drivingHome, legs: commuterWeeks, homeAirportCode: "MCO")
        let map = try #require(TripMap(status: driving, at: hours(13)))

        #expect(map.legs.map(\.id) == ["drive-home"])
    }

    // MARK: - Legs

    /// A commuter, home Orlando and base Louisville, home for a few hours between trips, so no gap between legs
    /// reaches a day: S1 ends at base, a drive home, a jumpseat back, T2, a jumpseat home, a drive to work, T3.
    private var commuterWeeks: [TripLeg] {
        [
            TripMapTestLegs.leg("s1-out", from: "SDF", to: "ANC", start: hours(-30), hours: 6, tripId: "S1"),
            TripMapTestLegs.leg("s1-layover", .layover, start: hours(-24), hours: 30, tripId: "S1"),
            TripMapTestLegs.leg("s1-last", from: "ANC", to: "SDF", start: hours(6), hours: 6, tripId: "S1"),
            TripMapTestLegs.leg("drive-home", .drive, from: "SDF", to: "MCO", start: hours(12.5), hours: 2, tripId: nil),
            TripMapTestLegs.leg("commute-back", from: "MCO", to: "SDF", start: hours(18), hours: 1, tripId: nil),
            TripMapTestLegs.leg("t2-out", from: "SDF", to: "PHL", start: hours(21), hours: 1.5, tripId: "T2"),
            TripMapTestLegs.leg("t2-back", from: "PHL", to: "SDF", start: hours(24), hours: 2, tripId: "T2"),
            TripMapTestLegs.leg("jumpseat-home", from: "SDF", to: "MCO", start: hours(28), hours: 1, tripId: nil),
            TripMapTestLegs.leg("t3-out", from: "SDF", to: "ANC", start: hours(42), hours: 6, tripId: "T3"),
        ]
    }

    /// SDF → CGN (8 h), a night in Cologne, CGN → SDF (9 h), a night at Louisville as `stop` (`.home` or `.base`),
    /// then SDF → DXB (13 h): one trip, T1, that passes through Louisville, as CrewLu sends it.
    private func tripThrough(_ stop: TripLeg.LegType) -> [TripLeg] {
        [
            TripMapTestLegs.leg("h1", from: "SDF", to: "CGN", start: hours(0), hours: 8, flightNumber: "UPS207"),
            TripMapTestLegs.leg("l1", .layover, start: hours(8), hours: 12),
            TripMapTestLegs.leg("h2", from: "CGN", to: "SDF", start: hours(20), hours: 9, flightNumber: "UPS208"),
            TripMapTestLegs.leg("n1", stop, start: hours(29), hours: 19),
            TripMapTestLegs.leg("h3", from: "SDF", to: "DXB", start: hours(48), hours: 13, flightNumber: "UPS209"),
        ]
    }

    /// T0, SDF → ANC and back, finished two days before T1.
    private var lastTrip: [TripLeg] {
        [
            TripMapTestLegs.leg("p1", from: "SDF", to: "ANC", start: hours(-96), hours: 6, tripId: "T0"),
            TripMapTestLegs.leg("p2", .layover, start: hours(-90), hours: 18, tripId: "T0"),
            TripMapTestLegs.leg("p3", from: "ANC", to: "SDF", start: hours(-72), hours: 6, tripId: "T0"),
        ]
    }

    // MARK: - Status

    /// A status as `PartnerStatusReceiver` publishes it: `displayStatus` resolved, and the legs as CrewLu encodes them.
    private func status(
        _ displayStatus: PilotDisplayStatus,
        legs: [TripLeg],
        homeAirportCode: String = "SDF",
        baseAirportCode: String = "SDF"
    ) -> SharedPilotStatus {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return SharedPilotStatus(
            pilotId: "pilot", pilotFirstName: "Alex", homeAirportCode: homeAirportCode, baseAirportCode: baseAirportCode,
            homeTimezone: "America/Kentucky/Louisville", displayStatus: displayStatus, isSleeping: false, isHome: true,
            isInFlight: false, isOnDuty: false, currentAirport: "SDF", currentCity: "Louisville",
            currentTimezone: "America/Kentucky/Louisville", localTimeAtPilot: nil, currentLatitude: nil,
            currentLongitude: nil, currentFlightNumber: nil, currentFlightDeparture: nil, currentFlightArrival: nil,
            currentFlightDepartureTime: nil, currentFlightArrivalTime: nil, currentFlightArrivalTimezone: nil,
            homeArrivalTime: nil, homeArrivalLabel: nil, homeArrivalCity: nil, nextDepartureTime: nil,
            nextFlightNumber: nil, nextFlightDestination: nil, nextDepartureLabel: nil, lastTripEndDate: nil,
            lastTripDurationDays: nil, currentTripId: nil, tripDayNumber: nil, tripTotalDays: nil, upcomingCities: [],
            tripLegsJSON: try? encoder.encode(legs), quickStatus: nil, quickStatusIcon: nil, quickStatusExpiry: nil,
            flightDelayMinutes: nil, displayNameByPartnerJSON: nil, lastUpdated: start, appVersion: "test"
        )
    }
}
