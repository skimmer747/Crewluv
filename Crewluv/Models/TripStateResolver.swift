//
//  TripStateResolver.swift
//  CrewLuv
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

    let homeArrivalTime: Date?
    let nextDepartureTime: Date?
    let nextFlightNumber: String?
    let nextFlightDestination: String?

    let tripDayNumber: Int?
    let tripTotalDays: Int?
    let upcomingCities: [String]

    let timeUntilNextTransition: TimeInterval?
}

enum TripStateResolver {

    static func resolve(legs: [TripLeg], at now: Date) -> ResolvedPilotState {
        let sorted = legs.sorted { $0.startTime < $1.startTime }

        // Find the current leg: startTime <= now < endTime
        let currentLeg = sorted.first { $0.startTime <= now && now < $0.endTime }

        // Future legs: startTime >= now, excluding the current leg by id
        let currentLegId = currentLeg?.id
        let futureLegs = sorted.filter { $0.startTime >= now && $0.id != currentLegId }

        // If no current leg, we're home (before trip, after trip, or in a gap)
        guard let leg = currentLeg else {
            return homeState(
                nextFlightLeg: futureLegs.first { $0.type == .flight },
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
            guard let currentIndex = sorted.firstIndex(where: { $0.id == leg.id }) else { return nil }
            // Find where this trip segment ends (next .home leg or end of array)
            let segmentEnd = sorted[currentIndex...].firstIndex { $0.type == .home } ?? sorted.endIndex
            // Last non-home leg within this segment
            return sorted[currentIndex..<segmentEnd].last { $0.type != .home }?.endTime
        }()

        // Next departure: first future flight leg's start time
        let nextFlightLeg = futureLegs.first { $0.type == .flight }
        let nextDepartureTime = nextFlightLeg?.startTime

        // Upcoming cities from future legs (deduplicated, max 5)
        let upcomingCities = deriveUpcomingCities(from: futureLegs)

        // Time until this leg ends (next transition point)
        let timeUntilNextTransition = leg.endTime.timeIntervalSince(now)

        return ResolvedPilotState(
            displayStatus: displayStatus,
            isHome: isHome,
            isInFlight: isInFlight,
            isOnDuty: !isHome,
            currentAirport: isInFlight ? leg.departureAirport : leg.airportCode,
            currentCity: isInFlight ? nil : leg.city,
            currentTimezone: leg.timezoneIdentifier,
            currentFlightNumber: isInFlight ? leg.flightNumber : nil,
            currentFlightDeparture: isInFlight ? leg.departureAirport : nil,
            currentFlightArrival: isInFlight ? leg.arrivalAirport : nil,
            currentFlightDepartureTime: isInFlight ? leg.startTime : nil,
            currentFlightArrivalTime: isInFlight ? leg.endTime : nil,
            homeArrivalTime: homeArrivalTime,
            nextDepartureTime: nextDepartureTime,
            nextFlightNumber: nextFlightLeg?.flightNumber,
            nextFlightDestination: nextFlightLeg?.arrivalAirport,
            tripDayNumber: leg.tripDayNumber,
            tripTotalDays: leg.tripTotalDays,
            upcomingCities: upcomingCities,
            timeUntilNextTransition: timeUntilNextTransition > 0 ? timeUntilNextTransition : nil
        )
    }

    // MARK: - Private

    private static func homeState(nextFlightLeg: TripLeg?, now: Date) -> ResolvedPilotState {
        ResolvedPilotState(
            displayStatus: "Home",
            isHome: true,
            isInFlight: false,
            isOnDuty: false,
            currentAirport: nil,
            currentCity: nil,
            currentTimezone: nil,
            currentFlightNumber: nil,
            currentFlightDeparture: nil,
            currentFlightArrival: nil,
            currentFlightDepartureTime: nil,
            currentFlightArrivalTime: nil,
            homeArrivalTime: nil,
            nextDepartureTime: nextFlightLeg?.startTime,
            nextFlightNumber: nextFlightLeg?.flightNumber,
            nextFlightDestination: nextFlightLeg?.arrivalAirport,
            tripDayNumber: nil,
            tripTotalDays: nil,
            upcomingCities: [],
            timeUntilNextTransition: nextFlightLeg.flatMap { leg in
                let interval = leg.startTime.timeIntervalSince(now)
                return interval > 0 ? interval : nil
            }
        )
    }

    private static func statusString(for type: TripLeg.LegType) -> String {
        switch type {
        case .flight:     return "In Flight"
        case .turn:       return "Turn"
        case .layover:    return "Layover"
        case .home:       return "Home"
        case .reserve:    return "Reserve"
        case .hotStandby: return "Hot Standby"
        case .event:      return "Event"
        case .unknown:    return "On Duty"
        }
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
