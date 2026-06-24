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
    let displayStatus: PilotDisplayStatus
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

/// Where the **current** contiguous trip ends, derived only from trip legs.
/// Used when Duty's `homeArrivalTime` / `homeArrivalLabel` are stale in CloudKit.
struct TripEndInfo: Sendable {
    let arrivalTime: Date
    let arrivalLabel: String
    let arrivalCity: String?
}

enum TripStateResolver {

    /// Derive real-time status from trip legs.
    /// Handles both active legs (startTime <= now < endTime) and gaps between legs.
    /// Returns `nil` only when no leg has completed yet (before first leg starts)
    static func resolve(legs: [TripLeg], flightDelayMinutes: Int? = nil, homeAirportCode: String? = nil, baseAirportCode: String? = nil, at now: Date) -> ActiveLegState? {
        let sorted = legs.sorted { $0.startTime < $1.startTime }

        // Standard active candidates: effective window covers `now`.
        // Flight legs take priority over reserve/hotStandby/event when overlapping.
        let candidates = sorted.filter { Self.effectiveStart(of: $0) <= now && now < Self.effectiveEnd(of: $0) }
        let primary = candidates.first { $0.type == .flight }
            ?? candidates.first { $0.type != .reserve && $0.type != .hotStandby && $0.type != .event }
            ?? candidates.first

        // Per-leg offset: the flight whose tagged signed offset is in effect.
        let perLegDelayed: TripLeg? = candidates.first {
            $0.type == .flight && ($0.delayMinutes ?? 0) != 0
        }

        // Legacy fallback for old Duty without per-leg offset tagging.
        let legacyDelayed: TripLeg? = {
            let shift = TimeInterval((flightDelayMinutes ?? 0) * 60)
            guard shift != 0, !sorted.contains(where: { ($0.delayMinutes ?? 0) != 0 }) else { return nil }
            return sorted.first {
                $0.type == .flight
                    && $0.startTime.addingTimeInterval(shift) <= now
                    && now < $0.endTime.addingTimeInterval(shift)
            }
        }()

        let delayedFlight = perLegDelayed ?? legacyDelayed

        // Delayed flight wins over ground legs that assumed on-time arrival
        guard let leg = (delayedFlight ?? primary) else {
            // No active leg spans `now` — derive state from surrounding legs (gap handling)
            return resolveGap(sorted: sorted, flightDelayMinutes: flightDelayMinutes, homeAirportCode: homeAirportCode, baseAirportCode: baseAirportCode, at: now)
        }

        let isInFlight = leg.type == .flight

        // Derive arrival timezone from the next ground leg (which sits at the arrival airport)
        let arrivalTimezone: String? = {
            guard isInFlight else { return nil }
            return leg.arrivalTimezoneIdentifier
                ?? sorted.first(where: { $0.startTime >= leg.endTime && $0.type != .flight })?.timezoneIdentifier
        }()

        // Effective end time with offset (signed — early shortens, late extends)
        let legDelay = TimeInterval((leg.delayMinutes ?? 0) * 60)
        let legacyDelay = TimeInterval((flightDelayMinutes ?? 0) * 60)
        let effectiveEnd: Date = {
            if isInFlight, legDelay != 0 { return leg.endTime.addingTimeInterval(legDelay) }
            if isInFlight, perLegDelayed == nil, legacyDelayed?.id == leg.id, legacyDelay != 0 {
                return leg.endTime.addingTimeInterval(legacyDelay)
            }
            // Ground leg before an early next flight: transition when the flight actually starts.
            if !isInFlight,
               let nf = sorted.first(where: { leg2 in
                   leg2.type == .flight && Self.effectiveStart(of: leg2) > now
               }),
               let d = nf.delayMinutes, d < 0 {
                return min(leg.endTime, Self.effectiveStart(of: nf))
            }
            return leg.endTime
        }()

        let transition = effectiveEnd.timeIntervalSince(now)

        // Resolved offset: the value relevant to the current state
        let resolvedDelay: Int? = {
            if let d = delayedFlight, (d.delayMinutes ?? 0) != 0 { return d.delayMinutes }
            if delayedFlight != nil || legacyDelayed != nil { return flightDelayMinutes }
            // Ground leg: check if next flight has a per-leg offset
            if !isInFlight {
                let nextFlight = sorted.first { $0.type == .flight && $0.startTime > now }
                if let nf = nextFlight, (nf.delayMinutes ?? 0) != 0 { return nf.delayMinutes }
            }
            return nil
        }()

        return ActiveLegState(
            displayStatus: leg.type == .drive
                ? driveStatus(for: leg, homeAirportCode: homeAirportCode, baseAirportCode: baseAirportCode)
                : displayStatus(for: leg.type),
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

    // MARK: - Trip End (countdown card)

    /// Finds the end of the pilot's **current** trip block for the partner countdown card.
    ///
    /// **Why this exists:** Duty sometimes writes `homeArrivalTime` once (e.g. first stop of the day)
    /// and does not refresh it. CrewLuve *does* get fresh legs — so we recompute trip end from legs
    /// when that CloudKit field is already in the past.
    ///
    /// **How it works:**
    /// 1. Sort legs by start time.
    /// 2. Split into **segments**: legs chained with gaps **at most** 24 hours between them.
    ///    A gap longer than 24h starts a new trip (e.g. work trip vs vacation vs next trip).
    /// 3. Pick the segment that matches `now`:
    ///    - If `now` is **inside** a segment (between first start and last end), that segment is the trip.
    ///    - If `now` is **after** the last leg (rest at hotel, days off), use the segment that **just
    ///      ended** (latest `last.endTime` still ≤ `now`) so the card shows PHL "In", not April's leg.
    ///    - If `now` is **before** the first leg, use the first segment.
    ///
    /// - Parameters:
    ///   - legs: Trip legs from shared status (same source as `resolve`).
    ///   - homeAirportCode: Pilot home IATA; if trip end matches, label is `"Back Home In"`.
    ///   - now: Reference time (normally `Date()`).
    /// - Returns: `nil` only when `legs` is empty.
    static func resolveTripEnd(legs: [TripLeg], homeAirportCode: String?, at now: Date) -> TripEndInfo? {
        let sorted = legs.sorted { $0.startTime < $1.startTime }
        guard let first = sorted.first else { return nil }

        let maxGapBetweenLegs: TimeInterval = 24 * 60 * 60

        // Build contiguous segments separated by > maxGapBetweenLegs.
        var segments: [[TripLeg]] = []
        var current: [TripLeg] = [first]
        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let leg = sorted[i]
            let gap = leg.startTime.timeIntervalSince(prev.endTime)
            if gap > maxGapBetweenLegs {
                segments.append(current)
                current = [leg]
            } else {
                current.append(leg)
            }
        }
        segments.append(current)

        // Pick the segment that covers `now`, accounting for per-leg delay on the
        // last flight so delayed flights keep the segment "active" until actual arrival.
        let chosen: [TripLeg] = {
            if let active = segments.first(where: { segment in
                guard let firstLeg = segment.first, let lastLeg = segment.last else { return false }
                let effectiveEnd: Date = {
                    guard lastLeg.type == .flight, let delay = lastLeg.delayMinutes, delay != 0 else {
                        return lastLeg.endTime
                    }
                    return lastLeg.endTime.addingTimeInterval(TimeInterval(delay * 60))
                }()
                return now >= firstLeg.startTime && now < effectiveEnd
            }) {
                return active
            }
            if let justFinished = segments
                .filter({ ($0.last?.endTime ?? .distantPast) <= now })
                .max(by: { a, b in
                    (a.last?.endTime ?? .distantPast) < (b.last?.endTime ?? .distantPast)
                }) {
                return justFinished
            }
            // segments is guaranteed non-empty (current is always appended above)
            return segments.first!
        }()

        guard let endLeg = chosen.last else { return nil }

        let arrivalTime: Date
        let arrivalAirport: String?
        let arrivalCity: String?

        if endLeg.type == .flight {
            let delay = TimeInterval((endLeg.delayMinutes ?? 0) * 60)
            arrivalTime = endLeg.endTime.addingTimeInterval(delay)
            arrivalAirport = endLeg.arrivalAirport
            arrivalCity = endLeg.arrivalCity
        } else {
            arrivalTime = endLeg.endTime
            arrivalAirport = endLeg.airportCode
            arrivalCity = endLeg.city
        }

        let arrivalLabel: String = {
            if let code = arrivalAirport,
               let home = homeAirportCode,
               code.caseInsensitiveCompare(home) == .orderedSame {
                return "Back Home In"
            }
            if let city = arrivalCity, !city.isEmpty {
                return "\(city) In"
            }
            if let code = arrivalAirport, !code.isEmpty {
                return "\(code) In"
            }
            return "Trip End In"
        }()

        let cityForSubtitle: String? = {
            if let city = arrivalCity, !city.isEmpty { return city }
            return arrivalAirport
        }()

        return TripEndInfo(
            arrivalTime: arrivalTime,
            arrivalLabel: arrivalLabel,
            arrivalCity: cityForSubtitle
        )
    }

    // MARK: - Home Arrival (cross-trip scan)

    /// Finds the first future leg arriving at the home airport across ALL legs.
    /// Unlike `resolveTripEnd()` which looks at the current trip segment's last leg,
    /// this scans across all trips to find when the pilot actually gets home.
    ///
    /// Includes `.event` legs whose `arrivalAirport` equals the home airport — manual
    /// events landing at home (e.g. "Drive home in Orlando") count as home arrivals.
    /// Safe because sims/training are scheduled at the base airport, never home.
    static func resolveHomeArrival(legs: [TripLeg], homeAirportCode: String?, at now: Date) -> TripEndInfo? {
        guard let home = homeAirportCode, !home.isEmpty else { return nil }

        guard let homeLeg = legs
            .filter({ ($0.type == .flight || $0.type == .event || $0.type == .drive) && $0.endTime > now && $0.arrivalAirport?.caseInsensitiveCompare(home) == .orderedSame })
            .min(by: { $0.startTime < $1.startTime })
        else { return nil }

        let delay = TimeInterval((homeLeg.delayMinutes ?? 0) * 60)
        let arrivalTime = homeLeg.endTime.addingTimeInterval(delay)
        let city = homeLeg.arrivalCity ?? home

        return TripEndInfo(
            arrivalTime: arrivalTime,
            arrivalLabel: "Back Home In",
            arrivalCity: city
        )
    }

    // MARK: - Drive To Work (leave-home countdown)

    /// The next upcoming drive from home to base ("leaving for work"), if any.
    /// Returns `nil` for non-commuters (no drive legs) — they leave home via the
    /// flight itself, so the leave-home countdown falls back to the departure.
    static func nextDriveToWork(legs: [TripLeg], baseAirportCode: String?, at now: Date) -> TripLeg? {
        guard let base = baseAirportCode, !base.isEmpty else { return nil }
        return legs
            .filter { $0.type == .drive && $0.startTime > now && $0.arrivalAirport?.caseInsensitiveCompare(base) == .orderedSame }
            .min(by: { $0.startTime < $1.startTime })
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
    private static func resolveGap(sorted: [TripLeg], flightDelayMinutes: Int?, homeAirportCode: String? = nil, baseAirportCode: String? = nil, at now: Date) -> ActiveLegState? {
        guard let completedLeg = sorted.last(where: { Self.effectiveEnd(of: $0) <= now }) else {
            return nil
        }

        let nextLeg = sorted.first(where: { Self.effectiveStart(of: $0) > now })

        // After a flight: pilot is at the arrival airport/city.
        // After a ground leg: pilot is still at that leg's airport/city.
        let airport: String?
        let city: String?
        let timezone: String?

        if completedLeg.type == .flight || completedLeg.type == .drive {
            airport = completedLeg.arrivalAirport
            city = completedLeg.arrivalCity
            timezone = nextLeg?.timezoneIdentifier
                ?? completedLeg.arrivalTimezoneIdentifier
        } else {
            airport = completedLeg.airportCode
            city = completedLeg.city
            timezone = completedLeg.timezoneIdentifier
        }

        // Detect home-between-trips: no next leg, gap > 24 hours, or cross-trip boundary.
        // If the pilot is at their home airport, return "Home" so the view shows "Leaves In".
        let maxGapBetweenLegs: TimeInterval = 24 * 60 * 60
        let isDifferentTrip: Bool = {
            guard let completedId = completedLeg.tripId, let nextId = nextLeg?.tripId else { return false }
            return completedId != nextId
        }()
        let isEndOfTrip = nextLeg == nil
            || nextLeg!.startTime.timeIntervalSince(completedLeg.endTime) > maxGapBetweenLegs
            || isDifferentTrip

        if isEndOfTrip {
            let transition = nextLeg.map { Self.effectiveStart(of: $0).timeIntervalSince(now) }
            let timeUntilNextTransition = transition.flatMap { $0 > 0 ? $0 : nil }

            func gapState(_ status: PilotDisplayStatus) -> ActiveLegState {
                ActiveLegState(
                    displayStatus: status,
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
                    flightDelayMinutes: nil,
                    timeUntilNextTransition: timeUntilNextTransition
                )
            }

            // 1. At the pilot's home airport.
            if let home = homeAirportCode, let current = airport,
               current.caseInsensitiveCompare(home) == .orderedSame {
                return gapState(.home)
            }

            // 2. At the pilot's base airport (commuter sitting at base between trips).
            if let base = baseAirportCode, let current = airport,
               current.caseInsensitiveCompare(base) == .orderedSame {
                return gapState(.base)
            }

            // 3. Between trips somewhere else — surface the city; no inferred status word.
            if airport != nil {
                return gapState(.elsewhere(city: city))
            }

            // No location at all — fall back to Duty's raw displayStatus.
            return nil
        }

        // Gap after a home/base leg (or a manual event at the home/base airport)
        // before the next leg starts: pilot is still at home or base, not on a "Turn".
        let inferredHomeBase: PilotDisplayStatus? = {
            if completedLeg.type == .home { return .home }
            if completedLeg.type == .base { return .base }
            if completedLeg.type == .event, let apt = completedLeg.airportCode {
                if let home = homeAirportCode, apt.caseInsensitiveCompare(home) == .orderedSame {
                    return .home
                }
                if let base = baseAirportCode, apt.caseInsensitiveCompare(base) == .orderedSame {
                    return .base
                }
            }
            if completedLeg.type == .drive, let apt = completedLeg.arrivalAirport {
                if let home = homeAirportCode, apt.caseInsensitiveCompare(home) == .orderedSame {
                    return .home
                }
                if let base = baseAirportCode, apt.caseInsensitiveCompare(base) == .orderedSame {
                    return .base
                }
            }
            return nil
        }()
        if let homeBaseStatus = inferredHomeBase {
            let transition = nextLeg.map { Self.effectiveStart(of: $0).timeIntervalSince(now) }
            return ActiveLegState(
                displayStatus: homeBaseStatus,
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
                flightDelayMinutes: nil,
                timeUntilNextTransition: transition.flatMap { $0 > 0 ? $0 : nil }
            )
        }

        // Propagate per-leg offset from the next upcoming flight
        let nextFlightDelay: Int? = {
            guard let nf = sorted.first(where: { $0.type == .flight && Self.effectiveStart(of: $0) > now }),
                  (nf.delayMinutes ?? 0) != 0 else { return nil }
            return nf.delayMinutes
        }()

        // Re-resolve when the next leg starts (shifted) so the status transitions in real time
        let transition = nextLeg.map { Self.effectiveStart(of: $0).timeIntervalSince(now) }

        return ActiveLegState(
            displayStatus: .turn,
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

    /// Scheduled start shifted by the leg's signed `delayMinutes` (negative = earlier).
    static func effectiveStart(of leg: TripLeg) -> Date {
        leg.startTime.addingTimeInterval(TimeInterval((leg.delayMinutes ?? 0) * 60))
    }

    /// Scheduled end shifted by the leg's signed `delayMinutes`.
    static func effectiveEnd(of leg: TripLeg) -> Date {
        leg.endTime.addingTimeInterval(TimeInterval((leg.delayMinutes ?? 0) * 60))
    }

    private static func displayStatus(for type: TripLeg.LegType) -> PilotDisplayStatus {
        switch type {
        case .flight:     .inFlight
        case .turn:       .turn
        case .layover:    .layover
        case .home:       .home
        case .base:       .base
        // Unreachable on the live path: active `.drive` legs route through `driveStatus`
        // (call site above), which resolves direction. This default only keeps the
        // switch exhaustive; the directional truth lives in `driveStatus`, not here.
        case .drive:      .drivingToWork
        case .reserve:    .reserve
        case .hotStandby: .hotStandby
        case .event:      .training
        case .unknown:    .unknown("On Duty")
        }
    }

    /// Direction of a drive leg from its arrival airport: home -> `.drivingHome`,
    /// otherwise `.drivingToWork`. `baseAirportCode` is reserved for symmetry with the
    /// other direction-detection sites; direction currently keys off the home match only.
    private static func driveStatus(for leg: TripLeg, homeAirportCode: String?, baseAirportCode: String?) -> PilotDisplayStatus {
        if let home = homeAirportCode,
           leg.arrivalAirport?.caseInsensitiveCompare(home) == .orderedSame {
            return .drivingHome
        }
        return .drivingToWork
    }
}
