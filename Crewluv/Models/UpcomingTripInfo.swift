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

    enum TripType: String {
        case line = "Line Trip"
        case reserve = "Reserve"
        case hotStandby = "Hot Standby"
        case training = "Training"
    }

    /// Derive next trip info from trip legs at a given date
    static func from(tripLegs: [TripLeg], at now: Date) -> UpcomingTripInfo? {
        // Filter to future legs with a tripId (skip standalone jumpseats)
        let futureLegs = tripLegs
            .filter { $0.tripId != nil && $0.startTime > now }
            .sorted { $0.startTime < $1.startTime }

        guard let firstLeg = futureLegs.first,
              let tripId = firstLeg.tripId else { return nil }

        // Group: all legs belonging to the same trip
        let tripLegs = futureLegs.filter { $0.tripId == tripId }

        guard let lastLeg = tripLegs.last else { return nil }

        // Infer trip type from leg types
        let tripType: TripType = {
            if tripLegs.contains(where: { $0.type == .reserve }) { return .reserve }
            if tripLegs.contains(where: { $0.type == .hotStandby }) { return .hotStandby }
            if tripLegs.contains(where: { $0.type == .event }) { return .training }
            return .line
        }()

        // Build city route from flight legs (departure + arrivals, deduplicated in order)
        let flightLegs = tripLegs.filter { $0.type == .flight }
        var cityRoute: [String] = []
        for leg in flightLegs {
            if let dep = leg.departureAirport, !cityRoute.contains(dep) {
                cityRoute.append(dep)
            }
            if let arr = leg.arrivalAirport, !cityRoute.contains(arr) {
                cityRoute.append(arr)
            }
        }

        // Compute duration as calendar days
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: firstLeg.startTime)
        let endDay = calendar.startOfDay(for: lastLeg.endTime)
        let durationDays = max(1, (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1)

        // Departure city from first flight leg
        let departureCity = flightLegs.first?.departureCity

        // First destination city from first flight leg
        let firstDestinationCity = flightLegs.first?.arrivalCity

        return UpcomingTripInfo(
            tripId: tripId,
            departureDate: firstLeg.startTime,
            endDate: lastLeg.endTime,
            durationDays: durationDays,
            departureCity: departureCity,
            firstDestinationCity: firstDestinationCity,
            cityRoute: cityRoute,
            tripType: tripType
        )
    }
}
