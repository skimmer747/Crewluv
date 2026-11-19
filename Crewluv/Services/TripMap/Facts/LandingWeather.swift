//
//  LandingWeather.swift
//  CrewLuve
//
//  Weather on landing (Stage 2 spec §7), and at takeoff for the flight in the air (time labels design §3.3): which
//  flights get it, and fetching it while the full-screen map is open, now and every 30 minutes. The card never shows
//  weather, so nothing is fetched until the map opens.
//

import CoreLocation
import Foundation
import Observation

@Observable
@MainActor
final class LandingWeather {

    /// Landing-hour forecasts, by leg id.
    private(set) var forecasts: [String: LandingForecast] = [:]
    /// The weather in the hour the flight in the air took off, by leg id.
    private(set) var takeoffForecasts: [String: LandingForecast] = [:]

    private static let refreshInterval: Duration = .seconds(30 * 60)

    /// The flight in the air at `now`, and the next flight, each only when it lands within 48 hours of `now`.
    nonisolated static func flightsToForecast(in tripMap: TripMap, now: Date) -> [MapLeg] {
        let flights = tripMap.legs.filter { $0.kind == .flight }
        let inAir = flights.first { $0.isMoving(at: now) }
        let next = flights.first { $0.start > now }
        return [inAir, next].compactMap { $0 }.filter { $0.end.timeIntervalSince(now) <= TripFacts.weatherHorizon }
    }

    /// The flight in the air at `now` and when it took off, once it has: its takeoff row tells that hour's weather.
    nonisolated static func takeoffToFetch(in tripMap: TripMap, now: Date) -> (leg: MapLeg, takeoff: Takeoff)? {
        guard let leg = tripMap.legs.first(where: { $0.kind == .flight && $0.isMoving(at: now) }),
              let takeoff = leg.takeoff, takeoff.time <= now else { return nil }
        return (leg, takeoff)
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
        // WeatherKit tells a past hour's weather as it tells a coming one's.
        guard !Task.isCancelled, let (leg, takeoff) = Self.takeoffToFetch(in: tripMap, now: now) else { return }
        let place = leg.origin.coordinate
        if let weather = await WeatherService.shared.landingForecast(forAirport: leg.origin.code, latitude: place.latitude,
                                                                     longitude: place.longitude, at: takeoff.time) {
            takeoffForecasts[leg.id] = weather
        }
    }
}
