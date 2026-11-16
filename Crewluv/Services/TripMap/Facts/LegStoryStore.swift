//
//  LegStoryStore.swift
//  CrewLuve
//
//  Builds each flight's story and sun events off the main actor, and keeps them (Stage 2 spec §3.2, Stage 3 spec §8).
//  The status screen owns one and hands it to the card and the full-screen map, so both read the same facts.
//  - A flight on the schedule has its route's story, since the screen rebuilds its TripMap on every render, and its
//    sun events by its delay-shifted times.
//  - A flight with a real path has a story of its own, made again as the path grows, at most once a minute, with
//    its sun events.
//  What a flight already has shows until the next is ready, so nothing blinks while it's worked out.
//

import Foundation
import Observation

@Observable
@MainActor
final class LegStoryStore {

    typealias FileLoader = @Sendable () -> (geography: Geography?, comparisons: ComparisonPicker?)

    /// A flight with a real path gets its story again no sooner than this after the last one was started
    /// (Stage 3 spec §8).
    nonisolated static let pathStoryInterval: TimeInterval = 60

    private let loadFiles: FileLoader
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let sleep: (TimeInterval) async throws -> Void
    /// The one load of the data files, shared by every `prepare` that's waiting for it.
    @ObservationIgnored private var filesTask: Task<(geography: Geography?, comparisons: ComparisonPicker?), Never>?
    @ObservationIgnored private var hasLoadedFiles = false
    private var geography: Geography?
    private var comparisons: ComparisonPicker?
    private var storiesByRoute: [String: LegStory] = [:]
    /// The story of each flight with a real path, by leg id.
    private var storiesByPath: [String: LegStory] = [:]
    /// Each flight's sun events, by leg id: one set a flight, replaced when its times or its path change.
    private var sunEventsByLeg: [String: [SkyFacts.SunEvent]] = [:]
    /// What each flight's sun events were last worked out from, by leg id.
    @ObservationIgnored private var sunKeys: [String: String] = [:]
    /// The newest path each flight's story was started for, by leg id, and when.
    @ObservationIgnored private var pathBuilds: [String: (key: String, at: Date)] = [:]

    /// - Parameters:
    ///   - loadFiles: reads geography.json and comparisons.json; the app's bundled copies unless a test says.
    ///   - now: this device's clock.
    ///   - sleep: waits that many seconds, and throws if its task is cancelled meanwhile.
    init(
        loadFiles: @escaping FileLoader = { (Geography.loadBundled(), ComparisonPicker.loadBundled()) },
        now: @escaping () -> Date = { Date() },
        sleep: @escaping (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }
    ) {
        self.loadFiles = loadFiles
        self.now = now
        self.sleep = sleep
    }

    /// Builds whatever `tripMap`'s flights are missing. Anything already built is kept, so calling it again is cheap.
    /// A real path that grew within a minute of its last story waits the minute out first: the views start
    /// `prepare` again with `.task(id:)` when the path changes, which ends the wait.
    func prepare(_ tripMap: TripMap) async {
        await loadFilesOnce()
        let home = tripMap.home
        let flights = tripMap.legs.filter { $0.kind == .flight }
        while !Task.isCancelled {
            let work = claimWork(for: flights, home: home, at: now())
            await build(work, home: home)
            guard let wait = work.wait else { return }
            do { try await sleep(wait) } catch { return }
        }
    }

    /// The facts for `tripMap` from what's built so far.
    /// - Parameter isReplay: the moments asked about are a replay's, not now.
    func facts(for tripMap: TripMap, forecasts: [String: LandingForecast] = [:], dayNumber: Int? = nil, totalDays: Int? = nil,
               isReplay: Bool = false) -> TripFacts {
        var stories: [String: LegStory] = [:]
        var sunEvents: [String: [SkyFacts.SunEvent]] = [:]
        for leg in tripMap.legs where leg.kind == .flight {
            let route = storiesByRoute[Self.routeKey(for: leg, home: tripMap.home)]
            // A real path has its own story. Until the first is ready the route's stands in, where the flight had
            // one from before it was seen: it's read by distance, which is near enough where a real path begins.
            stories[leg.id] = Self.pathKey(for: leg) == nil ? route : storiesByPath[leg.id] ?? route
            sunEvents[leg.id] = sunEventsByLeg[leg.id]
        }
        return TripFacts(tripMap: tripMap, geography: geography, comparisons: comparisons, stories: stories,
                         sunEvents: sunEvents, forecasts: forecasts, dayNumber: dayNumber, totalDays: totalDays,
                         isReplay: isReplay)
    }

    /// The route, and home when the flight passes it by: home changes the closest-point fact.
    nonisolated static func routeKey(for leg: MapLeg, home: AirportMark?) -> String {
        let route = "\(leg.origin.code)-\(leg.destination.code)"
        guard let home, home.code != leg.origin.code, home.code != leg.destination.code else { return route }
        return "\(route)|\(home.code)"
    }

