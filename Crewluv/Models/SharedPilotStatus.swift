//
//  SharedPilotStatus.swift
//  CrewLuve
//
//  Shared data model for pilot status
//  Duplicated from Duty app for independence
//

import Foundation
import CloudKit
import SwiftUI

/// Lightweight status data safe to share with partner via CloudKit
/// Designed for CKRecord conversion, NOT SwiftData
/// Privacy-conscious: no crew names, hotel details, or pay info
struct SharedPilotStatus: Codable, Sendable {

    // MARK: - Record Type

    static let recordType = "SharedPilotStatus"

    // MARK: - Identification

    let pilotId: String              // PilotInfo.id.uuidString
    let pilotFirstName: String       // First name only for privacy
    let homeAirportCode: String?     // Pilot's actual home airport (may differ from base)
    let homeTimezone: String?        // Timezone identifier for home airport

    // MARK: - Current State

    let displayStatus: String        // "Home", "In Flight", "Turn", or "Layover"
    let isSleeping: Bool             // User-toggled sleeping indicator

    // DEPRECATED: Use displayStatus instead
    let isHome: Bool
    let isInFlight: Bool
    let isOnDuty: Bool

    // MARK: - Location Info

    let currentAirport: String?      // IATA code
    let currentCity: String?         // From AirportDataProvider
    let currentTimezone: String?     // Timezone identifier
    let localTimeAtPilot: String?    // Pre-formatted local time

    // MARK: - Flight Position (for in-flight tracking)

    let currentLatitude: Double?
    let currentLongitude: Double?
    let currentFlightNumber: String?
    let currentFlightDeparture: String?
    let currentFlightArrival: String?
    let currentFlightDepartureTime: Date?
    let currentFlightArrivalTime: Date?
    let currentFlightArrivalTimezone: String?

    // MARK: - Countdown Timers

    let homeArrivalTime: Date?       // When pilot arrives home
    let homeArrivalLabel: String?    // "Back Home In" or "{City} In" based on trip ending airport
    let homeArrivalCity: String?     // City name for footer display (home-bound trips only)
    let nextDepartureTime: Date?     // When pilot leaves next
    let nextFlightNumber: String?
    let nextFlightDestination: String?
    let nextDepartureLabel: String?  // "Leaves From (Orlando)" for pre-trip jumpseats

    // MARK: - Last Trip (for "at home" view)

    let lastTripEndDate: Date?
    let lastTripDurationDays: Int?

    // MARK: - Trip Overview

    let currentTripId: String?
    let tripDayNumber: Int?          // Day 2 of 4
    let tripTotalDays: Int?
    let upcomingCities: [String]     // Next few cities

    // MARK: - Trip Schedule

    let tripLegsJSON: Data?      // JSON-encoded [TripLeg], nil for old Duty versions

    // MARK: - Quick Status

    let quickStatus: String?          // "Call Me", "Free to Talk", etc.
    let quickStatusIcon: String?      // SF Symbol name
    let quickStatusExpiry: Date?      // When it auto-clears (nil = no limit)

    // MARK: - Flight Delay

    let flightDelayMinutes: Int?      // Delay duration in minutes (nil = no delay)

    var hasFlightDelay: Bool { (flightDelayMinutes ?? 0) > 0 }

    // MARK: - Per-Partner Display Names

    /// JSON-encoded [String: String] dictionary mapping CloudKit user record names
    /// to the display name the pilot chose for each partner.
    ///
    /// **Privacy note:** The keys are CloudKit record names (opaque identifiers for each
    /// share participant). A partner with access to the raw record data could see other
    /// partners' record-name keys, though NOT their real names or Apple IDs.
    ///
    /// **Why this is acceptable today:**
    /// - CloudKit zone-level ACLs restrict access to participants the pilot explicitly
    ///   invited via share link; only accepted participants can fetch the record.
    /// - CrewLuve is read-only — it never writes this field. The Duty app (pilot side)
    ///   controls the serialization format.
    ///
    /// TODO: Migrate the Duty app to write a single viewer-scoped `viewerDisplayName`
    /// string per share participant (or use a non-identifying stable token as the key)
    /// so the record never contains the full partner-ID→name map. Track in Duty backlog.
    let displayNameByPartnerJSON: Data?

