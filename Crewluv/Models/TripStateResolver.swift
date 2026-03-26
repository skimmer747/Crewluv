//
//  TripStateResolver.swift
//  CrewLuve
//
//  Pure stateless resolver: finds the active trip leg and maps it to a display state.
//  Trusts Duty's pre-computed fields (homeArrival*, nextDeparture*, tripDay*, upcomingCities).
//

import Foundation

/// Result of resolving the active leg from trip legs.
/// `nil` from `resolve()` means no active leg — use Duty's pre-computed displayStatus.
struct ActiveLegState {
    let displayStatus: String
    let isInFlight: Bool

    // Location (from the active leg)
    let currentAirport: String?
    let currentCity: String?
    let currentTimezone: String?

    // Flight info (only when isInFlight)
    let currentFlightNumber: String?
    let currentFlightDeparture: String?
    let currentFlightArrival: String?
    let currentFlightDepartureTime: Date?
    let currentFlightArrivalTime: Date?

    // Delay for the active state
    let flightDelayMinutes: Int?

    // Seconds until the active leg ends (schedule re-resolve at this boundary)
    let timeUntilNextTransition: TimeInterval?
}

enum TripStateResolver {

    /// Find the currently-active leg and derive real-time status.
    /// Returns `nil` when no leg spans `now` — caller should use Duty's pre-computed displayStatus.
    static func resolve(legs: [TripLeg], flightDelayMinutes: Int? = nil, at now: Date) -> ActiveLegState? {
        let sorted = legs.sorted { $0.startTime < $1.startTime }

        // Standard active candidates: startTime <= now < endTime
        // Flight legs take priority over reserve/hotStandby/event when overlapping
        let candidates = sorted.filter { $0.startTime <= now && now < $0.endTime }
        let primary = candidates.first { $0.type == .flight }
            ?? candidates.first { $0.type != .reserve && $0.type != .hotStandby && $0.type != .event }
            ?? candidates.first

        // Per-leg delay: extend the specifically-delayed flight (new Duty tags delay on the leg)
        let perLegDelayed: TripLeg? = sorted.first {
            $0.type == .flight &&
            ($0.delayMinutes ?? 0) > 0 &&
            $0.startTime <= now &&
            now < $0.endTime.addingTimeInterval(TimeInterval(($0.delayMinutes ?? 0) * 60))
        }

        // Legacy fallback for old Duty without per-leg delay tagging
        let legacyDelayed: TripLeg? = {
            let interval = TimeInterval((flightDelayMinutes ?? 0) * 60)
            guard interval > 0, !sorted.contains(where: { ($0.delayMinutes ?? 0) > 0 }) else { return nil }
            return sorted.first {
                $0.type == .flight && $0.startTime <= now && now < $0.endTime.addingTimeInterval(interval)
            }
        }()

        let delayedFlight = perLegDelayed ?? legacyDelayed

        // Delayed flight wins over ground legs that assumed on-time arrival
        guard let leg = (delayedFlight ?? primary) else {
            return nil
        }

        let isInFlight = leg.type == .flight

        // Effective end time with delay extension
        let legDelay = TimeInterval((leg.delayMinutes ?? 0) * 60)
        let legacyDelay = TimeInterval((flightDelayMinutes ?? 0) * 60)
        let effectiveEnd: Date = {
            if isInFlight, legDelay > 0 { return leg.endTime.addingTimeInterval(legDelay) }
            if isInFlight, perLegDelayed == nil, legacyDelayed?.id == leg.id, legacyDelay > 0 {
                return leg.endTime.addingTimeInterval(legacyDelay)
            }
            return leg.endTime
        }()

        let transition = effectiveEnd.timeIntervalSince(now)

        // Resolved delay: the delay relevant to the current state
        let resolvedDelay: Int? = {
            if let d = delayedFlight, (d.delayMinutes ?? 0) > 0 { return d.delayMinutes }
            if delayedFlight != nil || legacyDelayed != nil { return flightDelayMinutes }
            // Ground leg: check if next flight has per-leg delay
            if !isInFlight {
                let nextFlight = sorted.first { $0.type == .flight && $0.startTime > now }
                if let nf = nextFlight, (nf.delayMinutes ?? 0) > 0 { return nf.delayMinutes }
            }
            return nil
        }()

        return ActiveLegState(
            displayStatus: statusString(for: leg.type),
            isInFlight: isInFlight,
            currentAirport: isInFlight ? leg.departureAirport : leg.airportCode,
            currentCity: isInFlight ? nil : leg.city,
            currentTimezone: leg.timezoneIdentifier,
            currentFlightNumber: isInFlight ? leg.flightNumber : nil,
            currentFlightDeparture: isInFlight ? leg.departureAirport : nil,
            currentFlightArrival: isInFlight ? leg.arrivalAirport : nil,
            currentFlightDepartureTime: isInFlight ? leg.startTime : nil,
            currentFlightArrivalTime: isInFlight ? leg.endTime : nil,
            flightDelayMinutes: resolvedDelay,
            timeUntilNextTransition: transition > 0 ? transition : nil
        )
    }

    // MARK: - Private

    private static func statusString(for type: TripLeg.LegType) -> String {
        switch type {
        case .flight:     "In Flight"
        case .turn:       "Turn"
        case .layover:    "Layover"
        case .home:       "Home"
        case .base:       "Base"
        case .reserve:    "Reserve"
        case .hotStandby: "Hot Standby"
        case .event:      "Training"
        case .unknown:    "On Duty"
        }
    }
}
