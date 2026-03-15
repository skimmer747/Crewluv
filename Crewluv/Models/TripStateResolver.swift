//
//  TripStateResolver.swift
//  CrewLuve
//
//  Pure stateless resolver: [TripLeg] + Date → ResolvedPilotState
//

import Foundation

struct ResolvedPilotState {
    let displayStatus: String
    let isHome: Bool
    let isInFlight: Bool
    let isOnDuty: Bool

    let currentAirport: String?
    let currentCity: String?
    let currentTimezone: String?

    let currentFlightNumber: String?
    let currentFlightDeparture: String?
    let currentFlightArrival: String?
    let currentFlightDepartureTime: Date?
    let currentFlightArrivalTime: Date?
    let currentFlightArrivalTimezone: String?

    let homeArrivalTime: Date?
    let homeArrivalLabel: String?
    let homeArrivalCity: String?
    let nextDepartureTime: Date?
    let nextFlightNumber: String?
    let nextFlightDestination: String?
    let nextDepartureLabel: String?

    let tripDayNumber: Int?
    let tripTotalDays: Int?
    let upcomingCities: [String]

    let timeUntilNextTransition: TimeInterval?

    /// Resolved delay minutes for the currently-matched flight leg (nil = no delay)
    let flightDelayMinutes: Int?
}

enum TripStateResolver {