    /// What `prepare` builds from: each leg's route and delay-shifted times, its real path where it has one, and
    /// home. The views start `prepare` again with `.task(id:)` whenever it changes.
    nonisolated static func preparationKey(for tripMap: TripMap) -> [String] {
        tripMap.legs.map { leg in [timesKey(for: leg), pathKey(for: leg)].compactMap { $0 }.joined(separator: "|") }
            + [tripMap.home?.code ?? ""]
    }

    /// The flight, its route and its delay-shifted times: a new delay moves the sun events.
    nonisolated static func timesKey(for leg: MapLeg) -> String {
        "\(leg.id)|\(leg.origin.code)-\(leg.destination.code)|\(leg.start.timeIntervalSince1970)|\(leg.end.timeIntervalSince1970)"
    }

    /// What tells one state of a flight's real path from the next, or nil for a flight without one: the places it
    /// was seen, its landing, real or estimated, and the height its sky is seen from. Its story and its sun events
    /// are made from these, so they're made again when it changes.
    nonisolated static func pathKey(for leg: MapLeg) -> String? {
        guard let flight = leg.flight, let record = flight.record else { return nil }
        let path = flight.path
        return [leg.id, "\(path.knots.count)", "\(path.flownLength)", "\(path.length)", "\(path.hasLanded)",
                "\(record.touchdown.timeIntervalSince1970)", "\(SkyFacts.cockpitHorizon(for: leg))"].joined(separator: "|")
    }

    // MARK: - Private

    /// What one pass of `prepare` builds, and how long until the next has something to build.
    private struct Work {
        /// One leg for each route with no story yet, even when the trip flies it twice.
        var routes: [String: MapLeg] = [:]
        /// Each flight whose real path changed, with the path's key.
        var paths: [(key: String, leg: MapLeg)] = []
        /// Each flight on the schedule whose times changed, with their key.
        var timed: [(key: String, leg: MapLeg)] = []
        /// The seconds until a real path that grew too soon after its last story can have its next.
        var wait: TimeInterval?

        var isEmpty: Bool { routes.isEmpty && paths.isEmpty && timed.isEmpty }
    }

    /// What `flights` are missing at `now`. Each thing to build is claimed here, before any waiting, so a second
    /// `prepare` running beside this one doesn't build it too.
    private func claimWork(for flights: [MapLeg], home: AirportMark?, at now: Date) -> Work {
        var work = Work()
        for leg in flights {
            guard let pathKey = Self.pathKey(for: leg) else {
                // Back on the schedule, as when its live data goes: should the same path come back, its story
                // and its sun events are made afresh.
                pathBuilds[leg.id] = nil
                let route = Self.routeKey(for: leg, home: home)
                if storiesByRoute[route] == nil, work.routes[route] == nil { work.routes[route] = leg }
                let times = Self.timesKey(for: leg)
                if sunKeys[leg.id] != times {
                    sunKeys[leg.id] = times
                    work.timed.append((times, leg))
                }
                continue
            }
            guard pathBuilds[leg.id]?.key != pathKey else { continue }
            // A clock that was set back doesn't hold a story up: only a build in the last minute does.
            if let last = pathBuilds[leg.id], (0..<Self.pathStoryInterval).contains(now.timeIntervalSince(last.at)) {
                let left = Self.pathStoryInterval - now.timeIntervalSince(last.at)
                work.wait = min(work.wait ?? left, left)
                continue
            }
            pathBuilds[leg.id] = (pathKey, now)
            sunKeys[leg.id] = pathKey
            work.paths.append((pathKey, leg))
        }
        return work
    }

    /// Builds `work` off the main actor, and keeps what comes back.
    private func build(_ work: Work, home: AirportMark?) async {
        guard !work.isEmpty else { return }
        let geography = self.geography
        let built = await Task.detached(priority: .utility) {
            (routes: work.routes.map { key, leg in (key, LegStory(leg: leg, geography: geography, home: home)) },
             paths: work.paths.map { ($0.key, $0.leg.id, LegStory(leg: $0.leg, geography: geography, home: home)) },
             sunEvents: (work.timed + work.paths).map { ($0.key, $0.leg.id, SkyFacts.sunEvents(on: $0.leg)) })
        }.value
        for (key, story) in built.routes { storiesByRoute[key] = story }
        // Only the newest asked for is kept, should an older one finish last.
        for (key, legID, story) in built.paths where pathBuilds[legID]?.key == key { storiesByPath[legID] = story }
        for (key, legID, events) in built.sunEvents where sunKeys[legID] == key { sunEventsByLeg[legID] = events }
    }

    private func loadFilesOnce() async {
        guard !hasLoadedFiles else { return }
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
}
