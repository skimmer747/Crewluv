//
//  SharedPilotStatusCKRecordTests.swift
//  CrewluvTests
//
//  CKRecord boundary contract for `baseAirportCode`:
//    - Present field round-trips intact.
//    - Absent field decodes to `nil` (old-Duty backward compatibility).
//

import Testing
import Foundation
import CloudKit
@testable import Crewluv

struct SharedPilotStatusCKRecordTests {

    private static let zoneID = CKRecordZone.ID(zoneName: "PartnerBeaconZone", ownerName: "test-owner")

    private static func minimalStatus(baseAirportCode: String?) -> SharedPilotStatus {
        SharedPilotStatus(
            pilotId: "pilot-1",
            pilotFirstName: "Todd",
            homeAirportCode: "MCO",
            baseAirportCode: baseAirportCode,
            homeTimezone: "America/New_York",
            displayStatus: .home,
            isSleeping: false,
            isHome: true,
            isInFlight: false,
            isOnDuty: false,
            currentAirport: "MCO",
            currentCity: "Orlando",
            currentTimezone: "America/New_York",
            localTimeAtPilot: nil,
            currentLatitude: nil,
            currentLongitude: nil,
            currentFlightNumber: nil,
            currentFlightDeparture: nil,
            currentFlightArrival: nil,
            currentFlightDepartureTime: nil,
            currentFlightArrivalTime: nil,
            currentFlightArrivalTimezone: nil,
            homeArrivalTime: nil,
            homeArrivalLabel: nil,
            homeArrivalCity: nil,
            nextDepartureTime: nil,
            nextFlightNumber: nil,
            nextFlightDestination: nil,
            nextDepartureLabel: nil,
            lastTripEndDate: nil,
            lastTripDurationDays: nil,
            currentTripId: nil,
            tripDayNumber: nil,
            tripTotalDays: nil,
            upcomingCities: [],
            tripLegsJSON: nil,
            quickStatus: nil,
            quickStatusIcon: nil,
            quickStatusExpiry: nil,
            flightDelayMinutes: nil,
            displayNameByPartnerJSON: nil,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000),
            appVersion: "test"
        )
    }

    // MARK: - Round-Trip

    @Test func test_ckRecord_roundTrip_preservesBaseAirportCode() {
        let original = Self.minimalStatus(baseAirportCode: "SDF")

        let record = original.toCKRecord(in: Self.zoneID)
        let decoded = SharedPilotStatus.from(record: record)

        #expect(decoded?.baseAirportCode == "SDF")
        #expect(decoded?.homeAirportCode == "MCO")
    }

    // MARK: - Backward Compatibility (old Duty without the field)

    @Test func test_ckRecord_decode_missingBaseAirportCode_isNil() {
        // Build a CKRecord that simulates an old-Duty write: every required field set,
        // but `baseAirportCode` deliberately absent.
        let recordID = CKRecord.ID(recordName: "pilot-legacy", zoneID: Self.zoneID)
        let record = CKRecord(recordType: SharedPilotStatus.recordType, recordID: recordID)
        record["pilotId"] = "pilot-legacy" as CKRecordValue
        record["pilotFirstName"] = "Legacy" as CKRecordValue
        record["homeAirportCode"] = "MCO" as CKRecordValue
        record["displayStatus"] = "Home" as CKRecordValue
        record["lastUpdated"] = Date(timeIntervalSince1970: 1_700_000_000) as CKRecordValue
        record["appVersion"] = "old-duty" as CKRecordValue

        let decoded = SharedPilotStatus.from(record: record)

        #expect(decoded != nil)
        #expect(decoded?.baseAirportCode == nil)
    }

    // MARK: - Nil Round-Trip (new build, base unconfigured)

    @Test func test_ckRecord_roundTrip_nilBaseAirportCode_staysNil() {
        let original = Self.minimalStatus(baseAirportCode: nil)

        let record = original.toCKRecord(in: Self.zoneID)
        // Verify the encoder did not write a key for the nil value.
        #expect(record["baseAirportCode"] == nil)

        let decoded = SharedPilotStatus.from(record: record)
        #expect(decoded?.baseAirportCode == nil)
    }
}