    static func resolve(legs: [TripLeg], homeAirport: String?, flightDelayMinutes: Int? = nil, at now: Date) -> ResolvedPilotState {
        let sorted = legs.sorted { $0.startTime < $1.startTime }
        let delayInterval = TimeInterval((flightDelayMinutes ?? 0) * 60)

        // Primary candidate: standard time window (startTime <= now < endTime)
        // Flight legs take priority over reserve/hotStandby/event legs when overlapping
        let activeCandidates = sorted.filter { $0.startTime <= now && now < $0.endTime }
        let primaryCandidate = activeCandidates.first { $0.type == .flight }
            ?? activeCandidates.first { $0.type != .reserve && $0.type != .hotStandby && $0.type != .event }
            ?? activeCandidates.first

        // Per-leg delay: only extend the specifically-delayed leg (new Duty sends delayMinutes on the leg)
        let perLegDelayed: TripLeg? = sorted.first {
            $0.type == .flight &&
            ($0.delayMinutes ?? 0) > 0 &&
            $0.startTime <= now &&
            now < $0.endTime.addingTimeInterval(TimeInterval(($0.delayMinutes ?? 0) * 60))
        }

        // Fallback for old Duty versions without per-leg tagging:
        // If no leg has delayMinutes set but we have a global delay, use old behavior
        let legacyDelayed: TripLeg? = {
            guard delayInterval > 0 else { return nil }
            guard !sorted.contains(where: { ($0.delayMinutes ?? 0) > 0 }) else { return nil }
            return sorted.first {
                $0.type == .flight &&
                $0.startTime <= now &&
                now < $0.endTime.addingTimeInterval(delayInterval)
            }
        }()

        let delayedFlight = perLegDelayed ?? legacyDelayed

        // Delayed flight wins over ground legs that assumed on-time arrival
        let currentLeg = delayedFlight ?? primaryCandidate

        // Future legs: startTime >= now, excluding the current leg by id
        let currentLegId = currentLeg?.id
        let futureLegs = sorted.filter { $0.startTime >= now && $0.id != currentLegId }

        // If no current leg, we're home (before trip, after trip, or in a gap)
        guard let leg = currentLeg else {
            let nextFlight = futureLegs.first { $0.type == .flight }

            // Detect post-trip jumpseat chain: standalone flight(s) eventually reaching home
            if let home = homeAirport,
               let js = nextFlight,
               js.tripId == nil,
               let dep = js.departureAirport,
               dep != home,
               let jsArrival = js.arrivalAirport {
                let chainEnd: TripLeg?
                if jsArrival == home {
                    chainEnd = js
                } else if let end = followJumpseatChain(from: jsArrival, after: js.endTime, in: sorted),
                          end.arrivalAirport == home {
                    chainEnd = end
                } else {
                    chainEnd = nil
                }
                if let chainEnd {
                    return commutingHomeState(firstJumpseat: js, chainEnd: chainEnd, homeAirport: home, now: now)
                }
            }

            // Pilot at non-home airport between completed leg and next departure
            // (e.g., after pre-trip jumpseat lands at SDF, before trip's first leg starts)
            if let home = homeAirport {
                let pastLegs = sorted.filter { $0.endTime <= now }
                if let lastCompleted = pastLegs.last {
                    let lastAirport = lastCompleted.type == .flight
                        ? lastCompleted.arrivalAirport
                        : lastCompleted.airportCode
                    if let airport = lastAirport, airport != home,
                       let firstFuture = futureLegs.first {
                        let nextAirport = firstFuture.type == .flight
                            ? firstFuture.departureAirport
                            : firstFuture.airportCode
                        if nextAirport == airport {
                            return awaitingDepartureState(
                                airport: airport,
                                lastCompleted: lastCompleted,
                                futureLegs: futureLegs,
                                sorted: sorted,
                                homeAirport: home,
                                now: now
                            )
                        }
                    }
                }
            }

            return homeState(
                nextFlightLeg: nextFlight,
                sorted: sorted,
                homeAirport: homeAirport,
                now: now
            )
        }

        let displayStatus = statusString(for: leg.type)
        let isHome = leg.type == .home
        let isInFlight = leg.type == .flight

        // Home arrival: end time of last non-home leg in the current trip segment
        // Find the boundary: the first .home leg after the current leg marks the trip end
        let homeArrivalTime: Date? = {
            guard !isHome else { return nil }

            // Standalone leg (no trip association — e.g., post-trip jumpseat, reserve, training)
            if leg.tripId == nil {
                return leg.endTime
            }

            // Scope to current trip by tripId
            if let tripId = leg.tripId {
                let tripLegs = sorted.filter { $0.tripId == tripId && $0.type != .home }
                if let lastLeg = tripLegs.last {
                    let lastArrival = lastLeg.type == .flight ? lastLeg.arrivalAirport : lastLeg.airportCode
                    // Follow jumpseat chain from trip's final airport toward home
                    if let lastArrival,
                       let chainEnd = followJumpseatChain(from: lastArrival, after: lastLeg.endTime, in: sorted),
                       homeAirport == nil || chainEnd.arrivalAirport == homeAirport {
                        return chainEnd.endTime
                    }
                    return lastLeg.endTime
                }
            }

            // Fallback: segment-based logic for legs without tripId
            guard let currentIndex = sorted.firstIndex(where: { $0.id == leg.id }) else { return nil }
            let segmentEnd = sorted[currentIndex...].firstIndex { $0.type == .home } ?? sorted.endIndex
            return sorted[currentIndex..<segmentEnd].last { $0.type != .home }?.endTime
        }()

        // Home arrival label: derive from trip legs
        let homeArrivalLabel: String? = {
            guard homeArrivalTime != nil else { return nil }

            // Standalone reserve/hotStandby/training — "Released In"
            if leg.tripId == nil && (leg.type == .reserve || leg.type == .hotStandby || leg.type == .event) {
                return "Released In"
            }

            // Standalone leg (e.g., post-trip jumpseat)
            if leg.tripId == nil && leg.type == .flight {
                if let arrival = leg.arrivalAirport, arrival == homeAirport {
                    return "Back Home In"
                }
                return leg.arrivalCity.map { "\($0) In" }
            }

            guard let tripId = leg.tripId else { return nil }
            let tripLegs = sorted.filter { $0.tripId == tripId }
            let firstLeg = tripLegs.first
            let originAirport = firstLeg?.type == .flight ? firstLeg?.departureAirport : firstLeg?.airportCode
            let lastNonHome = tripLegs.filter { $0.type != .home }.last
            let lastArrival = lastNonHome?.type == .flight ? lastNonHome?.arrivalAirport : lastNonHome?.airportCode

            // Follow jumpseat chain from trip's final airport toward home
            let chainEnd: TripLeg? = {
                guard let lastArrival, let lastEnd = lastNonHome?.endTime else { return nil }
                return followJumpseatChain(from: lastArrival, after: lastEnd, in: sorted)
            }()

            if let chainEnd, homeAirport == nil || chainEnd.arrivalAirport == homeAirport {
                return "Back Home In"
            }

            let destAirport = lastNonHome?.type == .flight ? lastNonHome?.arrivalAirport : lastNonHome?.airportCode
            let city = lastNonHome?.type == .flight ? lastNonHome?.arrivalCity : lastNonHome?.city
            let goingHome = originAirport != nil && originAirport == destAirport
            if goingHome {
                return "Back Home In"
            } else {
                return city != nil ? "\(city!) In" : nil
            }
        }()

        // Home arrival city: city name for footer display (only for home-bound trips)
        let homeArrivalCity: String? = {
            guard homeArrivalTime != nil else { return nil }

            // Standalone leg (e.g., post-trip jumpseat)
            if leg.tripId == nil && leg.type == .flight {
                if let arrival = leg.arrivalAirport, arrival == homeAirport {
                    return leg.arrivalCity
                        ?? homeAirport.flatMap { AirportDataProvider.shared.airportInfo(forIataCode: $0)?.city }
                }
                return nil
            }

            guard let tripId = leg.tripId else { return nil }
            let tripLegs = sorted.filter { $0.tripId == tripId }
            let lastNonHome = tripLegs.filter { $0.type != .home }.last
            let lastArrival = lastNonHome?.type == .flight ? lastNonHome?.arrivalAirport : lastNonHome?.airportCode

            // Follow jumpseat chain from trip's final airport toward home
            let chainEnd: TripLeg? = {
                guard let lastArrival, let lastEnd = lastNonHome?.endTime else { return nil }
                return followJumpseatChain(from: lastArrival, after: lastEnd, in: sorted)
            }()

            if let chainEnd, homeAirport == nil || chainEnd.arrivalAirport == homeAirport {
                return chainEnd.arrivalCity
            }

            let firstLeg = tripLegs.first
            let originAirport = firstLeg?.type == .flight ? firstLeg?.departureAirport : firstLeg?.airportCode
            let destAirport = lastNonHome?.type == .flight ? lastNonHome?.arrivalAirport : lastNonHome?.airportCode
            let goingHome = originAirport != nil && originAirport == destAirport
            if goingHome {
                return lastNonHome?.type == .flight ? lastNonHome?.arrivalCity : lastNonHome?.city
            }
            return nil  // Non-home destination: no city in footer
        }()

        // Next departure: first future flight leg's start time
        let nextFlightLeg = futureLegs.first { $0.type == .flight }
        let nextDepartureTime = nextFlightLeg?.startTime

        // Chain through pre-trip jumpseat for departure label and destination
        let (resolvedDepartureLabel, resolvedFlightDestination) = Self.chainThroughJumpseat(
            nextFlightLeg: nextFlightLeg, sorted: sorted, homeAirport: homeAirport
        )

        // Upcoming cities from future legs (deduplicated, max 5)
        let upcomingCities = deriveUpcomingCities(from: futureLegs)

        // Time until this leg ends (next transition point)
        let legDelay = TimeInterval((leg.delayMinutes ?? 0) * 60)
        let effectiveEndTime = (leg.type == .flight && legDelay > 0)
            ? leg.endTime.addingTimeInterval(legDelay)
            : (leg.type == .flight && delayedFlight?.id == leg.id && delayInterval > 0
                ? leg.endTime.addingTimeInterval(delayInterval) // legacy fallback
                : leg.endTime)
        let timeUntilNextTransition = effectiveEndTime.timeIntervalSince(now)

        // Prefer our own airport lookup over leg data (Duty's lookup has gaps)
        let resolvedTimezone: String? = isInFlight
            ? (airportTimezone(leg.departureAirport) ?? leg.timezoneIdentifier)
            : (airportTimezone(leg.airportCode) ?? leg.timezoneIdentifier)
        let arrivalTimezone: String? = isInFlight
            ? airportTimezone(leg.arrivalAirport)
            : nil

        // Compute trip day dynamically using calendar days in base airport timezone
        let computedDayNumber: Int? = {
            guard let tripId = leg.tripId,
                  let total = leg.tripTotalDays else { return leg.tripDayNumber }
            let tripLegs = sorted.filter { $0.tripId == tripId && $0.type != .home }
            guard let firstLeg = tripLegs.first else { return leg.tripDayNumber }

            // Base timezone = first leg's departure airport (trips always start from base)
            let tzId = airportTimezone(firstLeg.departureAirport ?? firstLeg.airportCode)
            var calendar = Calendar.current
            if let tzId, let tz = TimeZone(identifier: tzId) {
                calendar.timeZone = tz
            }

            let tripStartDay = calendar.startOfDay(for: firstLeg.startTime)
            let today = calendar.startOfDay(for: now)
            let elapsed = calendar.dateComponents([.day], from: tripStartDay, to: today).day ?? 0
            return min(max(elapsed + 1, 1), total)
        }()

        // Resolved delay: the delay relevant to the current state
        // - In-flight on delayed flight → that flight's delay
        // - Layover/turn with delay on next flight → next flight's delay
        // - Legacy Duty (no per-leg tagging) → global delay for matched flight
        let resolvedDelay: Int? = {
            // Current leg is the delayed flight
            if let perLeg = delayedFlight, (perLeg.delayMinutes ?? 0) > 0 {
                return perLeg.delayMinutes
            }
            // Legacy fallback: current leg matched via global delay
            if delayedFlight != nil && delayInterval > 0 {
                return flightDelayMinutes
            }
            // Ground leg (layover/turn): check if next flight has a per-leg delay
            if !isInFlight, let nextFlight = nextFlightLeg, (nextFlight.delayMinutes ?? 0) > 0 {
                return nextFlight.delayMinutes
            }
            return nil
        }()

        return ResolvedPilotState(
            displayStatus: displayStatus,
            isHome: isHome,
            isInFlight: isInFlight,
            isOnDuty: !isHome,
            currentAirport: isInFlight ? leg.departureAirport : leg.airportCode,
            currentCity: isInFlight ? nil : leg.city,
            currentTimezone: resolvedTimezone,
            currentFlightNumber: isInFlight ? leg.flightNumber : nil,
            currentFlightDeparture: isInFlight ? leg.departureAirport : nil,
            currentFlightArrival: isInFlight ? leg.arrivalAirport : nil,
            currentFlightDepartureTime: isInFlight ? leg.startTime : nil,
            currentFlightArrivalTime: isInFlight ? leg.endTime : nil,
            currentFlightArrivalTimezone: arrivalTimezone,
            homeArrivalTime: homeArrivalTime,
            homeArrivalLabel: homeArrivalLabel,
            homeArrivalCity: homeArrivalCity,
            nextDepartureTime: nextDepartureTime,
            nextFlightNumber: nextFlightLeg?.flightNumber,
            nextFlightDestination: resolvedFlightDestination,
            nextDepartureLabel: resolvedDepartureLabel,
            tripDayNumber: computedDayNumber,
            tripTotalDays: leg.tripTotalDays,
            upcomingCities: upcomingCities,
            timeUntilNextTransition: timeUntilNextTransition > 0 ? timeUntilNextTransition : nil,
            flightDelayMinutes: resolvedDelay
        )
    }

