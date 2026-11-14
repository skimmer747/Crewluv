//
//  LegStoryStore.swift
//  CrewLuve
//
//  Builds each flight's story and sun events off the main actor, and keeps them (Stage 2 spec §3.2). The status
//  screen owns one and hands it to the card and the full-screen map, so both read the same facts. Stories are kept
//  by route, since the screen rebuilds its TripMap on every render; sun events by flight and its delay-shifted times.
//

import Foundation
import Observation

@Observable
@MainActor
final class LegStoryStore {

    typealias FileLoader = @Sendable () -> (geography: Geography?, comparisons: ComparisonPicker?)

    private let loadFiles: FileLoader
    /// The one load of the data files, shared by every `prepare` that's waiting for it.
    @ObservationIgnored private var filesTask: Task<(geography: Geography?, comparisons: ComparisonPicker?), Never>?
    @ObservationIgnored private var hasLoadedFiles = false
    private var geography: Geography?
    private var comparisons: ComparisonPicker?
    private var storiesByRoute: [String: LegStory] = [:]
    private var sunEventsByLeg: [String: [SkyFacts.SunEvent]] = [:]

    /// - Parameter loadFiles: reads geography.json and comparisons.json; the app's bundled copies unless a test says.
    init(loadFiles: @escaping FileLoader = { (Geography.loadBundled(), ComparisonPicker.loadBundled()) }) {
        self.loadFiles = loadFiles
    }

    /// Builds whatever `tripMap`'s flights are missing. Anything already built is kept, so calling it again is cheap.
    func prepare(_ tripMap: TripMap) async {
        if !hasLoadedFiles {
            let loadFiles = self.loadFiles
            let task = filesTask ?? Task.detached(priority: .utility) { loadFiles() }
            filesTask = task
            let files = await task.value
            if !hasLoadedFiles {
                geography = files.geography
                comparisons = files.comparisons
                hasLoadedFiles = true
            }
        }
        let home = tripMap.home
        let flights = tripMap.legs.filter { $0.kind == .flight }
        // One story per route, even when the trip flies it twice.
        var routes: [String: MapLeg] = [:]
        for leg in flights {
            let key = Self.routeKey(for: leg, home: home)
            if storiesByRoute[key] == nil, routes[key] == nil { routes[key] = leg }
        }
        let timed = flights.filter { sunEventsByLeg[Self.timesKey(for: $0)] == nil }
        guard !routes.isEmpty || !timed.isEmpty else { return }
        let geography = self.geography
        let built = await Task.detached(priority: .utility) {
            (stories: routes.map { key, leg in (key, LegStory(leg: leg, geography: geography, home: home)) },
             sunEvents: timed.map { (Self.timesKey(for: $0), SkyFacts.sunEvents(on: $0)) })
        }.value
        for (key, story) in built.stories { storiesByRoute[key] = story }
        for (key, events) in built.sunEvents { sunEventsByLeg[key] = events }
    }

    /// The facts for `tripMap` from what's built so far.
    func facts(for tripMap: TripMap, forecasts: [String: LandingForecast] = [:], dayNumber: Int? = nil, totalDays: Int? = nil) -> TripFacts {
        var stories: [String: LegStory] = [:]
        var sunEvents: [String: [SkyFacts.SunEvent]] = [:]
        for leg in tripMap.legs where leg.kind == .flight {
            stories[leg.id] = storiesByRoute[Self.routeKey(for: leg, home: tripMap.home)]
            sunEvents[leg.id] = sunEventsByLeg[Self.timesKey(for: leg)]
        }
        return TripFacts(tripMap: tripMap, geography: geography, comparisons: comparisons, stories: stories,
                         sunEvents: sunEvents, forecasts: forecasts, dayNumber: dayNumber, totalDays: totalDays)
    }

    /// The route, and home when the flight passes it by: home changes the closest-point fact.
    nonisolated static func routeKey(for leg: MapLeg, home: AirportMark?) -> String {
        let route = "\(leg.origin.code)-\(leg.destination.code)"
        guard let home, home.code != leg.origin.code, home.code != leg.destination.code else { return route }
        return "\(route)|\(home.code)"
    }

    /// The flight, its route and its delay-shifted times: a new delay moves the sun events.
    nonisolated static func timesKey(for leg: MapLeg) -> String {
        "\(leg.id)|\(leg.origin.code)-\(leg.destination.code)|\(leg.start.timeIntervalSince1970)|\(leg.end.timeIntervalSince1970)"
    }
}
