//
//  LandingWeather.swift
//  CrewLuve
//
//  Weather on landing (Stage 2 spec §7): which flights get it, and fetching it while the full-screen map is open, now
//  and every 30 minutes. The card never shows weather, so nothing is fetched until the map opens.
//

import CoreLocation
import Foundation
import Observation

@Observable
@MainActor
final class LandingWeather {

    /// Landing-hour forecasts, by leg id.
    private(set) var forecasts: [String: LandingForecast] = [:]

    private static let refreshInterval: Duration = .seconds(30 * 60)

    /// The flight in the air at `now`, and the next flight, each only when it lands within 48 hours of `now`.
    nonisolated static func flightsToForecast(in tripMap: TripMap, now: Date) -> [MapLeg] {
        let flights = tripMap.legs.filter { $0.kind == .flight }
        let inAir = flights.first { $0.isMoving(at: now) }
        let next = flights.first { $0.start > now }
        return [inAir, next].compactMap { $0 }.filter { $0.end.timeIntervalSince(now) <= TripFacts.weatherHorizon }
    }

    /// Fetches the forecasts now, then every 30 minutes until the task is cancelled, when the map closes. Start it with
    /// `.task(id:)` on the flights' times, so a new delay starts it again with the new landing hours.
    func keepRefreshing(for tripMap: TripMap) async {
        while !Task.isCancelled {
            await refresh(for: tripMap, now: .now)
            try? await Task.sleep(for: Self.refreshInterval)
        }
    }

    private func refresh(for tripMap: TripMap, now: Date) async {
        for leg in Self.flightsToForecast(in: tripMap, now: now) {
            guard !Task.isCancelled else { return }
            let place = leg.destination.coordinate
            if let forecast = await WeatherService.shared.landingForecast(forAirport: leg.destination.code, latitude: place.latitude,
                                                                          longitude: place.longitude, at: leg.end) {
                forecasts[leg.id] = forecast
            }
        }
    }
}