    // MARK: - Private

    private static func homeState(nextFlightLeg: TripLeg?, sorted: [TripLeg], homeAirport: String?, now: Date) -> ResolvedPilotState {
        let (resolvedDepartureLabel, resolvedFlightDestination) = chainThroughJumpseat(
            nextFlightLeg: nextFlightLeg, sorted: sorted, homeAirport: homeAirport
        )

        // Derive home location info from homeAirport code
        let homeInfo = homeAirport.flatMap { AirportDataProvider.shared.airportInfo(forIataCode: $0) }
        let homeTZ = airportTimezone(homeAirport)

        return ResolvedPilotState(
            displayStatus: "Home",
            isHome: true,
            isInFlight: false,
            isOnDuty: false,
            currentAirport: homeAirport,
            currentCity: homeInfo?.city,
            currentTimezone: homeTZ,
            currentFlightNumber: nil,
            currentFlightDeparture: nil,
            currentFlightArrival: nil,
            currentFlightDepartureTime: nil,
            currentFlightArrivalTime: nil,
            currentFlightArrivalTimezone: nil,
            homeArrivalTime: nil,
            homeArrivalLabel: nil,
            homeArrivalCity: nil,
            nextDepartureTime: nextFlightLeg?.startTime,
            nextFlightNumber: nextFlightLeg?.flightNumber,
            nextFlightDestination: resolvedFlightDestination,
            nextDepartureLabel: resolvedDepartureLabel,
            tripDayNumber: nil,
            tripTotalDays: nil,
            upcomingCities: [],
            timeUntilNextTransition: nextFlightLeg.flatMap { leg in
                let interval = leg.startTime.timeIntervalSince(now)
                return interval > 0 ? interval : nil
            },
            flightDelayMinutes: nil
        )
    }

