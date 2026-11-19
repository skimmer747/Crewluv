//
//  FactRow.swift
//  CrewLuve
//
//  One row of the facts sheet (Stage 2 spec §5): a symbol, a title and a second line made of the row's other parts.
//

import Foundation

nonisolated struct FactRow: Identifiable, Equatable, Sendable {

    nonisolated enum Kind: String, Sendable {
        // In flight (§5.1), with the plane's row for a flight with live data (Stage 3 spec §8)
        case below, plane, sky, distance, takeoff, headed
        // On a layover (§5.3), at home before a trip (§5.4) and in the recap (§5.5)
        case whereTheyAre, nextFlight, leaves, tripAhead, theTrip, onTheWay, tripSoFar, longestFlight
    }

    let kind: Kind
    /// An SF Symbol.
    let symbolName: String
    let title: String
    /// The other parts, joined by " · ", or nil when there are none.
    let detail: String?
    /// True when the row shows a WeatherKit forecast, which needs Apple's attribution (§7.2).
    let hasWeather: Bool

    var id: Kind { kind }

    /// The row as VoiceOver reads it, with commas where the screen shows " · ", and "your time" for the family's
    /// times' "L".
    var sentence: String {
        ClockLabel.spoken([title, detail?.replacingOccurrences(of: " · ", with: ", ")].compactMap { $0 }.joined(separator: ". "))
    }

    /// A row whose second line is `details` without the nils.
    init(_ kind: Kind, symbol: String, title: String, details: [String?] = [], hasWeather: Bool = false) {
        self.kind = kind
        symbolName = symbol
        self.title = title
        let parts = details.compactMap { $0 }
        detail = parts.isEmpty ? nil : parts.joined(separator: " · ")
        self.hasWeather = hasWeather
    }
}
