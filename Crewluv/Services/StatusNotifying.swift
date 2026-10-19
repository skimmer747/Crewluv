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
        resolvedHomeArrivalTime: Date?
    ) async
}

extension StatusChangeNotifier: StatusNotifying {}

extension StatusNotifying {
    /// Hands a new reading to the alerts, titled with `name` or else the pilot's first name, with
    /// what they compare: the effective delay and the resolved home arrival, worked out as the
    /// screen used to.
    func evaluate(_ reading: PilotReading, titledWith name: String?) async {
        let now = Date()
        let status = reading.status(at: now)
        let homeArrival = TripStateResolver.resolveHomeArrival(
            legs: status.tripLegs, homeAirportCode: status.homeAirportCode, at: now
        )?.arrivalTime
        await evaluateChanges(
            old: nil,
            new: status,
            pilotName: name ?? status.pilotFirstName,
            newEffectiveDelay: status.effectiveFlightDelayMinutes,
            resolvedHomeArrivalTime: homeArrival ?? status.homeArrivalTime
        )
    }
}