    private static func commutingHomeState(firstJumpseat js: TripLeg, chainEnd: TripLeg, homeAirport: String, now: Date) -> ResolvedPilotState {
        let depInfo = js.departureAirport.flatMap { AirportDataProvider.shared.airportInfo(forIataCode: $0) }
        let depTZ = airportTimezone(js.departureAirport)

        return ResolvedPilotState(
            displayStatus: "Commuting Home",
            isHome: false,
            isInFlight: false,
            isOnDuty: false,
            currentAirport: js.departureAirport,
            currentCity: js.departureCity ?? depInfo?.city,
            currentTimezone: depTZ ?? js.timezoneIdentifier,
            currentFlightNumber: nil,
            currentFlightDeparture: nil,
            currentFlightArrival: nil,
            currentFlightDepartureTime: nil,
            currentFlightArrivalTime: nil,
            currentFlightArrivalTimezone: nil,
            homeArrivalTime: chainEnd.endTime,
            homeArrivalLabel: "Back Home In",
            homeArrivalCity: chainEnd.arrivalCity ?? AirportDataProvider.shared.airportInfo(forIataCode: homeAirport)?.city,
            nextDepartureTime: js.startTime,
            nextFlightNumber: js.flightNumber,
            nextFlightDestination: js.arrivalAirport,
            nextDepartureLabel: nil,
            tripDayNumber: nil,
            tripTotalDays: nil,
            upcomingCities: [],
            timeUntilNextTransition: {
                let interval = js.startTime.timeIntervalSince(now)
                return interval > 0 ? interval : nil
            }(),
            flightDelayMinutes: nil
        )
    }

    private static func awaitingDepartureState(
        airport: String,
        lastCompleted: TripLeg,
        futureLegs: [TripLeg],
        sorted: [TripLeg],
        homeAirport: String,
        now: Date
    ) -> ResolvedPilotState {
        let airportInfo = AirportDataProvider.shared.airportInfo(forIataCode: airport)
        let city = (lastCompleted.type == .flight ? lastCompleted.arrivalCity : lastCompleted.city)
            ?? airportInfo?.city
        let timezone = airportTimezone(airport) ?? lastCompleted.timezoneIdentifier

        let nextFlight = futureLegs.first { $0.type == .flight }
        let tripContext = nextFlight?.tripId ?? lastCompleted.tripId

        let (homeTime, homeLabel, homeCity) = tripHomeArrival(
            tripId: tripContext,
            sorted: sorted,
            homeAirport: homeAirport
        )

        let (resolvedDepartureLabel, resolvedFlightDestination) = chainThroughJumpseat(
            nextFlightLeg: nextFlight, sorted: sorted, homeAirport: homeAirport
        )

        let tripDayNumber: Int? = {
            guard let tripId = tripContext else { return nil }
            let tripLegs = sorted.filter { $0.tripId == tripId && $0.type != .home }
            guard let firstLeg = tripLegs.first else { return nil }
            let total = firstLeg.tripTotalDays ?? tripLegs.last?.tripTotalDays
            guard let total else { return nil }
            let tzId = airportTimezone(firstLeg.departureAirport ?? firstLeg.airportCode)
            var calendar = Calendar.current
            if let tzId, let tz = TimeZone(identifier: tzId) {
                calendar.timeZone = tz
            }
            let tripStartDay = calendar.startOfDay(for: firstLeg.startTime)
            let today = calendar.startOfDay(for: now)
            let elapsed = calendar.dateComponents([.day], from: tripStartDay, to: today).day ?? 0
            return min(max(elapsed + 1, 1), total)
        }()

        let tripTotalDays: Int? = {
            guard let tripId = tripContext else { return nil }
            let tripLegs = sorted.filter { $0.tripId == tripId }
            return tripLegs.first?.tripTotalDays
        }()

        let upcomingCities = deriveUpcomingCities(from: futureLegs)

        return ResolvedPilotState(
            displayStatus: "Layover",
            isHome: false,
            isInFlight: false,
            isOnDuty: true,
            currentAirport: airport,
            currentCity: city,
            currentTimezone: timezone,
            currentFlightNumber: nil,
            currentFlightDeparture: nil,
            currentFlightArrival: nil,
            currentFlightDepartureTime: nil,
            currentFlightArrivalTime: nil,
            currentFlightArrivalTimezone: nil,
            homeArrivalTime: homeTime,
            homeArrivalLabel: homeLabel,
            homeArrivalCity: homeCity,
            nextDepartureTime: nextFlight?.startTime,
            nextFlightNumber: nextFlight?.flightNumber,
            nextFlightDestination: resolvedFlightDestination,
            nextDepartureLabel: resolvedDepartureLabel,
            tripDayNumber: tripDayNumber,
            tripTotalDays: tripTotalDays,
            upcomingCities: upcomingCities,
            timeUntilNextTransition: nextFlight.flatMap { leg in
                let interval = leg.startTime.timeIntervalSince(now)
                return interval > 0 ? interval : nil
            },
            flightDelayMinutes: nil
        )
    }

