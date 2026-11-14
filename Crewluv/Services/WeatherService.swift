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
    let moonPhase: MoonPhase?
    let moonrise: Date?
    let moonset: Date?
}

// MARK: - Moon Phase Helpers

extension MoonPhase {
    var sfSymbolName: String {
        switch self {
        case .new:              "moonphase.new.moon"
        case .waxingCrescent:   "moonphase.waxing.crescent"
        case .firstQuarter:     "moonphase.first.quarter"
        case .waxingGibbous:    "moonphase.waxing.gibbous"
        case .full:             "moonphase.full.moon"
        case .waningGibbous:    "moonphase.waning.gibbous"
        case .lastQuarter:     "moonphase.last.quarter"
        case .waningCrescent:   "moonphase.waning.crescent"
        @unknown default:       "moon.fill"
        }
    }

    var displayName: String {
        switch self {
        case .new:              "New Moon"
        case .waxingCrescent:   "Waxing Crescent"
        case .firstQuarter:     "First Quarter"
        case .waxingGibbous:    "Waxing Gibbous"
        case .full:             "Full Moon"
        case .waningGibbous:    "Waning Gibbous"
        case .lastQuarter:     "Third Quarter"
        case .waningCrescent:   "Waning Crescent"
        @unknown default:       "Moon"
        }
    }
}

@MainActor
final class WeatherService {
    static let shared = WeatherService()

    private var cache: [String: (snapshot: WeatherSnapshot, fetchedAt: Date)] = [:]
    private static let cacheDuration: TimeInterval = 15 * 60 // 15 minutes
    private var landingCache: [String: (forecast: LandingForecast, fetchedAt: Date)] = [:]
    private static let landingCacheDuration: TimeInterval = 30 * 60 // 30 minutes

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
                sunset: today?.sun.sunset,
                moonPhase: today?.moon.phase,
                moonrise: today?.moon.moonrise,
                moonset: today?.moon.moonset
            )

            cache[iata] = (snapshot, Date())
            return snapshot
        } catch {
            debugLog("WeatherService: failed for \(iata): \(error)")
            return nil
        }
    }

    /// The forecast for the hour holding `landing` at an airport (moving map Stage 2 spec §7.1): one hour of WeatherKit's
    /// hourly forecast, cached by airport and hour for 30 minutes. Nil, logged, when WeatherKit can't give one.
    func landingForecast(forAirport iata: String, latitude: Double, longitude: Double, at landing: Date) async -> LandingForecast? {
        let hour = Date(timeIntervalSince1970: (landing.timeIntervalSince1970 / 3600).rounded(.down) * 3600)
        let key = "\(iata)@\(Int(hour.timeIntervalSince1970))"
        if let cached = landingCache[key], Date().timeIntervalSince(cached.fetchedAt) < Self.landingCacheDuration {
            return cached.forecast
        }
        do {
            let location = CLLocation(latitude: latitude, longitude: longitude)
            let hours = try await WeatherKit.WeatherService.shared.weather(
                for: location, including: .hourly(startDate: hour, endDate: hour.addingTimeInterval(3600)))
            guard let forecastHour = hours.first(where: { $0.date <= landing && landing < $0.date.addingTimeInterval(3600) }) else { return nil }
            let forecast = LandingForecast(
                temperature: forecastHour.temperature.formatted(
                    .measurement(width: .abbreviated, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0)))),
                condition: forecastHour.condition.description.lowercased()
            )
            landingCache[key] = (forecast, Date())
            return forecast
        } catch is CancellationError {
            return nil // the map closed
        } catch {
            debugLog("WeatherService: no landing forecast for \(iata): \(error)")
            return nil
        }
    }
}
