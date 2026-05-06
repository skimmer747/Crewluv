//
//  TripStateResolverGapTests.swift
//  CrewluvTests
//
//  End-of-trip decision: at-home vs. at-base vs. elsewhere(city:).
//  Regression suite for the "In Base" misreport bug.
//

import Testing
import Foundation
@testable import Crewluv

struct TripStateResolverGapTests {

    // MARK: - Fixture Helpers

    private static func arrivalLeg(
        arrival: String,
        arrivalCity: String?,
        endTime: Date,
        tripId: String = "trip-1"
    ) -> TripLeg {
        TripLeg(
            id: "flight-1",
            tripId: tripId,
            type: .flight,
            startTime: endTime.addingTimeInterval(-2 * 3600),
            endTime: endTime,
            airportCode: nil,
            city: nil,
            timezoneIdentifier: nil,
            arrivalTimezoneIdentifier: nil,
            flightNumber: "UA 100",
            departureAirport: "ORD",
            arrivalAirport: arrival,
            departureCity: "Chicago",
            arrivalCity: arrivalCity,
            tripDayNumber: 1,
            tripTotalDays: 1,
            delayMinutes: nil,
            airlineCode: "UA",
            label: nil
        )
    }

    // MARK: - End of Trip: Home

    @Test func test_resolveGap_endOfTripAtHome_returnsHome() {
        let now = Date()
        let endedAt = now.addingTimeInterval(-3600) // landed an hour ago
        let leg = Self.arrivalLeg(arrival: "MCO", arrivalCity: "Orlando", endTime: endedAt)

        let state = TripStateResolver.resolve(
            legs: [leg],
            homeAirportCode: "MCO",
            baseAirportCode: "SDF",
            at: now
        )

        #expect(state?.displayStatus == .home)
        #expect(state?.currentAirport == "MCO")
    }

    // MARK: - End of Trip: Base (commuter — home != base)

    @Test func test_resolveGap_endOfTripAtBase_baseDiffersFromHome_returnsBase() {
        let now = Date()
        let endedAt = now.addingTimeInterval(-3600)
        let leg = Self.arrivalLeg(arrival: "SDF", arrivalCity: "Louisville", endTime: endedAt)

        let state = TripStateResolver.resolve(
            legs: [leg],
            homeAirportCode: "MCO",
            baseAirportCode: "SDF",
            at: now
        )

        #expect(state?.displayStatus == .base)
        #expect(state?.currentAirport == "SDF")
    }

    // MARK: - End of Trip: Elsewhere (the bug case)

    @Test func test_resolveGap_endOfTripElsewhere_returnsElsewhereWithCity() {
        let now = Date()
        let endedAt = now.addingTimeInterval(-3600)
        let leg = Self.arrivalLeg(arrival: "DFW", arrivalCity: "Dallas", endTime: endedAt)

        let state = TripStateResolver.resolve(
            legs: [leg],
            homeAirportCode: "MCO",
            baseAirportCode: "SDF",
            at: now
        )

        #expect(state?.displayStatus == .elsewhere(city: "Dallas"))
        #expect(state?.currentAirport == "DFW")
    }

    @Test func test_resolveGap_endOfTripElsewhere_baseUnknown_stillElsewhereNeverBase() {
        let now = Date()
        let endedAt = now.addingTimeInterval(-3600)
        let leg = Self.arrivalLeg(arrival: "DFW", arrivalCity: "Dallas", endTime: endedAt)

        // Old Duty build: no baseAirportCode in the record.
        let state = TripStateResolver.resolve(
            legs: [leg],
            homeAirportCode: "MCO",
            baseAirportCode: nil,
            at: now
        )

        #expect(state?.displayStatus == .elsewhere(city: "Dallas"))
        if case .base = state?.displayStatus {
            Issue.record("Must never silently fall back to .base when base is unknown")
        }
    }

    // MARK: - End of Trip: Home == Base (non-commuter)

    @Test func test_resolveGap_endOfTripAtBase_homeEqualsBase_returnsHome() {
        let now = Date()
        let endedAt = now.addingTimeInterval(-3600)
        let leg = Self.arrivalLeg(arrival: "SDF", arrivalCity: "Louisville", endTime: endedAt)

        // Non-commuter: home and base are the same airport. The home check fires first.
        let state = TripStateResolver.resolve(
            legs: [leg],
            homeAirportCode: "SDF",
            baseAirportCode: "SDF",
            at: now
        )

        #expect(state?.displayStatus == .home)
    }

    // MARK: - Case-Insensitive Compare

    @Test func test_resolveGap_caseInsensitiveAirportMatch_returnsBase() {
        let now = Date()
        let endedAt = now.addingTimeInterval(-3600)
        let leg = Self.arrivalLeg(arrival: "sdf", arrivalCity: "Louisville", endTime: endedAt)

        let state = TripStateResolver.resolve(
            legs: [leg],
            homeAirportCode: "MCO",
            baseAirportCode: "SDF",
            at: now
        )

        #expect(state?.displayStatus == .base)
    }
}