    /// Compute home arrival info (time, label, city) for a given trip context
    private static func tripHomeArrival(
        tripId: String?,
        sorted: [TripLeg],
        homeAirport: String
    ) -> (homeArrivalTime: Date?, homeArrivalLabel: String?, homeArrivalCity: String?) {
        guard let tripId else { return (nil, nil, nil) }

        let tripLegs = sorted.filter { $0.tripId == tripId && $0.type != .home }
        guard let lastLeg = tripLegs.last else { return (nil, nil, nil) }

        let lastArrival = lastLeg.type == .flight ? lastLeg.arrivalAirport : lastLeg.airportCode

        // Follow jumpseat chain from trip's final airport toward home
        let chainEnd: TripLeg? = {
            guard let lastArrival else { return nil }
            return followJumpseatChain(from: lastArrival, after: lastLeg.endTime, in: sorted)
        }()

        if let chainEnd, chainEnd.arrivalAirport == homeAirport {
            let city = chainEnd.arrivalCity
                ?? AirportDataProvider.shared.airportInfo(forIataCode: homeAirport)?.city
            return (chainEnd.endTime, "Back Home In", city)
        }

        let endTime = lastLeg.endTime
        let firstLeg = tripLegs.first
        let originAirport = firstLeg?.type == .flight ? firstLeg?.departureAirport : firstLeg?.airportCode
        let destAirport = lastLeg.type == .flight ? lastLeg.arrivalAirport : lastLeg.airportCode
        let goingHome = originAirport != nil && originAirport == destAirport

        if goingHome {
            let city = lastLeg.type == .flight ? lastLeg.arrivalCity : lastLeg.city
            return (endTime, "Back Home In", city)
        }

        let city = lastLeg.type == .flight ? lastLeg.arrivalCity : lastLeg.city
        let label = city.map { "\($0) In" }
        return (endTime, label, nil)
    }

    /// If the next flight is a standalone jumpseat (tripId == nil), chain through
    /// to the trip it connects to for the real destination and produce a departure label.
    /// Only chains if the jumpseat departs from the pilot's actual home airport.
    private static func chainThroughJumpseat(
        nextFlightLeg: TripLeg?,
        sorted: [TripLeg],
        homeAirport: String?
    ) -> (departureLabel: String?, flightDestination: String?) {
        guard let js = nextFlightLeg, js.tripId == nil,
              let jsArrival = js.arrivalAirport,
              homeAirport == nil || js.departureAirport == homeAirport else {
            return (nil, nextFlightLeg?.arrivalAirport)
        }
        // Jumpseat departure city = where pilot physically leaves from
        let label = js.departureCity.map { "Leaves From (\($0))" }
        // Follow multi-hop jumpseat chain to its end
        let chainEnd = followJumpseatChain(from: jsArrival, after: js.endTime, in: sorted)
        let finalAirport = chainEnd?.arrivalAirport ?? jsArrival
        let finalTime = chainEnd?.endTime ?? js.endTime
        // Find the trip flight that follows for the real destination
        if let tripFlight = sorted.first(where: {
            $0.tripId != nil && $0.type == .flight &&
            $0.startTime >= finalTime &&
            $0.departureAirport == finalAirport
        }) {
            return (label, tripFlight.arrivalAirport)
        }
        return (label, finalAirport)
    }

