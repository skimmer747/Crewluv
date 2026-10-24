//
//  StatusNotifying.swift
//  CrewLuve
//
//  What hears of each new status: the alerts
//

import Foundation

/// What hears of each new status: the alerts.
nonisolated protocol StatusNotifying: Sendable {
    func evaluateChanges(
        old: SharedPilotStatus?,
        new: SharedPilotStatus,
        pilotName: String,
        newEffectiveDelay: Int?,
        resolvedHomeArrivalTime: Date?,
        resolvedHomeArrivalTrips: [String]?,
        posting: Bool
    ) async
}

extension StatusChangeNotifier: StatusNotifying {}

extension StatusNotifying {
    /// Hands a new reading to the alerts, titled with `name` or else the pilot's first name, with
    /// what they compare: the effective delay and the resolved home arrival, worked out at `now` as the
    /// screen used to, with the trips that arrival belongs to. With `posting` false, the alerts compare
    /// and remember it but post nothing (alert pushes spec §6.3).
    func evaluate(_ reading: PilotReading, titledWith name: String?, at now: Date = Date(), posting: Bool = true) async {
        let status = reading.status(at: now)
        let homeArrival = TripStateResolver.resolveHomeArrival(
            legs: status.tripLegs, homeAirportCode: status.homeAirportCode, at: now
        )
        await evaluateChanges(
            old: nil,
            new: status,
            pilotName: name ?? status.pilotFirstName,
            newEffectiveDelay: status.effectiveFlightDelayMinutes(at: now),
            resolvedHomeArrivalTime: homeArrival?.arrivalTime ?? status.homeArrivalTime,
            resolvedHomeArrivalTrips: homeArrival?.trips ?? status.currentTripId.map { [$0] } ?? [],
            posting: posting
        )
    }
}
