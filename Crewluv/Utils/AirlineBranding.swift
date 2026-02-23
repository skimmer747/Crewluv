//
//  AirlineBranding.swift
//  CrewLuve
//
//  Airline name, symbol, and color lookups for narrative display.
//  Data sourced from Duty's AirlineColors.swift.
//

import SwiftUI

enum AirlineBranding {

    // MARK: - ICAO → IATA resolution

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

    /// Resolves an ICAO prefix (e.g. "UPS") to its IATA code ("5X"),
    /// or returns the input unchanged if already IATA.
    private static func resolveCode(_ code: String) -> String {
        let upper = code.uppercased()
        return icaoToIATA[upper] ?? upper
    }

    // MARK: - Airline Name

    static func airlineName(for airlineCode: String?) -> String {
        guard let raw = airlineCode, !raw.isEmpty else { return "Commercial" }
        let code = resolveCode(raw)

        switch code {
        // Major US Airlines
        case "WN": return "Southwest"
        case "AA": return "American"
        case "DL": return "Delta"
        case "UA": return "United"
        case "B6": return "JetBlue"
        case "AS": return "Alaska"
        case "NK": return "Spirit"
        case "F9": return "Frontier"
        case "G4": return "Allegiant"
        case "MX": return "Breeze"
        case "HA": return "Hawaiian"
        case "XP": return "Avelo"
        case "SY": return "Sun Country"

        // Cargo
        case "FX": return "FedEx"
        case "5X": return "UPS"
        case "5Y": return "Atlas Air"
        case "GG": return "Air Cargo Germany"
        case "K4": return "Kalitta"
        case "PO": return "Polar Air"
        case "GT": return "Air Inuit"

        // International
        case "AC": return "Air Canada"
        case "LH": return "Lufthansa"
        case "BA": return "British Airways"
        case "AF": return "Air France"
        case "CX": return "Cathay Pacific"
        case "KL": return "KLM"
        case "QF": return "Qantas"
        case "EK": return "Emirates"
        case "SQ": return "Singapore"

        // Asian Airlines
        case "NH": return "ANA"
        case "JL": return "Japan Airlines"
        case "KE": return "Korean Air"
        case "OZ": return "Asiana"
        case "CI": return "China Airlines"
        case "BR": return "EVA Air"
        case "TG": return "Thai Airways"
        case "MH": return "Malaysia"

        // Middle East
        case "QR": return "Qatar"
        case "EY": return "Etihad"
        case "TK": return "Turkish"

        // European Airlines
        case "LX": return "Swiss"
        case "OS": return "Austrian"
        case "AZ": return "ITA Airways"
        case "IB": return "Iberia"
        case "SK": return "SAS"
        case "AY": return "Finnair"
        case "EI": return "Aer Lingus"
        case "VS": return "Virgin Atlantic"
        case "VA": return "Virgin Australia"

        // Oceania
        case "NZ": return "Air New Zealand"

        // Latin America
        case "AM": return "Aeromexico"
        case "LA": return "LATAM"
        case "CM": return "Copa"
        case "AV": return "Avianca"

        // Regional Airlines
        case "OO": return "SkyWest"
        case "YX": return "Republic"
        case "9E": return "Endeavor"
        case "QX": return "Horizon"
        case "ZW": return "Air Wisconsin"
        case "MQ": return "Envoy"
        case "OH": return "PSA"
        case "CP": return "Compass"
        case "G7": return "GoJet"
        case "AX": return "Trans States"

        default: return code
        }
    }

    // MARK: - SF Symbol