    /// Follow a chain of standalone jumpseat flights from a starting airport/time.
    /// Returns the final leg in the chain, or `nil` if no jumpseats depart from `startAirport`.
    private static func followJumpseatChain(
        from startAirport: String,
        after startTime: Date,
        in sorted: [TripLeg]
    ) -> TripLeg? {
        var currentAirport = startAirport
        var currentTime = startTime
        var lastJumpseat: TripLeg?
        var visited: Set<String> = [startAirport]

        while let next = sorted.first(where: {
            $0.tripId == nil && $0.type == .flight &&
            $0.startTime >= currentTime &&
            $0.departureAirport == currentAirport
        }) {
            guard let arrival = next.arrivalAirport, !visited.contains(arrival) else { break }
            visited.insert(arrival)
            lastJumpseat = next
            currentAirport = arrival
            currentTime = next.endTime
        }

        return lastJumpseat
    }

    private static func statusString(for type: TripLeg.LegType) -> String {
        switch type {
        case .flight:     return "In Flight"
        case .turn:       return "Turn"
        case .layover:    return "Layover"
        case .home:       return "Home"
        case .reserve:    return "Reserve"
        case .hotStandby: return "Hot Standby"
        case .event:      return "Training"
        case .unknown:    return "On Duty"
        }
    }

