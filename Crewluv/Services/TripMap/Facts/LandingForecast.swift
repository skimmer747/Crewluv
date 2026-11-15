//
//  LandingForecast.swift
//  CrewLuve
//
//  The weather forecast for the hour a flight lands (Stage 2 spec §7).
//

nonisolated struct LandingForecast: Equatable, Sendable {
    /// "48°F", in the family's units.
    let temperature: String
    /// WeatherKit's description, lowercased: "rain", "mostly cloudy".
    let condition: String
}
