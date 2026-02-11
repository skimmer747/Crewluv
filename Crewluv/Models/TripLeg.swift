//
//  TripLeg.swift
//  CrewLuv
//
//  A single segment of a pilot's trip schedule
//

import Foundation

struct TripLeg: Codable, Sendable {
    enum LegType: String, Codable, Sendable {
        case flight, turn, layover, home
        case reserve, hotStandby, event  // future
        case unknown                     // forward compat

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = LegType(rawValue: raw) ?? .unknown
        }
    }

    let id: String
    let type: LegType
    let startTime: Date
    let endTime: Date

    let airportCode: String?
    let city: String?
    let timezoneIdentifier: String?

    // Flight-specific
    let flightNumber: String?
    let departureAirport: String?
    let arrivalAirport: String?
    let departureCity: String?
    let arrivalCity: String?

    let tripDayNumber: Int?
    let tripTotalDays: Int?
}
