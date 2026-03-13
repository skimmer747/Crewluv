//
//  FlightTrackingHelper.swift
//  CrewLuve
//
//  URL construction for FlightRadar24 and FlightAware tracking links
//

import Foundation

enum FlightTrackingHelper {

    /// Splits a raw flight number string (e.g. "UPS2453", "5X 123", "WN1234")
    /// into (prefix, number) by finding the first digit after stripping spaces.
    static func parseFlightNumber(_ raw: String) -> (prefix: String, number: String) {
        let stripped = raw.replacingOccurrences(of: " ", with: "")
        guard let firstDigit = stripped.firstIndex(where: { $0.isNumber }) else {
            return (stripped, "")
        }
        let prefix = String(stripped[..<firstDigit])
        let number = String(stripped[firstDigit...])
        return (prefix, number)
    }

    /// FlightRadar24 URL — uses IATA prefix, lowercased.
    /// Maps known ICAO→IATA (e.g. UPS→5X) for better results.
    static func flightRadar24URL(for flightNumber: String) -> URL? {
        let (prefix, number) = parseFlightNumber(flightNumber)
        guard !prefix.isEmpty, !number.isEmpty else { return nil }
        let iataPrefix = icaoToIATA[prefix.uppercased()] ?? prefix
        let callsign = "\(iataPrefix)\(number)".lowercased()
        return URL(string: "https://www.flightradar24.com/data/flights/\(callsign)")
    }

    /// FlightAware URL — uses ICAO prefix, uppercased.
    /// Maps known IATA→ICAO (e.g. WN→SWA) since FlightAware prefers ICAO codes.
    static func flightAwareURL(for flightNumber: String) -> URL? {
        let (prefix, number) = parseFlightNumber(flightNumber)
        guard !prefix.isEmpty, !number.isEmpty else { return nil }
        let icaoPrefix = iataToICAO[prefix.uppercased()] ?? prefix
        let callsign = "\(icaoPrefix)\(number)".uppercased()
        return URL(string: "https://www.flightaware.com/live/flight/\(callsign)")
    }

    /// Converts a flight number from IATA prefix to ICAO prefix for display.
    /// e.g. "WN2200" → "SWA2200", "AA123" → "AAL123"
    static func displayFlightNumber(_ raw: String) -> String {
        let (prefix, number) = parseFlightNumber(raw)
        guard !prefix.isEmpty, !number.isEmpty else { return raw }
        let icaoPrefix = iataToICAO[prefix.uppercased()] ?? prefix
        return "\(icaoPrefix)\(number)"
    }

    // MARK: - Airline code mappings

    /// IATA → ICAO mapping (reverse of icaoToIATA, for display and FlightAware)
    private static let iataToICAO: [String: String] = {
        Dictionary(uniqueKeysWithValues: icaoToIATA.map { ($0.value, $0.key) })
    }()

    /// ICAO → IATA mapping (for FR24 which prefers IATA codes)
    private static let icaoToIATA: [String: String] = [
        "UPS": "5X",
        "FDX": "FX",
        "AAL": "AA",
        "DAL": "DL",
        "UAL": "UA",
        "SWA": "WN",
        "JBU": "B6",
        "NKS": "NK",
        "FFT": "F9",
        "ASA": "AS",
        "HAL": "HA",
        "SKW": "OO",
        "RPA": "YX",
        "ENY": "MQ",
        "PSA": "OH",
    ]
}
