//
//  SharedPilotStatus.swift
//  CrewLuv
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

    // MARK: - Current State

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

    // MARK: - Countdown Timers

    let homeArrivalTime: Date?       // When pilot arrives home
    let nextDepartureTime: Date?     // When pilot leaves next
    let nextFlightNumber: String?
    let nextFlightDestination: String?

    // MARK: - Trip Overview

    let currentTripId: String?
    let tripDayNumber: Int?          // Day 2 of 4
    let tripTotalDays: Int?
    let upcomingCities: [String]     // Next few cities

    // MARK: - Metadata

    let lastUpdated: Date
    let appVersion: String

    // MARK: - Computed Current Status

    /// Calculates the actual current status based on flight times and current time
    /// This provides real-time status updates even if the Duty app's boolean flags are stale
    var computedStatus: StatusType {
        let now = Date()

        // Priority 1: Check if currently in flight
        if let departureTime = currentFlightDepartureTime,
           let arrivalTime = currentFlightArrivalTime {
            if departureTime <= now && now < arrivalTime {
                return .inFlight
            }
        }

        // Priority 2: Check if at home
        // Pilot is home if homeArrivalTime has passed and next departure hasn't happened yet
        if let homeTime = homeArrivalTime {
            if homeTime <= now {
                // Check if next departure hasn't started yet
                if let nextDep = nextDepartureTime, nextDep > now {
                    return .home
                }
                // Or if there's no next departure scheduled
                if nextDepartureTime == nil {
                    return .home
                }
            }
        }

        // Priority 3: Check if on duty (has upcoming flights but not currently flying)
        if nextDepartureTime != nil || currentFlightDepartureTime != nil {
            return .onDuty
        }

        // Default: On layover
        return .onLayover
    }

    /// Status type enum for cleaner computed status
    enum StatusType {
        case home
        case inFlight
        case onDuty
        case onLayover

        var displayText: String {
            switch self {
            case .home: return "Home"
            case .inFlight: return "In Flight"
            case .onDuty: return "On Duty"
            case .onLayover: return "On Layover"
            }
        }

        var color: Color {
            switch self {
            case .home: return .green
            case .inFlight: return .blue
            case .onDuty, .onLayover: return .orange
            }
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

        if let homeArrivalTime = homeArrivalTime {
            record["homeArrivalTime"] = homeArrivalTime as CKRecordValue
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
            homeArrivalTime: record["homeArrivalTime"] as? Date,
            nextDepartureTime: record["nextDepartureTime"] as? Date,
            nextFlightNumber: record["nextFlightNumber"] as? String,
            nextFlightDestination: record["nextFlightDestination"] as? String,
            currentTripId: record["currentTripId"] as? String,
            tripDayNumber: record["tripDayNumber"] as? Int,
            tripTotalDays: record["tripTotalDays"] as? Int,
            upcomingCities: record["upcomingCities"] as? [String] ?? [],
            lastUpdated: lastUpdated,
            appVersion: appVersion
        )
    }
}