    // Mirrors Duty's TripParser.getTimeZoneForAirport — keep in sync
    private static let airportTimeZones: [String: String] = [
        // Eastern Time (EST/EDT)
        "ATL": "America/New_York",
        "BOS": "America/New_York",
        "BWI": "America/New_York",
        "CHS": "America/New_York",
        "CLT": "America/New_York",
        "CMH": "America/New_York",
        "CVG": "America/New_York",
        "DCA": "America/New_York",
        "DTW": "America/New_York",
        "EWR": "America/New_York",
        "FLL": "America/New_York",
        "FWA": "America/New_York",
        "IAD": "America/New_York",
        "IND": "America/New_York",
        "JFK": "America/New_York",
        "LGA": "America/New_York",
        "MCO": "America/New_York",
        "MIA": "America/New_York",
        "ORF": "America/New_York",
        "PBI": "America/New_York",
        "PHL": "America/New_York",
        "PIT": "America/New_York",
        "PVD": "America/New_York",
        "RDU": "America/New_York",
        "RIC": "America/New_York",
        "ROC": "America/New_York",
        "RSW": "America/New_York",
        "SBN": "America/New_York",
        "SDF": "America/New_York",
        "GATC": "America/New_York",
        "SRQ": "America/New_York",
        "SYR": "America/New_York",
        "TPA": "America/New_York",
        "BDL": "America/New_York",
        "BUF": "America/New_York",
        "CAE": "America/New_York",
        "CLE": "America/New_York",
        "DAY": "America/New_York",
        "GRR": "America/New_York",
        "GSO": "America/New_York",
        "GSP": "America/New_York",
        "JAX": "America/New_York",
        "LEX": "America/New_York",
        "MHT": "America/New_York",
        "ORH": "America/New_York",
        "PWM": "America/New_York",
        "SAV": "America/New_York",
        "TYS": "America/New_York",
        "ACY": "America/New_York",
        "AGS": "America/New_York",
        "ABY": "America/New_York",
        "ALB": "America/New_York",
        "AVL": "America/New_York",
        "AZO": "America/New_York",
        "BGR": "America/New_York",
        "BGM": "America/New_York",
        "CHA": "America/New_York",
        "CHO": "America/New_York",
        "CRW": "America/New_York",
        "FNT": "America/New_York",
        "GNV": "America/New_York",
        "HPN": "America/New_York",
        "ILM": "America/New_York",
        "ISO": "America/New_York",
        "LAN": "America/New_York",
        "MBS": "America/New_York",
        "MDT": "America/New_York",
        "MLB": "America/New_York",
        "PHF": "America/New_York",
        "TLH": "America/New_York",
        "TOL": "America/New_York",
        "TRI": "America/New_York",

        // Central Time (CST/CDT)
        "AUS": "America/Chicago",
        "BNA": "America/Chicago",
        "DAL": "America/Chicago",
        "DFW": "America/Chicago",
        "DSM": "America/Chicago",
        "GYY": "America/Chicago",
        "HOU": "America/Chicago",
        "IAH": "America/Chicago",
        "JAN": "America/Chicago",
        "MCI": "America/Chicago",
        "MDW": "America/Chicago",
        "MEM": "America/Chicago",
        "MKE": "America/Chicago",
        "MSP": "America/Chicago",
        "MSY": "America/Chicago",
        "OKC": "America/Chicago",
        "OMA": "America/Chicago",
        "ORD": "America/Chicago",
        "SAT": "America/Chicago",
        "STL": "America/Chicago",
        "TUL": "America/Chicago",
        "BHM": "America/Chicago",
        "ICT": "America/Chicago",
        "LIT": "America/Chicago",
        "MLI": "America/Chicago",
        "XNA": "America/Chicago",
        "ACT": "America/Chicago",
        "ALO": "America/Chicago",
        "AMA": "America/Chicago",
        "BIS": "America/Chicago",
        "BMI": "America/Chicago",
        "BRO": "America/Chicago",
        "CID": "America/Chicago",
        "CMI": "America/Chicago",
        "COU": "America/Chicago",
        "CRP": "America/Chicago",
        "DBQ": "America/Chicago",
        "DLH": "America/Chicago",
        "EVV": "America/Chicago",
        "FAR": "America/Chicago",
        "FSD": "America/Chicago",
        "FSM": "America/Chicago",
        "GFK": "America/Chicago",
        "GRB": "America/Chicago",
        "HRL": "America/Chicago",
        "HSV": "America/Chicago",
        "LBB": "America/Chicago",
        "LNK": "America/Chicago",
        "LRD": "America/Chicago",
        "LSE": "America/Chicago",
        "MAF": "America/Chicago",
        "MGM": "America/Chicago",
        "MLU": "America/Chicago",
        "PNS": "America/Chicago",
        "MOT": "America/Chicago",
        "MSN": "America/Chicago",
        "PIA": "America/Chicago",
        "RFD": "America/Chicago",
        "RST": "America/Chicago",
        "SGF": "America/Chicago",
        "SHV": "America/Chicago",
        "SUX": "America/Chicago",

        // Mountain Time (MST/MDT)
        "ABQ": "America/Denver",
        "BIL": "America/Denver",
        "BOI": "America/Denver",
        "BZN": "America/Denver",
        "COS": "America/Denver",
        "DEN": "America/Denver",
        "ELP": "America/Denver",
        "GJT": "America/Denver",
        "JAC": "America/Denver",
        "SLC": "America/Denver",
        "FCA": "America/Denver",
        "GTF": "America/Denver",
        "RAP": "America/Denver",

        // Arizona (no DST)
        "PHX": "America/Phoenix",
        "TUS": "America/Phoenix",

        // Pacific Time (PST/PDT)
        "BUR": "America/Los_Angeles",
        "FAT": "America/Los_Angeles",
        "LAS": "America/Los_Angeles",
        "LAX": "America/Los_Angeles",
        "LGB": "America/Los_Angeles",
        "OAK": "America/Los_Angeles",
        "ONT": "America/Los_Angeles",
        "PDX": "America/Los_Angeles",
        "BFI": "America/Los_Angeles",
        "PSP": "America/Los_Angeles",
        "RNO": "America/Los_Angeles",
        "SAN": "America/Los_Angeles",
        "SBD": "America/Los_Angeles",
        "SNA": "America/Los_Angeles",
        "SEA": "America/Los_Angeles",
        "SFO": "America/Los_Angeles",
        "SJC": "America/Los_Angeles",
        "SMF": "America/Los_Angeles",
        "MHR": "America/Los_Angeles",
        "GEG": "America/Los_Angeles",

        // Alaska Time
        "ANC": "America/Anchorage",
        "FAI": "America/Anchorage",
        "JNU": "America/Anchorage",

        // Hawaii Time (no DST)
        "HNL": "Pacific/Honolulu",
        "OGG": "Pacific/Honolulu",
        "KOA": "Pacific/Honolulu",
        "LIH": "Pacific/Honolulu",

        // US Territories
        "SJU": "America/Puerto_Rico",
        "STT": "America/St_Thomas",
        "STX": "America/St_Thomas",
        "GUM": "Pacific/Guam",
        "PPG": "Pacific/Pago_Pago",

        // Canada
        "YEG": "America/Edmonton",
        "YHM": "America/Toronto",
        "YHZ": "America/Halifax",
        "YMX": "America/Montreal",
        "YOW": "America/Toronto",
        "YUL": "America/Toronto",
        "YVR": "America/Vancouver",
        "YWG": "America/Winnipeg",
        "YYC": "America/Denver",
        "YYZ": "America/Toronto",
        "YYT": "America/St_Johns",

        // Mexico
        "CUN": "America/Cancun",
        "GDL": "America/Mexico_City",
        "MEX": "America/Mexico_City",
        "NLU": "America/Mexico_City",
        "PVR": "America/Mexico_City",
        "SJD": "America/Mazatlan",

        // Caribbean
        "AUA": "America/Aruba",
        "BGI": "America/Barbados",
        "CUR": "America/Curacao",
        "GCM": "America/Cayman",
        "KIN": "America/Jamaica",
        "MBJ": "America/Jamaica",
        "NAS": "America/Nassau",
        "PLS": "America/Grand_Turk",
        "POS": "America/Port_of_Spain",
        "PUJ": "America/Santo_Domingo",
        "SDQ": "America/Santo_Domingo",
        "SXM": "America/Lower_Princes",

        // Central America
        "BZE": "America/Belize",
        "GUA": "America/Guatemala",
        "LIR": "America/Costa_Rica",
        "MGA": "America/Managua",
        "PTY": "America/Panama",
        "SAL": "America/El_Salvador",
        "SAP": "America/Tegucigalpa",
        "SJO": "America/Costa_Rica",
        "TGU": "America/Tegucigalpa",

        // South America
        "BOG": "America/Bogota",
        "BSB": "America/Sao_Paulo",
        "CCS": "America/Caracas",
        "EZE": "America/Argentina/Buenos_Aires",
        "GIG": "America/Sao_Paulo",
        "GRU": "America/Sao_Paulo",
        "GYE": "America/Guayaquil",
        "LIM": "America/Lima",
        "MVD": "America/Montevideo",
        "SCL": "America/Santiago",
        "UIO": "America/Guayaquil",

        // Europe
        "AMS": "Europe/Amsterdam",
        "BCN": "Europe/Madrid",
        "BRU": "Europe/Brussels",
        "BUD": "Europe/Budapest",
        "CDG": "Europe/Paris",
        "CPH": "Europe/Copenhagen",
        "CGN": "Europe/Berlin",
        "LGG": "Europe/Brussels",
        "PRG": "Europe/Prague",
        "OSL": "Europe/Oslo",
        "ARN": "Europe/Stockholm",
        "HEL": "Europe/Helsinki",
        "ATH": "Europe/Athens",
        "IST": "Europe/Istanbul",
        "SAW": "Europe/Istanbul",
        "BSL": "Europe/Zurich",
        "BGY": "Europe/Rome",
        "BLL": "Europe/Copenhagen",
        "KRK": "Europe/Warsaw",
        "GDN": "Europe/Warsaw",
        "WRO": "Europe/Warsaw",
        "RIX": "Europe/Riga",
        "VNO": "Europe/Vilnius",
        "TLL": "Europe/Tallinn",
        "DUB": "Europe/Dublin",
        "DUS": "Europe/Berlin",
        "EMA": "Europe/London",
        "FCO": "Europe/Rome",
        "FRA": "Europe/Berlin",
        "GVA": "Europe/Zurich",
        "LGW": "Europe/London",
        "LHR": "Europe/London",
        "LIS": "Europe/Lisbon",
        "STN": "Europe/London",
        "MAD": "Europe/Madrid",
        "MAN": "Europe/London",
        "MUC": "Europe/Berlin",
        "MXP": "Europe/Rome",
        "VCE": "Europe/Rome",
        "ORY": "Europe/Paris",
        "SVO": "Europe/Moscow",
        "VIE": "Europe/Vienna",
        "WAW": "Europe/Warsaw",
        "ZRH": "Europe/Zurich",

        // Asia
        "BKK": "Asia/Bangkok",
        "BLR": "Asia/Kolkata",
        "CAN": "Asia/Shanghai",
        "CGK": "Asia/Jakarta",
        "CGO": "Asia/Shanghai",
        "CRK": "Asia/Manila",
        "DEL": "Asia/Kolkata",
        "DWC": "Asia/Dubai",
        "DXB": "Asia/Dubai",
        "HAN": "Asia/Ho_Chi_Minh",
        "HKG": "Asia/Hong_Kong",
        "ICN": "Asia/Seoul",
        "KIX": "Asia/Tokyo",
        "HND": "Asia/Tokyo",
        "KUL": "Asia/Kuala_Lumpur",
        "MNL": "Asia/Manila",
        "NRT": "Asia/Tokyo",
        "PEK": "Asia/Shanghai",
        "PNH": "Asia/Phnom_Penh",
        "PVG": "Asia/Shanghai",
        "SIN": "Asia/Singapore",
        "TPE": "Asia/Taipei",
        "SZX": "Asia/Shanghai",
        "XMN": "Asia/Shanghai",
        "CSX": "Asia/Shanghai",
        "WUH": "Asia/Shanghai",
        "ZGZJ": "Asia/Shanghai",

        // Oceania
        "AKL": "Pacific/Auckland",
        "BNE": "Australia/Brisbane",
        "MEL": "Australia/Melbourne",
        "PER": "Australia/Perth",
        "SYD": "Australia/Sydney",

        // Africa
        "JNB": "Africa/Johannesburg",
        "CAI": "Africa/Cairo",
        "CPT": "Africa/Johannesburg",
        "NBO": "Africa/Nairobi",
        "ADD": "Africa/Addis_Ababa",
        "LOS": "Africa/Lagos",
        "ACC": "Africa/Accra",
        "CMN": "Africa/Casablanca",
        "RBA": "Africa/Casablanca",
        "ALG": "Africa/Algiers",

        // Middle East
        "TLV": "Asia/Jerusalem",
        "AMM": "Asia/Amman",
        "DOH": "Asia/Qatar",
        "AUH": "Asia/Dubai",
        "SHJ": "Asia/Dubai",
        "KWI": "Asia/Kuwait",
        "JED": "Asia/Riyadh",
        "RUH": "Asia/Riyadh",
        "BAH": "Asia/Bahrain",
        "MCT": "Asia/Muscat",

        // China Special Cases
        "ACEN": "Asia/Shanghai",
    ]

    private static func airportTimezone(_ airport: String?) -> String? {
        guard let airport else { return nil }
        return airportTimeZones[airport.uppercased()]
    }

    private static func deriveUpcomingCities(from futureLegs: [TripLeg]) -> [String] {
        var seen = Set<String>()
        var cities: [String] = []
        for leg in futureLegs {
            // Use arrivalCity for flights, city for ground legs
            let city = leg.type == .flight ? leg.arrivalCity : leg.city
            guard let c = city, !c.isEmpty, !seen.contains(c) else { continue }
            seen.insert(c)
            cities.append(c)
            if cities.count >= 5 { break }
        }
        return cities
    }
}