    /// Deserializes `displayNameByPartnerJSON` into a [recordName: displayName] dictionary.
    /// The caller (PartnerStatusReceiver) looks up the current user's CKRecord name to
    /// resolve only their own display name — other entries are ignored at runtime.
    ///
    /// See privacy note on `displayNameByPartnerJSON` for why a multi-key map is stored today.
    var displayNameByPartner: [String: String] {
        guard let data = displayNameByPartnerJSON else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    /// Resolve the display name for a specific partner by their CloudKit user record name.
    /// Falls back to the pilot's actual first name when no per-partner name is set.
    func displayName(for partnerId: String) -> String {
        if let name = displayNameByPartner[partnerId], !name.isEmpty {
            return name
        }
        return pilotFirstName
    }

    // MARK: - Metadata

    let lastUpdated: Date
    let appVersion: String

    // MARK: - Trip Legs Convenience

    var tripLegs: [TripLeg] {
        guard let data = tripLegsJSON else {
            debugLog("[TripLegs] tripLegsJSON is nil")
            return []
        }
        debugLog("[TripLegs] tripLegsJSON present: \(data.count) bytes")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        do {
            var legs = try decoder.decode([TripLeg].self, from: data)
            legs = Self.adjustLayoversForOverlappingFlights(legs)
            let typeBreakdown = Dictionary(grouping: legs, by: { $0.type.rawValue }).mapValues(\.count)
            debugLog("[TripLegs] Decoded \(legs.count) legs, breakdown: \(typeBreakdown)")
            return legs
        } catch {
            debugLog("[TripLegs] ❌ Decode FAILED: \(error)")
            return []
        }
    }

    var hasTripLegs: Bool {
        !tripLegs.isEmpty
    }

    /// Truncates layover/home legs when a flight departs during them.
    ///
    /// When a pilot books a personal flight (e.g. jumpseat) that departs before
    /// a scheduled layover ends, the layover's `endTime` is adjusted to the
    /// earliest overlapping flight's `startTime` so downstream views show the
    /// correct shorter duration.
    private static func adjustLayoversForOverlappingFlights(_ legs: [TripLeg]) -> [TripLeg] {
        let flights = legs.filter { $0.type == .flight }
        guard !flights.isEmpty else { return legs }

        return legs.map { leg in
            guard leg.type == .layover || leg.type == .home || leg.type == .base else { return leg }

            guard let earliest = flights
                .filter({ $0.startTime > leg.startTime && $0.startTime < leg.endTime })
                .min(by: { $0.startTime < $1.startTime })
            else { return leg }

            return TripLeg(
                id: leg.id,
                tripId: leg.tripId,
                type: leg.type,
                startTime: leg.startTime,
                endTime: earliest.startTime,
                airportCode: leg.airportCode,
                city: leg.city,
                timezoneIdentifier: leg.timezoneIdentifier,
                arrivalTimezoneIdentifier: leg.arrivalTimezoneIdentifier,
                flightNumber: leg.flightNumber,
                departureAirport: leg.departureAirport,
                arrivalAirport: leg.arrivalAirport,
                departureCity: leg.departureCity,
                arrivalCity: leg.arrivalCity,
                tripDayNumber: leg.tripDayNumber,
                tripTotalDays: leg.tripTotalDays,
                delayMinutes: leg.delayMinutes,
                airlineCode: leg.airlineCode,
                label: leg.label
            )
        }
    }

    // MARK: - CKRecord Conversion

    /// Convert to CloudKit record for storage in PartnerBeaconZone
    func toCKRecord(in zone: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: pilotId, zoneID: zone)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        // Encode all fields to record
        record["pilotId"] = pilotId as CKRecordValue
        record["pilotFirstName"] = pilotFirstName as CKRecordValue
        if let homeAirportCode = homeAirportCode {
            record["homeAirportCode"] = homeAirportCode as CKRecordValue
        }
        if let homeTimezone = homeTimezone {
            record["homeTimezone"] = homeTimezone as CKRecordValue
        }
        record["displayStatus"] = displayStatus as CKRecordValue
        record["isSleeping"] = (isSleeping ? 1 : 0) as CKRecordValue
        record["isHome"] = (isHome ? 1 : 0) as CKRecordValue
        record["isInFlight"] = (isInFlight ? 1 : 0) as CKRecordValue
        record["isOnDuty"] = (isOnDuty ? 1 : 0) as CKRecordValue

        if let currentAirport = currentAirport {
            record["currentAirport"] = currentAirport as CKRecordValue
        }
        if let currentCity = currentCity {
            record["currentCity"] = currentCity as CKRecordValue
        }
        if let currentTimezone = currentTimezone {
            record["currentTimezone"] = currentTimezone as CKRecordValue
        }
        if let localTimeAtPilot = localTimeAtPilot {
            record["localTimeAtPilot"] = localTimeAtPilot as CKRecordValue
        }

        if let currentLatitude = currentLatitude {
            record["currentLatitude"] = currentLatitude as CKRecordValue
        }
        if let currentLongitude = currentLongitude {
            record["currentLongitude"] = currentLongitude as CKRecordValue
        }
        if let currentFlightNumber = currentFlightNumber {
            record["currentFlightNumber"] = currentFlightNumber as CKRecordValue
        }
        if let currentFlightDeparture = currentFlightDeparture {
            record["currentFlightDeparture"] = currentFlightDeparture as CKRecordValue
        }
        if let currentFlightArrival = currentFlightArrival {
            record["currentFlightArrival"] = currentFlightArrival as CKRecordValue
        }
        if let currentFlightDepartureTime = currentFlightDepartureTime {
            record["currentFlightDepartureTime"] = currentFlightDepartureTime as CKRecordValue
        }
        if let currentFlightArrivalTime = currentFlightArrivalTime {
            record["currentFlightArrivalTime"] = currentFlightArrivalTime as CKRecordValue
        }
        if let currentFlightArrivalTimezone = currentFlightArrivalTimezone {
            record["currentFlightArrivalTimezone"] = currentFlightArrivalTimezone as CKRecordValue
        }

        if let homeArrivalTime = homeArrivalTime {
            record["homeArrivalTime"] = homeArrivalTime as CKRecordValue
        }
        if let homeArrivalLabel = homeArrivalLabel {
            record["homeArrivalLabel"] = homeArrivalLabel as CKRecordValue
        }
        if let nextDepartureTime = nextDepartureTime {
            record["nextDepartureTime"] = nextDepartureTime as CKRecordValue
        }
        if let nextFlightNumber = nextFlightNumber {
            record["nextFlightNumber"] = nextFlightNumber as CKRecordValue
        }
        if let nextFlightDestination = nextFlightDestination {
            record["nextFlightDestination"] = nextFlightDestination as CKRecordValue
        }
        if let nextDepartureLabel = nextDepartureLabel {
            record["nextDepartureLabel"] = nextDepartureLabel as CKRecordValue
        }

        if let lastTripEndDate = lastTripEndDate {
            record["lastTripEndDate"] = lastTripEndDate as CKRecordValue
        }
        if let lastTripDurationDays = lastTripDurationDays {
            record["lastTripDurationDays"] = lastTripDurationDays as CKRecordValue
        }

        if let currentTripId = currentTripId {
            record["currentTripId"] = currentTripId as CKRecordValue
        }
        if let tripDayNumber = tripDayNumber {
            record["tripDayNumber"] = tripDayNumber as CKRecordValue
        }
        if let tripTotalDays = tripTotalDays {
            record["tripTotalDays"] = tripTotalDays as CKRecordValue
        }

        record["upcomingCities"] = upcomingCities as CKRecordValue
        if let tripLegsJSON = tripLegsJSON {
            record["tripLegsJSON"] = tripLegsJSON as CKRecordValue
        }
        if let quickStatus = quickStatus {
            record["quickStatus"] = quickStatus as CKRecordValue
        }
        if let quickStatusIcon = quickStatusIcon {
            record["quickStatusIcon"] = quickStatusIcon as CKRecordValue
        }
        if let quickStatusExpiry = quickStatusExpiry {
            record["quickStatusExpiry"] = quickStatusExpiry as CKRecordValue
        }
        if let flightDelayMinutes = flightDelayMinutes {
            record["flightDelayMinutes"] = flightDelayMinutes as CKRecordValue
        }
        if let displayNameByPartnerJSON = displayNameByPartnerJSON {
            record["displayNameByPartnerJSON"] = displayNameByPartnerJSON as CKRecordValue
        }
        record["lastUpdated"] = lastUpdated as CKRecordValue
        record["appVersion"] = appVersion as CKRecordValue

        return record
    }

