//
//  TripStateResolver+HomeArrival.swift
//  CrewLuve
//
//  When the pilot gets home, found trip by trip as Crewluve Website finds it
//

import Foundation

// MARK: - Home Arrival

extension TripStateResolver {

    /// When the pilot gets home, for the "Back Home In" card and the alerts: Crewluve Website's
    /// `arrivalTarget` (`src/engine/targets.ts`) on the app's legs, its home answers only.
    ///
    /// It goes trip by trip, never by the gaps between legs, so a commuter home for a few hours
    /// between two trips is home: the countdown ends there, not at a later trip's homecoming.
    /// 1. On a ride home now (a jumpseat, drive or event that arrives home, in no trip), its end.
    /// 2. Otherwise the trip under way, else one that ended or starts within a day:
    ///    - its last arrival home, when nothing of the trip comes after it, so a turn through home
    ///      doesn't count;
    ///    - else a ride home that starts after its last flight began, within 3 days of its end and
    ///      before the next trip;
    ///    - else, while the pilot stays away, the same for the next trip. The pilot stays away when
    ///      the next trip starts within a day, from somewhere other than home, with no ride from
    ///      home or drive to work before it.
    /// 3. With no trip that near, a ride home that starts within 3 days, before the next trip.
    ///
    /// Crewlu Cloud's partner-push copies this (`homeArrival`), and the alert pushes' shared cases
    /// hold the two to it.
    ///
    /// - Returns: `nil` without a home airport, or when that search finds no arrival home ahead.
    ///   The trips are those the search went through, for the alerts to compare arrivals within.
    static func resolveHomeArrival(legs: [TripLeg], homeAirportCode: String?, at now: Date) -> TripEndInfo? {
        guard let home = homeAirportCode, !home.isEmpty else { return nil }
        guard let homecoming = HomecomingSearch(legs: legs, home: home, now: now).homecoming() else { return nil }
        return TripEndInfo(
            arrivalTime: effectiveEnd(of: homecoming.leg),
            arrivalLabel: "Back Home In",
            arrivalCity: homecoming.leg.arrivalCity ?? home,
            trips: homecoming.trips
        )
    }

    /// When the trip `tripID` brings the pilot home, as `resolveHomeArrival` sees it at the trip's first flight
    /// (Crewluve Website's `nextTripHomecoming`): for the narrative's "Back home in … on …" while the pilot is
    /// home before the trip. A pre-trip commute isn't the trip's start: at its moment the trip before still counts.
    static func resolveHomeArrival(forTrip tripID: String, legs: [TripLeg], homeAirportCode: String?) -> TripEndInfo? {
        let tripLegs = legs.filter { $0.tripId == tripID }
        let byStart: (TripLeg, TripLeg) -> Bool = { effectiveStart(of: $0) < effectiveStart(of: $1) }
        guard let first = tripLegs.filter({ $0.type == .flight }).min(by: byStart) ?? tripLegs.min(by: byStart) else {
            return nil
        }
        return resolveHomeArrival(legs: legs, homeAirportCode: homeAirportCode, at: effectiveStart(of: first))
    }
}

// MARK: - Homecoming Search

/// The search behind `TripStateResolver.resolveHomeArrival`, on delay-shifted times throughout.
private struct HomecomingSearch {

    /// The leg that brings the pilot home, and the trips the search went through to find it.
    struct Homecoming {
        let leg: TripLeg
        let trips: [String]
    }

    private static let day: TimeInterval = 24 * 60 * 60
    /// How long after a trip's last flight a ride home still counts as that trip's.
    private static let rideWindow: TimeInterval = 3 * day

    /// Sorted by start, then by end.
    private let legs: [TripLeg]
    private let home: String
    private let now: Date

    init(legs: [TripLeg], home: String, now: Date) {
        self.legs = legs.sorted { (Self.start($0), Self.end($0)) < (Self.start($1), Self.end($1)) }
        self.home = home
        self.now = now
    }

    func homecoming() -> Homecoming? {
        let trip = currentTripID()
        if let current = currentLeg(), current.tripId == nil, isHomecoming(current) {
            return Homecoming(leg: current, trips: trip.map { [$0] } ?? [])
        }
        guard let trip else {
            let nextTripStart = nextTripLeg(of: nil, after: now).map { Self.start($0) } ?? .distantFuture
            return ride(startingFrom: .distantPast, by: now + Self.rideWindow, before: nextTripStart)
                .map { Homecoming(leg: $0, trips: []) }
        }

        var trips = [trip]
        var after = now
        while let id = trips.last {
            let tripLegs = legs.filter { $0.tripId == id }
            if let final = finalArrivalHome(among: tripLegs) {
                return Homecoming(leg: final, trips: trips)
            }
            guard let last = tripLegs.filter({ $0.type == .flight }).max(by: { Self.end($0) < Self.end($1) }) else {
                return nil
            }
            let next = nextTripLeg(of: id, after: after)
            let nextStart = next.map { Self.start($0) } ?? .distantFuture
            if let ride = ride(startingFrom: Self.start(last), by: Self.end(last) + Self.rideWindow, before: nextStart) {
                return Homecoming(leg: ride, trips: trips)
            }
            guard let next, let nextID = next.tripId, staysAway(from: last, until: next) else { return nil }
            trips.append(nextID)
            after = nextStart
        }
        return nil
    }

