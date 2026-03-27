//
//  TripStateResolver.swift
//  CrewLuve
//
//  Pure stateless resolver: derives real-time status from the trip legs timeline.
//  Handles active legs AND gaps between legs (turns, post-flight ground time).
//  The trip legs timeline is the single source of truth when legs exist.
//

import Foundation

/// Result of resolving the pilot's current state from trip legs.
/// `nil` from `resolve()` means no leg data covers `now` (before first leg)
/// — caller should fall back to Duty's pre-computed displayStatus.
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
    let currentFlightArrivalTimezone: String?  // Arrival tz derived from next ground leg

    // Delay for the active state
    let flightDelayMinutes: Int?

    // Seconds until the active leg ends (schedule re-resolve at this boundary)
    let timeUntilNextTransition: TimeInterval?
}

enum TripStateResolver {

    /// Derive real-time status from trip legs.
    /// Handles both active legs (startTime <= now < endTime) and gaps between legs.
    /// Returns `nil` only when no leg has completed yet (before first leg starts)
    /// — caller should fall back to Duty's pre-computed displayStatus in that case.
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
            // No active leg spans `now` — derive state from surrounding legs (gap handling)
            return resolveGap(sorted: sorted, flightDelayMinutes: flightDelayMinutes, at: now)
        }

        let isInFlight = leg.type == .flight

        // Derive arrival timezone from the next ground leg (which sits at the arrival airport)
        let arrivalTimezone: String? = {
            guard isInFlight else { return nil }
            return leg.arrivalTimezoneIdentifier
                ?? sorted.first(where: { $0.startTime >= leg.endTime && $0.type != .flight })?.timezoneIdentifier
        }()

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
            currentFlightArrivalTimezone: arrivalTimezone,
            flightDelayMinutes: resolvedDelay,
            timeUntilNextTransition: transition > 0 ? transition : nil
        )
    }

    // MARK: - Gap Resolution

    /// Derive status when `now` falls between legs (e.g., turn at DFW between flights).
    ///
    /// Finds the most recently completed leg and uses its arrival/location data to
    /// determine where the pilot is right now. This keeps the trip legs timeline as
    /// the single source of truth instead of falling back to Duty's pre-computed fields,
    /// which may be stale for cross-trip or jumpseat flights.
    ///
    /// Returns `nil` only when no leg has completed yet (before the first leg starts).
    private static func resolveGap(sorted: [TripLeg], flightDelayMinutes: Int?, at now: Date) -> ActiveLegState? {
        guard let completedLeg = sorted.last(where: { $0.endTime <= now }) else {
            return nil
        }

        let nextLeg = sorted.first(where: { $0.startTime > now })

        // After a flight: pilot is at the arrival airport/city.
        // After a ground leg: pilot is still at that leg's airport/city.
        let airport: String?
        let city: String?
        let timezone: String?

        if completedLeg.type == .flight {
            airport = completedLeg.arrivalAirport
            city = completedLeg.arrivalCity
            timezone = nextLeg?.timezoneIdentifier
                ?? completedLeg.arrivalTimezoneIdentifier
        } else {
            airport = completedLeg.airportCode
            city = completedLeg.city
            timezone = completedLeg.timezoneIdentifier
        }

        // Propagate per-leg delay from the next upcoming flight
        let nextFlightDelay: Int? = {
            guard let nf = sorted.first(where: { $0.type == .flight && $0.startTime > now }),
                  (nf.delayMinutes ?? 0) > 0 else { return nil }
            return nf.delayMinutes
        }()

        // Re-resolve when the next leg starts so the status transitions in real time
        let transition = nextLeg.map { $0.startTime.timeIntervalSince(now) }

        return ActiveLegState(
            displayStatus: "Turn",
            isInFlight: false,
            currentAirport: airport,
            currentCity: city,
            currentTimezone: timezone,
            currentFlightNumber: nil,
            currentFlightDeparture: nil,
            currentFlightArrival: nil,
            currentFlightDepartureTime: nil,
            currentFlightArrivalTime: nil,
            currentFlightArrivalTimezone: nil,
            flightDelayMinutes: nextFlightDelay,
            timeUntilNextTransition: transition.flatMap { $0 > 0 ? $0 : nil }
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
