//
//  TripLeg.swift
//  CrewLuve
//
//  A single segment of a pilot's trip schedule
//

import Foundation

struct TripLeg: Codable, Sendable {
    enum LegType: String, Codable, Sendable {
        case flight, turn, layover, home, base
        case drive                       // ground commute (base <-> home)
        case reserve, hotStandby, event  // future
        case unknown                     // forward compat

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = LegType(rawValue: raw) ?? .unknown
        }
    }

    let id: String
    let tripId: String?
    let type: LegType
    let startTime: Date
    let endTime: Date

    let airportCode: String?
    let city: String?
    let timezoneIdentifier: String?
    let arrivalTimezoneIdentifier: String?

    // Flight-specific
    let flightNumber: String?
    let departureAirport: String?
    let arrivalAirport: String?
    let departureCity: String?
    let arrivalCity: String?

    let tripDayNumber: Int?
    let tripTotalDays: Int?

    /// Signed per-leg flight-time offset in minutes. Only the specifically-tagged
    /// flight leg has a value here.
    /// - Positive: delayed by this many minutes.
    /// - Negative: departing early by `abs(value)` minutes.
    let delayMinutes: Int?

    // "AA", "DL", "WN" etc. — nil for company flights
    let airlineCode: String?

    // Context label for non-flight legs (e.g., "RSV-A", "CQ12 Training")
    let label: String?
}