    // MARK: - The Trip

    /// The leg covering now, a flight before a drive, a drive before a ground leg, a ground leg before
    /// a reserve, standby or event.
    private func currentLeg() -> TripLeg? {
        legs
            .filter { Self.start($0) <= now && now < Self.end($0) }
            .min { Self.rank($0) < Self.rank($1) }
    }

    /// The trip under way, else the last one to end if it ended within a day, else the next if it starts
    /// within a day.
    private func currentTripID() -> String? {
        if let id = currentLeg()?.tripId { return id }
        let previous = legs.reduce(nil as TripLeg?) { latest, leg in
            guard leg.tripId != nil, Self.end(leg) <= now else { return latest }
            guard let latest else { return leg }
            return Self.end(leg) >= Self.end(latest) ? leg : latest
        }
        if let previous, now.timeIntervalSince(Self.end(previous)) <= Self.day { return previous.tripId }
        guard let next = nextTripLeg(of: nil, after: now), Self.start(next).timeIntervalSince(now) <= Self.day else {
            return nil
        }
        return next.tripId
    }

    /// The trip's last arrival home still ahead, with nothing of the trip after it.
    private func finalArrivalHome(among tripLegs: [TripLeg]) -> TripLeg? {
        let finals = tripLegs.indices.filter { index in
            let leg = tripLegs[index]
            return isHomecoming(leg) && Self.end(leg) > now
                && !tripLegs.indices.contains { $0 != index && Self.start(tripLegs[$0]) >= Self.end(leg) }
        }
        return finals.map { tripLegs[$0] }.max { Self.end($0) < Self.end($1) }
    }

    /// The first leg of a trip other than `trip` that starts after `moment`.
    private func nextTripLeg(of trip: String?, after moment: Date) -> TripLeg? {
        legs.first { $0.tripId != nil && $0.tripId != trip && Self.start($0) > moment }
    }

    // MARK: - Rides Home

    /// The first ride home, in no trip and not yet over, that starts in `[from, before)` and by `by`.
    private func ride(startingFrom from: Date, by: Date, before: Date) -> TripLeg? {
        legs.first { leg in
            let start = Self.start(leg)
            return leg.tripId == nil && isHomecoming(leg) && Self.end(leg) > now
                && start >= from && start < before && start <= by
        }
    }

    /// Whether the pilot stays away from the trip's last flight to the next trip: it starts within a day,
    /// not from home, and no ride from home or drive to work starts before it (from now, once the trip
    /// is over, since the signs of home before now are over).
    private func staysAway(from last: TripLeg, until next: TripLeg) -> Bool {
        let nextStart = Self.start(next)
        guard nextStart.timeIntervalSince(Self.end(last)) <= Self.day, !isHome(departure(of: next)) else { return false }
        let from = max(Self.end(last), now)
        return !legs.contains { leg in
            let start = Self.start(leg)
            return leg.tripId == nil && start >= from && start < nextStart
                && (isHome(departure(of: leg)) || (leg.type == .drive && !isHome(leg.arrivalAirport)))
        }
    }

    // MARK: - Legs

    /// A flight, drive or event that arrives home.
    private func isHomecoming(_ leg: TripLeg) -> Bool {
        [.flight, .drive, .event].contains(leg.type) && isHome(leg.arrivalAirport)
    }

    private func isHome(_ airport: String?) -> Bool {
        airport?.caseInsensitiveCompare(home) == .orderedSame
    }

    /// Where a leg begins: a flight's or drive's departure airport, else the leg's own airport.
    private func departure(of leg: TripLeg) -> String? {
        switch leg.type {
        case .flight, .drive: leg.departureAirport
        default: leg.airportCode
        }
    }

    private static func rank(_ leg: TripLeg) -> Int {
        switch leg.type {
        case .flight: 0
        case .drive: 1
        case .turn, .layover, .base, .home: 2
        case .reserve, .hotStandby, .event, .unknown: 3
        }
    }

    private static func start(_ leg: TripLeg) -> Date { TripStateResolver.effectiveStart(of: leg) }
    private static func end(_ leg: TripLeg) -> Date { TripStateResolver.effectiveEnd(of: leg) }
}