    static func symbolName(for airlineCode: String?) -> String {
        guard let raw = airlineCode, !raw.isEmpty else { return "airplane" }
        let code = resolveCode(raw)

        switch code {
        case "WN": return "heart.fill"
        case "DL": return "triangle.fill"
        case "AA": return "star.fill"
        case "UA": return "globe.americas.fill"
        case "B6": return "airplane.circle.fill"
        case "AS": return "mountain.2.fill"
        case "NK": return "dollarsign.circle.fill"
        case "F9": return "leaf.fill"
        case "G4": return "sun.max.fill"
        case "MX": return "wind"
        case "HA": return "leaf.fill"
        case "XP": return "bird.fill"
        case "SY": return "sun.max.fill"
        case "FX": return "shippingbox.fill"
        case "5X": return "shippingbox.fill"
        case "AC": return "leaf.fill"
        case "LH": return "bird.fill"
        case "BA": return "crown.fill"
        case "AF": return "airplane.circle.fill"
        case "CX": return "bird.fill"
        case "KL": return "crown.fill"
        case "QF": return "hare.fill"
        case "EK": return "sparkles"
        case "SQ": return "bird.fill"
        case "NH": return "airplane.circle.fill"
        case "JL": return "bird.fill"
        case "KE": return "circle.lefthalf.filled"
        case "OZ": return "airplane.circle.fill"
        case "CI": return "leaf.fill"
        case "BR": return "globe.asia.australia.fill"
        case "TG": return "leaf.fill"
        case "MH": return "diamond.fill"
        case "QR": return "hare.fill"
        case "EY": return "bird.fill"
        case "TK": return "bird.fill"
        case "LX": return "plus"
        case "OS": return "chevron.up.chevron.down"
        case "SK": return "sailboat.fill"
        case "EI": return "leaf.fill"
        case "VS": return "sparkles"
        case "VA": return "sparkles"
        case "NZ": return "leaf.fill"
        case "AM": return "bird.fill"
        case "CM": return "star.fill"
        case "AV": return "bird.fill"
        case "QX": return "mountain.2.fill"
        case "MQ": return "star.fill"
        case "OH": return "star.fill"
        case "CP": return "location.north.fill"
        case "5Y": return "globe.americas.fill"
        case "PO": return "pawprint.fill"
        default: return "airplane"
        }
    }

    // MARK: - Brand Color