    /// Create from CloudKit record
    static func from(record: CKRecord) -> SharedPilotStatus? {
        guard let pilotId = record["pilotId"] as? String,
              let pilotFirstName = record["pilotFirstName"] as? String,
              let lastUpdated = record["lastUpdated"] as? Date,
              let appVersion = record["appVersion"] as? String else {
            return nil
        }

        return SharedPilotStatus(
            pilotId: pilotId,
            pilotFirstName: pilotFirstName,
            homeAirportCode: record["homeAirportCode"] as? String,
            homeTimezone: record["homeTimezone"] as? String,
            displayStatus: record["displayStatus"] as? String ?? "Home",
            isSleeping: (record["isSleeping"] as? Int ?? 0) == 1,
            isHome: (record["isHome"] as? Int ?? 0) == 1,
            isInFlight: (record["isInFlight"] as? Int ?? 0) == 1,
            isOnDuty: (record["isOnDuty"] as? Int ?? 0) == 1,
            currentAirport: record["currentAirport"] as? String,
            currentCity: record["currentCity"] as? String,
            currentTimezone: record["currentTimezone"] as? String,
            localTimeAtPilot: record["localTimeAtPilot"] as? String,
            currentLatitude: record["currentLatitude"] as? Double,
            currentLongitude: record["currentLongitude"] as? Double,
            currentFlightNumber: record["currentFlightNumber"] as? String,
            currentFlightDeparture: record["currentFlightDeparture"] as? String,
            currentFlightArrival: record["currentFlightArrival"] as? String,
            currentFlightDepartureTime: record["currentFlightDepartureTime"] as? Date,
            currentFlightArrivalTime: record["currentFlightArrivalTime"] as? Date,
            currentFlightArrivalTimezone: record["currentFlightArrivalTimezone"] as? String,
            homeArrivalTime: record["homeArrivalTime"] as? Date,
            homeArrivalLabel: record["homeArrivalLabel"] as? String,
            homeArrivalCity: record["homeArrivalCity"] as? String,
            nextDepartureTime: record["nextDepartureTime"] as? Date,
            nextFlightNumber: record["nextFlightNumber"] as? String,
            nextFlightDestination: record["nextFlightDestination"] as? String,
            nextDepartureLabel: record["nextDepartureLabel"] as? String,
            lastTripEndDate: record["lastTripEndDate"] as? Date,
            lastTripDurationDays: record["lastTripDurationDays"] as? Int,
            currentTripId: record["currentTripId"] as? String,
            tripDayNumber: record["tripDayNumber"] as? Int,
            tripTotalDays: record["tripTotalDays"] as? Int,
            upcomingCities: record["upcomingCities"] as? [String] ?? [],
            tripLegsJSON: record["tripLegsJSON"] as? Data,
            quickStatus: record["quickStatus"] as? String,
            quickStatusIcon: record["quickStatusIcon"] as? String,
            quickStatusExpiry: record["quickStatusExpiry"] as? Date,
            flightDelayMinutes: record["flightDelayMinutes"] as? Int,
            displayNameByPartnerJSON: record["displayNameByPartnerJSON"] as? Data,
            lastUpdated: lastUpdated,
            appVersion: appVersion
        )
    }
}
