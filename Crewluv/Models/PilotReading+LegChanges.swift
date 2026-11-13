//
//  PilotReading+LegChanges.swift
//  CrewLuve
//
//  Logs legs that appear or disappear between readings
//

import Foundation

extension PilotReading {
    /// Logs legs that appeared or disappeared between two readings, to catch disappearing legs.
    static func logLegChanges(from old: PilotReading?, to new: PilotReading) {
        let now = Date()
        let oldLegs = old?.status(at: now).tripLegs ?? []
        let newLegs = new.status(at: now).tripLegs
        let oldIds = Set(oldLegs.map(\.id))
        let newIds = Set(newLegs.map(\.id))
        guard oldIds != newIds else { return }

        debugLog("[TripLegDiff] === LEG CHANGE DETECTED ===")
        debugLog("[TripLegDiff] Count: \(oldLegs.count) → \(newLegs.count)")
        debugLog("[TripLegDiff] Record mod date: \(new.recordModifiedAt?.formatted(date: .abbreviated, time: .standard) ?? "unknown")")
        for leg in oldLegs where !newIds.contains(leg.id) {
            debugLog("[TripLegDiff] REMOVED: \(describe(leg))")
        }
        for leg in newLegs where !oldIds.contains(leg.id) {
            debugLog("[TripLegDiff] ADDED: \(describe(leg))")
        }
    }

    private static func describe(_ leg: TripLeg) -> String {
        let route = leg.type == .flight
            ? "\(leg.departureAirport ?? "?")→\(leg.arrivalAirport ?? "?")"
            : leg.airportCode ?? "?"
        let trip = leg.tripId.map { "trip:\($0)" } ?? "standalone"
        let start = leg.startTime.formatted(date: .abbreviated, time: .shortened)
        let end = leg.endTime.formatted(date: .abbreviated, time: .shortened)
        return "[\(leg.type.rawValue)] \(route) (\(trip)) \(start)–\(end)"
    }
}
