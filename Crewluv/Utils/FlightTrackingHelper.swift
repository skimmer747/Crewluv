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

    /// FlightRadar24 URLs — app deep link and web fallback.
    /// Uses ICAO broadcast callsign to match ADS-B data.
    static func flightRadar24URLs(for flightNumber: String) -> (app: URL, web: URL)? {
        let (prefix, number) = parseFlightNumber(flightNumber)
        guard !prefix.isEmpty, !number.isEmpty else { return nil }
        let icaoPrefix = iataToICAO[prefix.uppercased()] ?? prefix
        let callsign = "\(icaoPrefix)\(number)".uppercased()
        guard let app = URL(string: "flightradar24://\(callsign)"),
              let web = URL(string: "https://fr24.com/\(callsign)") else { return nil }
        return (app, web)
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

    /// ICAO → IATA mapping (for airline code display)
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
