//
//  UpcomingTripInfo.swift
//  Crewluv
//
//  Derives next-trip details from existing [TripLeg] data
//

import Foundation

struct UpcomingTripInfo {
    let tripId: String
    let departureDate: Date
    let endDate: Date
    let durationDays: Int
    let departureCity: String?
    let firstDestinationCity: String?
    let cityRoute: [String]       // ordered IATA codes, deduped
    let tripType: TripType
    let commuteCity: String?      // non-nil when a pre-trip commute from home was detected

    enum TripType: String {
        case line = "Line Trip"
        case reserve = "Reserve"
        case hotStandby = "Hot Standby"
        case training = "Training"
    }

    /// Derive next trip info from trip legs at a given date
    static func from(
        tripLegs: [TripLeg],
        at now: Date,
        homeAirportCode: String? = nil
    ) -> UpcomingTripInfo? {
        // Filter to future legs with a tripId (skip standalone jumpseats)
        let futureLegs = tripLegs
            .filter { $0.tripId != nil && $0.startTime > now }
            .sorted { $0.startTime < $1.startTime }

        guard let firstLeg = futureLegs.first,
              let tripId = firstLeg.tripId else { return nil }

        // Group: all legs belonging to the same trip
        let tripOnlyLegs = futureLegs.filter { $0.tripId == tripId }

        guard let lastLeg = tripOnlyLegs.last else { return nil }

        // Infer trip type from leg types
        let tripType: TripType = {
            if tripOnlyLegs.contains(where: { $0.type == .reserve }) { return .reserve }
            if tripOnlyLegs.contains(where: { $0.type == .hotStandby }) { return .hotStandby }
            if tripOnlyLegs.contains(where: { $0.type == .event }) { return .training }
            return .line
        }()

        // Build city route from flight legs (departure + arrivals, deduplicated in order)
        let flightLegs = tripOnlyLegs.filter { $0.type == .flight }
        var cityRoute: [String] = []
        for leg in flightLegs {
            if let dep = leg.departureAirport, !cityRoute.contains(dep) {
                cityRoute.append(dep)
            }
            if let arr = leg.arrivalAirport, !cityRoute.contains(arr) {
                cityRoute.append(arr)
            }
        }

        // Detect pre-trip commute: a standalone jumpseat from home to the trip's first departure airport
        let tripDepartureAirport = flightLegs.first?.departureAirport
        var commuteCity: String?
        var commuteDepartureDate: Date?
        var commuteDepartureCity: String?
        var commuteAirportCode: String?

        if let home = homeAirportCode, let tripDep = tripDepartureAirport, home != tripDep {
            let commuteLeg = tripLegs
                .filter {
                    $0.tripId == nil &&
                    $0.type == .flight &&
                    $0.startTime > now &&
                    $0.startTime < firstLeg.startTime &&
                    $0.departureAirport == home &&
                    $0.arrivalAirport == tripDep
                }
                .sorted { $0.startTime < $1.startTime }
                .first

            if let commute = commuteLeg {
                commuteCity = commute.arrivalCity
                commuteDepartureDate = commute.startTime
                commuteDepartureCity = commute.departureCity
                commuteAirportCode = commute.departureAirport
            }
        }

        // If commute found, prepend home airport to city route
        if let homeCode = commuteAirportCode, !cityRoute.contains(homeCode) {
            cityRoute.insert(homeCode, at: 0)
        }

        // Compute duration as calendar days
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: firstLeg.startTime)
        let endDay = calendar.startOfDay(for: lastLeg.endTime)
        let durationDays = max(1, (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1)

        // Use commute departure info when available, otherwise fall back to trip's first flight
        let departureCity = commuteDepartureCity ?? flightLegs.first?.departureCity
        let departureDate = commuteDepartureDate ?? firstLeg.startTime

        // First destination city from first flight leg of the actual trip
        let firstDestinationCity = flightLegs.first?.arrivalCity

        return UpcomingTripInfo(
            tripId: tripId,
            departureDate: departureDate,
            endDate: lastLeg.endTime,
            durationDays: durationDays,
            departureCity: departureCity,
            firstDestinationCity: firstDestinationCity,
            cityRoute: cityRoute,
            tripType: tripType,
            commuteCity: commuteCity
        )
    }
}