    static func color(for airlineCode: String?) -> Color {
        guard let raw = airlineCode, !raw.isEmpty else { return .blue }
        let code = resolveCode(raw)

        switch code {
        // Major US Airlines
        case "WN": return Color(red: 1.0, green: 0.5, blue: 0.0)
        case "AA": return Color(red: 0.0, green: 0.2, blue: 0.5)
        case "DL": return Color(red: 0.0, green: 0.15, blue: 0.4)
        case "UA": return Color(red: 0.0, green: 0.45, blue: 0.7)
        case "B6": return Color(red: 0.0, green: 0.35, blue: 0.65)
        case "AS": return Color(red: 0.0, green: 0.3, blue: 0.5)
        case "NK": return Color(red: 1.0, green: 0.8, blue: 0.0)
        case "F9": return Color(red: 0.0, green: 0.5, blue: 0.3)
        case "G4": return Color(red: 1.0, green: 0.5, blue: 0.0)
        case "SY": return Color(red: 1.0, green: 0.4, blue: 0.0)
        case "MX": return Color(red: 0.0, green: 0.7, blue: 0.7)
        case "HA": return Color(red: 0.5, green: 0.0, blue: 0.5)
        case "XP": return Color(red: 1.0, green: 0.8, blue: 0.0)

        // Cargo
        case "FX": return Color(red: 0.5, green: 0.0, blue: 0.5)
        case "5X": return Color(red: 0.4, green: 0.2, blue: 0.0)
        case "K4": return Color(red: 0.8, green: 0.0, blue: 0.0)
        case "5Y": return Color(red: 0.0, green: 0.2, blue: 0.6)
        case "GG": return Color(red: 0.5, green: 0.5, blue: 0.5)

        // International
        case "AC": return Color(red: 0.8, green: 0.0, blue: 0.0)
        case "LH": return Color(red: 0.0, green: 0.1, blue: 0.4)
        case "BA": return Color(red: 0.0, green: 0.2, blue: 0.5)
        case "AF": return Color(red: 0.0, green: 0.3, blue: 0.5)
        case "CX": return Color(red: 0.0, green: 0.5, blue: 0.4)
        case "KL": return Color(red: 0.0, green: 0.6, blue: 0.9)
        case "QF": return Color(red: 0.9, green: 0.0, blue: 0.0)
        case "EK": return Color(red: 0.9, green: 0.0, blue: 0.2)
        case "SQ": return Color(red: 0.0, green: 0.2, blue: 0.5)

        // Asian Airlines
        case "NH": return Color(red: 0.0, green: 0.27, blue: 0.5)
        case "JL": return Color(red: 0.79, green: 0.15, blue: 0.18)
        case "KE": return Color(red: 0.0, green: 0.39, blue: 0.82)
        case "OZ": return Color(red: 0.93, green: 0.11, blue: 0.14)
        case "CI": return Color(red: 0.4, green: 0.0, blue: 0.4)
        case "BR": return Color(red: 0.0, green: 0.65, blue: 0.32)
        case "TG": return Color(red: 0.36, green: 0.18, blue: 0.57)
        case "MH": return Color(red: 0.0, green: 0.2, blue: 0.4)

        // Middle East
        case "QR": return Color(red: 0.36, green: 0.02, blue: 0.2)
        case "EY": return Color(red: 0.77, green: 0.65, blue: 0.47)
        case "TK": return Color(red: 0.78, green: 0.05, blue: 0.19)

        // European Airlines
        case "LX": return Color(red: 0.84, green: 0.1, blue: 0.13)
        case "OS": return Color(red: 0.89, green: 0.02, blue: 0.08)
        case "AZ": return Color(red: 0.0, green: 0.2, blue: 0.6)
        case "IB": return Color(red: 0.85, green: 0.12, blue: 0.02)
        case "SK": return Color(red: 0.0, green: 0.0, blue: 0.5)
        case "AY": return Color(red: 0.04, green: 0.06, blue: 0.38)
        case "EI": return Color(red: 0.0, green: 0.42, blue: 0.33)
        case "VS": return Color(red: 0.88, green: 0.04, blue: 0.04)
        case "VA": return Color(red: 0.6, green: 0.0, blue: 0.2)

        // Oceania
        case "NZ": return Color(red: 0.0, green: 0.71, blue: 0.68)

        // Latin America
        case "AM": return Color(red: 0.0, green: 0.15, blue: 0.3)
        case "LA": return Color(red: 0.11, green: 0.06, blue: 0.42)
        case "CM": return Color(red: 0.0, green: 0.22, blue: 0.46)
        case "AV": return Color(red: 0.89, green: 0.02, blue: 0.08)

        // Regional Airlines
        case "OO": return Color(red: 0.0, green: 0.3, blue: 0.6)
        case "YX": return Color(red: 0.0, green: 0.3, blue: 0.5)
        case "9E": return Color(red: 0.0, green: 0.2, blue: 0.4)
        case "QX": return Color(red: 0.0, green: 0.5, blue: 0.3)
        case "ZW": return Color(red: 0.8, green: 0.0, blue: 0.2)
        case "MQ": return Color(red: 0.0, green: 0.2, blue: 0.5)
        case "OH": return Color(red: 0.0, green: 0.2, blue: 0.5)
        case "CP": return Color(red: 0.0, green: 0.15, blue: 0.4)
        case "G7": return Color(red: 0.0, green: 0.45, blue: 0.7)
        case "AX": return Color(red: 0.0, green: 0.3, blue: 0.5)

        // Additional Cargo
        case "PO": return Color(red: 0.0, green: 0.3, blue: 0.6)
        case "GT": return Color(red: 0.8, green: 0.0, blue: 0.0)

        default: return .blue
        }
    }
}
