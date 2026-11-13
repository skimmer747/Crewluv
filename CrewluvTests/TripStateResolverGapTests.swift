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

    // MARK: - Mid-Trip Gap (Turn)

    /// Regression guard: a gap between two flights of the same trip must remain `.turn`,
    /// not get reclassified by the new home/base/elsewhere branch (which is end-of-trip only).
    @Test func test_resolveGap_midTripGap_returnsTurn() {
        let now = Date()
        let firstArrival = now.addingTimeInterval(-3600)        // landed an hour ago at DFW
        let secondDeparture = now.addingTimeInterval(2 * 3600)  // next leg leaves in 2 hours

        let firstLeg = TripLeg(
            id: "flight-1",
            tripId: "trip-1",
            type: .flight,
            startTime: firstArrival.addingTimeInterval(-2 * 3600),
            endTime: firstArrival,
            airportCode: nil,
            city: nil,
            timezoneIdentifier: nil,
            arrivalTimezoneIdentifier: nil,
            flightNumber: "UA 100",
            departureAirport: "ORD",
            arrivalAirport: "DFW",
            departureCity: "Chicago",
            arrivalCity: "Dallas",
            tripDayNumber: 1,
            tripTotalDays: 1,
            delayMinutes: nil,
            airlineCode: "UA",
            label: nil
        )

        let secondLeg = TripLeg(
            id: "flight-2",
            tripId: "trip-1",
            type: .flight,
            startTime: secondDeparture,
            endTime: secondDeparture.addingTimeInterval(2 * 3600),
            airportCode: nil,
            city: nil,
            timezoneIdentifier: nil,
            arrivalTimezoneIdentifier: nil,
            flightNumber: "UA 200",
            departureAirport: "DFW",
            arrivalAirport: "LAX",
            departureCity: "Dallas",
            arrivalCity: "Los Angeles",
            tripDayNumber: 1,
            tripTotalDays: 1,
            delayMinutes: nil,
            airlineCode: "UA",
            label: nil
        )

        let state = TripStateResolver.resolve(
            legs: [firstLeg, secondLeg],
            homeAirportCode: "MCO",
            baseAirportCode: "SDF",
            at: now
        )

        #expect(state?.displayStatus == .turn)
        #expect(state?.currentAirport == "DFW")
    }

    // MARK: - Between Trips at Home: Jumpseat Commuter (regression)

    /// Fixture: a flight/jumpseat that *departs* `from` and *arrives* `to`.
    private static func flightLeg(
        id: String,
        tripId: String?,
        from: String,
        to: String,
        arrivalCity: String?,
        startTime: Date,
        endTime: Date
    ) -> TripLeg {
        TripLeg(
            id: id,
            tripId: tripId,
            type: .flight,
            startTime: startTime,
            endTime: endTime,
            airportCode: nil,
            city: nil,
            timezoneIdentifier: nil,
            arrivalTimezoneIdentifier: nil,
            flightNumber: id,
            departureAirport: from,
            arrivalAirport: to,
            departureCity: nil,
            arrivalCity: arrivalCity,
            tripDayNumber: nil,
            tripTotalDays: nil,
            delayMinutes: nil,
            airlineCode: nil,
            label: nil
        )
    }

    /// A jumpseat commuter (home != base) who has flown home and is waiting to
    /// leave for the next trip. His ride home is a standalone jumpseat with no
    /// trip id, so the gap to tonight's trip can't be linked by trip id. The
    /// resolver must still report `.home` — not a mid-trip `.turn` — otherwise
    /// the UI suppresses "Leaves In" and shows a bogus "Back Home In" countdown
    /// while the pilot is sitting at home.
    @Test func test_resolveGap_jumpseatedHomeBeforeNextTrip_returnsHome() {
        let now = Date()

        // Jumpseated home to PHL 6h ago — standalone, no trip id.
        let jumpseatHome = Self.flightLeg(
            id: "js-home",
            tripId: nil,
            from: "SDF",
            to: "PHL",
            arrivalCity: "Philadelphia",
            startTime: now.addingTimeInterval(-8 * 3600),
            endTime: now.addingTimeInterval(-6 * 3600)
        )

        // Tonight's trip departs from home (PHL) in 5h — gap < 24h, different trip.
        let nextTripFlight = Self.flightLeg(
            id: "UPS1189",
            tripId: "trip-tonight",
            from: "PHL",
            to: "SDF",
            arrivalCity: "Louisville",
            startTime: now.addingTimeInterval(5 * 3600),
            endTime: now.addingTimeInterval(7 * 3600)
        )

        let state = TripStateResolver.resolve(
            legs: [jumpseatHome, nextTripFlight],
            homeAirportCode: "PHL",
            baseAirportCode: "SDF",
            at: now
        )

        #expect(state?.displayStatus == .home)
        #expect(state?.currentAirport == "PHL")
    }

    /// Mirror of the above for a commuter who jumpseated to *base* and is waiting
    /// for the next trip: he is settled at base, not on a turn.
    @Test func test_resolveGap_jumpseatedToBaseBeforeNextTrip_returnsBase() {
        let now = Date()

        let jumpseatToBase = Self.flightLeg(
            id: "js-base",
            tripId: nil,
            from: "PHL",
            to: "SDF",
            arrivalCity: "Louisville",
            startTime: now.addingTimeInterval(-8 * 3600),
            endTime: now.addingTimeInterval(-6 * 3600)
        )

        let nextTripFlight = Self.flightLeg(
            id: "UPS1070",
            tripId: "trip-tonight",
            from: "SDF",
            to: "EWR",
            arrivalCity: "Newark",
            startTime: now.addingTimeInterval(5 * 3600),
            endTime: now.addingTimeInterval(7 * 3600)
        )

        let state = TripStateResolver.resolve(
            legs: [jumpseatToBase, nextTripFlight],
            homeAirportCode: "PHL",
            baseAirportCode: "SDF",
            at: now
        )

        #expect(state?.displayStatus == .base)
        #expect(state?.currentAirport == "SDF")
    }

    /// Guard for the jumpseat-home fix: a *same-trip* turn that happens to pass
    /// through the home airport must remain `.turn` (the pilot is mid-duty, not
    /// home between trips). The shared, non-nil trip id is what distinguishes it.
    @Test func test_resolveGap_sameTripTurnThroughHome_staysTurn() {
        let now = Date()

        let inbound = Self.flightLeg(
            id: "UPS10",
            tripId: "trip-1",
            from: "SDF",
            to: "PHL",
            arrivalCity: "Philadelphia",
            startTime: now.addingTimeInterval(-3 * 3600),
            endTime: now.addingTimeInterval(-3600)
        )

        let outbound = Self.flightLeg(
            id: "UPS20",
            tripId: "trip-1",
            from: "PHL",
            to: "SDF",
            arrivalCity: "Louisville",
            startTime: now.addingTimeInterval(2 * 3600),
            endTime: now.addingTimeInterval(4 * 3600)
        )

        let state = TripStateResolver.resolve(
            legs: [inbound, outbound],
            homeAirportCode: "PHL",
            baseAirportCode: "SDF",
            at: now
        )

        #expect(state?.displayStatus == .turn)
        #expect(state?.currentAirport == "PHL")
    }

    /// Same guard for the base airport: a mid-trip turn that lands at the pilot's
    /// base and continues the same trip must stay `.turn`, never `.base`/`.home`.
    /// He is mid-duty passing through base, not settled there between trips.
    @Test func test_resolveGap_sameTripTurnThroughBase_staysTurn() {
        let now = Date()

        let inbound = Self.flightLeg(
            id: "UPS30",
            tripId: "trip-1",
            from: "ORD",
            to: "SDF",
            arrivalCity: "Louisville",
            startTime: now.addingTimeInterval(-3 * 3600),
            endTime: now.addingTimeInterval(-3600)
        )

        let outbound = Self.flightLeg(
            id: "UPS40",
            tripId: "trip-1",
            from: "SDF",
            to: "EWR",
            arrivalCity: "Newark",
            startTime: now.addingTimeInterval(2 * 3600),
            endTime: now.addingTimeInterval(4 * 3600)
        )

        let state = TripStateResolver.resolve(
            legs: [inbound, outbound],
            homeAirportCode: "PHL",
            baseAirportCode: "SDF",
            at: now
        )

        #expect(state?.displayStatus == .turn)
        #expect(state?.currentAirport == "SDF")
    }
}
