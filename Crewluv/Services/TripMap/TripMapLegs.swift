//
//  TripMapLegs.swift
//  CrewLuve
//
//  Which legs the status screen's map draws while the pilot is away, as Crewluve Website's tripMapFor picks them
//

import Foundation

/// Which legs the status screen's map draws while the pilot is away (`src/map/tripMapFor.ts` on the website): the
/// trip under way, by its id, else the flight or drive in motion. Never legs chained by how close they fall: a commuter
/// home for a few hours between trips sees one trip, not the next two weeks.
enum TripMapLegs {

    /// Drives and jumpseats this close to a trip's flights are drawn with it, like a commute to or from base.
    static let commuteWindow: TimeInterval = 12 * 3600

    /// The trip under way at `now`, the one whose legs span it: its flights, its layovers, turns and nights at base or
    /// home, and the drives and jumpseats in no trip within 12 hours of its flights. Nil between trips, or for a trip
    /// with no flight.
    static func ofTripUnderWay(in legs: [TripLeg], at now: Date) -> [TripLeg]? {
        let trips = Dictionary(grouping: legs.filter { $0.tripId != nil }, by: \.tripId)
        let underWay = trips.values
            .compactMap { tripLegs -> (legs: [TripLeg], start: Date)? in
                guard let first = tripLegs.map({ start($0) }).min(), let last = tripLegs.map({ end($0) }).max(),
                      first <= now, now < last else { return nil }
                return (tripLegs, first)
            }
            .min { $0.start < $1.start }
        guard let trip = underWay?.legs else { return nil }

        let flights = trip.filter { $0.type == .flight }
        guard let firstFlight = flights.map({ start($0) }).min(), let lastFlight = flights.map({ end($0) }).max() else {
            return nil
        }
        let window = firstFlight.addingTimeInterval(-commuteWindow)...lastFlight.addingTimeInterval(commuteWindow)
        let commutes = legs.filter { leg in
            (leg.type == .drive || (leg.type == .flight && leg.tripId == nil))
                && window.contains(start(leg)) && window.contains(end(leg))
        }
        let ground = trip.filter { [.turn, .layover, .base, .home].contains($0.type) }
        return (flights + commutes + ground).sorted { start($0) < start($1) }
    }

    /// The flight or drive under way at `now`, a flight before a drive, for a pilot between trips: a drive home or a
    /// jumpseat back to base.
    static func inMotion(in legs: [TripLeg], at now: Date) -> TripLeg? {
        let moving = legs
            .filter { [.flight, .drive].contains($0.type) && start($0) <= now && now < end($0) }
            .sorted { start($0) < start($1) }
        return moving.first { $0.type == .flight } ?? moving.first
    }

    // MARK: - Times

    private static func start(_ leg: TripLeg) -> Date { TripStateResolver.effectiveStart(of: leg) }
    private static func end(_ leg: TripLeg) -> Date { TripStateResolver.effectiveEnd(of: leg) }
}
