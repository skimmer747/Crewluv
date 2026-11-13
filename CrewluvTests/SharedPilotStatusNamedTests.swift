//
//  SharedPilotStatusNamedTests.swift
//  CrewluvTests
//
//  The status under the name this partner calls the pilot
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
struct SharedPilotStatusNamedTests {

    @Test func test_named_changesOnlyThePilotsName() {
        for status in [SharedPilotStatus.demo, Self.everyFieldSet] {
            let named = status.named("Dad")

            #expect(named.pilotFirstName == "Dad")
            let before = Mirror(reflecting: status).children.filter { $0.label != "pilotFirstName" }
            let after = Mirror(reflecting: named).children.filter { $0.label != "pilotFirstName" }
            #expect(before.map { $0.label } == after.map { $0.label })
            for (field, copy) in zip(before, after) {
                #expect(String(describing: field.value) == String(describing: copy.value), "\(field.label ?? "?")")
            }
        }
    }

    /// A status with every field set, so a copy that drops one shows.
    private static let everyFieldSet = SharedPilotStatus(
        pilotId: "pilot", pilotFirstName: "Alex", homeAirportCode: "SDF", baseAirportCode: "ONT",
        homeTimezone: "America/Kentucky/Louisville", displayStatus: .inFlight, isSleeping: true, isHome: true,
        isInFlight: true, isOnDuty: true, currentAirport: "ONT", currentCity: "Ontario, CA",
        currentTimezone: "America/Los_Angeles", localTimeAtPilot: "11:04 AM", currentLatitude: 34.05,
        currentLongitude: -117.6, currentFlightNumber: "5X 123", currentFlightDeparture: "ONT",
        currentFlightArrival: "SDF", currentFlightDepartureTime: Date(timeIntervalSince1970: 1),
        currentFlightArrivalTime: Date(timeIntervalSince1970: 2), currentFlightArrivalTimezone: "America/New_York",
        homeArrivalTime: Date(timeIntervalSince1970: 3), homeArrivalLabel: "Back Home In", homeArrivalCity: "Louisville",
        nextDepartureTime: Date(timeIntervalSince1970: 4), nextFlightNumber: "5X 456", nextFlightDestination: "ANC",
        nextDepartureLabel: "Leaves From", lastTripEndDate: Date(timeIntervalSince1970: 5), lastTripDurationDays: 4,
        currentTripId: "trip", tripDayNumber: 2, tripTotalDays: 4, upcomingCities: ["Anchorage"],
        tripLegsJSON: Data([1]), quickStatus: "Call Me", quickStatusIcon: "phone.fill",
        quickStatusExpiry: Date(timeIntervalSince1970: 6), flightDelayMinutes: 15, displayNameByPartnerJSON: Data([2]),
        lastUpdated: Date(timeIntervalSince1970: 7), appVersion: "3.0"
    )
}
