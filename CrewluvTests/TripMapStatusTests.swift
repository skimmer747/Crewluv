//
//  TripMapStatusTests.swift
//  CrewluvTests
//
//  Which trip the status screen's map shows (TripMap+Status, moving map spec §5.1, §12): at home or base, the next
//  trip; a night at home or base in the middle of a trip, that trip under way.
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
        #expect(map.pilotLocation(at: hours(36))?.code == "SDF", "the heart sits at home, where the last leg landed")
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

    // MARK: - Legs

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
