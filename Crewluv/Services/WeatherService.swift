//
//  WeatherService.swift
//  CrewLuve
//
//  Fetches current weather for airport locations via WeatherKit
//

import Foundation
import WeatherKit
import CoreLocation

struct WeatherSnapshot {
    let temperature: String
    let conditionSymbol: String
    let conditionDescription: String
    let isDaylight: Bool
    let sunrise: Date?
    let sunset: Date?
}

@MainActor
final class WeatherService {
    static let shared = WeatherService()

    private var cache: [String: (snapshot: WeatherSnapshot, fetchedAt: Date)] = [:]
    private static let cacheDuration: TimeInterval = 15 * 60 // 15 minutes

    private init() {}

    func currentWeather(forAirport iata: String, latitude: Double, longitude: Double) async -> WeatherSnapshot? {
        // Check cache
        if let cached = cache[iata],
           Date().timeIntervalSince(cached.fetchedAt) < Self.cacheDuration {
            return cached.snapshot
        }

        do {
            let location = CLLocation(latitude: latitude, longitude: longitude)
            let (current, daily) = try await WeatherKit.WeatherService.shared
                .weather(for: location, including: .current, .daily)

            let temp = current.temperature.formatted(
                .measurement(width: .narrow, usage: .weather,
                             numberFormatStyle: .number.precision(.fractionLength(0)))
            )
            let calendar = Calendar.current
            let today = daily.first { calendar.isDateInToday($0.date) }
            let snapshot = WeatherSnapshot(
                temperature: temp,
                conditionSymbol: current.symbolName,
                conditionDescription: current.condition.description,
                isDaylight: current.isDaylight,
                sunrise: today?.sun.sunrise,
                sunset: today?.sun.sunset
            )

            cache[iata] = (snapshot, Date())
            return snapshot
        } catch {
            debugLog("WeatherService: failed for \(iata): \(error)")
            return nil
        }
    }
}
