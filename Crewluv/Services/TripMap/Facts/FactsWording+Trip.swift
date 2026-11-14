//
//  FactsWording+Trip.swift
//  CrewLuve
//
//  The facts' sentences about the whole trip (Stage 2 spec §4.8, §5, §6.5): totals so far, a trip ahead's forecast,
//  and the recap.
//

import Foundation

nonisolated extension FactsWording {

    /// "1 city", "2 cities".
    static func count(_ value: Int, _ one: String, _ many: String, locale: Locale = .current) -> String {
        "\(number(value, locale: locale)) \(value == 1 ? one : many)"
    }

    /// "1 day", "4 days".
    static func days(_ value: Int) -> String {
        value == 1 ? "1 day" : "\(value) days"
    }

    // MARK: - Totals

    /// "Day 2 of 4 · 1 city · 4,350 mi · 6 time zones · 1 sunset from the cockpit", with zeros left out. Nil when there's
    /// nothing to say.
    static func soFar(_ totals: TripTotals, dayNumber: Int?, totalDays: Int?, locale: Locale = .current) -> String? {
        var parts: [String] = []
        if let dayNumber, let totalDays { parts.append("Day \(dayNumber) of \(totalDays)") }
        if totals.cities > 0 { parts.append(count(totals.cities, "city", "cities", locale: locale)) }
        if totals.miles > 0 { parts.append(TripMapWording.milesText(totals.miles, locale: locale)) }
        if let onTheWay = onTheWay(totals, isForecast: false, locale: locale) { parts.append(onTheWay) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "8 time zones · about 2 sunsets from the cockpit" for a trip ahead, without "about" once flown. Nil when both
    /// are zero.
    static func onTheWay(_ totals: TripTotals, isForecast: Bool, locale: Locale = .current) -> String? {
        var parts: [String] = []
        if totals.timeZones > 0 {
            parts.append(count(totals.timeZones, "time zone", "time zones", locale: locale))
        }
        if totals.cockpitSunsets > 0 {
            let sunsets = count(totals.cockpitSunsets, "sunset from the cockpit", "sunsets from the cockpit", locale: locale)
            // A forecast is "about"; one sunset is just "a sunset".
            parts.append(!isForecast ? sunsets : totals.cockpitSunsets == 1 ? "a sunset from the cockpit" : "about \(sunsets)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "Dubai → Louisville, 7,382 mi".
    static func longest(_ leg: MapLeg, locale: Locale = .current) -> String {
        "\(leg.origin.name) → \(leg.destination.name), \(TripMapWording.milesText(miles(of: leg), locale: locale))"
    }

    // MARK: - The recap (§6.5)

    /// "Home from 4 days away", or "Home from a day away".
    static func recapChip(days: Int) -> String {
        days == 1 ? "Home from a day away" : "Home from \(days) days away"
    }

    /// Up to four numbers, with zeros left out.
    static func recapTiles(_ totals: TripTotals, locale: Locale = .current) -> [RecapTile] {
        let tiles: [(value: Int, one: String, many: String)] = [
            (totals.cities, "city", "cities"),
            (totals.miles, "mile", "miles"),
            (totals.timeZones, "time zone", "time zones"),
            (totals.cockpitSunsets, "sunset aloft", "sunsets aloft"),
        ]
        return tiles.filter { $0.value > 0 }.map {
            RecapTile(value: number($0.value, locale: locale), label: $0.value == 1 ? $0.one : $0.many)
        }
    }

    /// The recap card as VoiceOver reads it: "Trip recap: home from 4 days away. 2 cities, 14,819 miles,
    /// 18 time zones, 1 sunset from the cockpit. Longest flight, Dubai to Louisville, 7,382 miles."
    static func recapSummary(days: Int, totals: TripTotals, longest: MapLeg?, locale: Locale = .current) -> String {
        let chip = recapChip(days: days)
        var sentences = ["Trip recap: \(chip.prefix(1).lowercased() + chip.dropFirst())."]
        let counts = [
            totals.cities > 0 ? count(totals.cities, "city", "cities", locale: locale) : nil,
            totals.miles > 0 ? count(totals.miles, "mile", "miles", locale: locale) : nil,
            totals.timeZones > 0 ? count(totals.timeZones, "time zone", "time zones", locale: locale) : nil,
            totals.cockpitSunsets > 0 ? count(totals.cockpitSunsets, "sunset from the cockpit", "sunsets from the cockpit", locale: locale) : nil,
        ].compactMap { $0 }
        if !counts.isEmpty {
            sentences.append(counts.joined(separator: ", ") + ".")
        }
        if let longest {
            let longestMiles = number(miles(of: longest), locale: locale)
            sentences.append("Longest flight, \(longest.origin.name) to \(longest.destination.name), \(longestMiles) miles.")
        }
        return sentences.joined(separator: " ")
    }

    // MARK: - Private

    private static func miles(of leg: MapLeg) -> Int {
        Int((leg.distance / GreatCircle.metersPerMile).rounded())
    }
}
