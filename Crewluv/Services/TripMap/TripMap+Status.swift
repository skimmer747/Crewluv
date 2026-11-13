//
//  TripMap+Status.swift
//  CrewLuve
//
//  Which trip the status screen's map shows (moving map spec §5.1, §12):
//  - at home or base, the next trip, unless it's a night there in the middle of a trip: that trip is under way;
//  - on a trip, that trip's legs;
//  - from a CrewLu too old to send legs, just the flight in the air.
//

import CoreLocation

extension TripMap {

    /// The status screen's trip map, or nil when there's nothing to draw.
    init?(status: SharedPilotStatus, at now: Date) {
        let airports = AirportDataProvider.shared
        let coordinate: (String) -> CLLocationCoordinate2D? = { code in
            airports.airportInfo(forIataCode: code).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }
        let isSettled = status.displayStatus.isSettled
        let legs: [TripLeg]
        if isSettled {
            guard let trip = UpcomingTripInfo.from(tripLegs: status.tripLegs, at: now, homeAirportCode: status.homeAirportCode) else { return nil }
            legs = status.tripLegs.filter { $0.tripId == trip.tripId }
        } else if status.hasTripLegs {
            let segment = TripStateResolver.contiguousSegment(covering: now, in: status.tripLegs)
            // Legs that no longer cover now (stale, or a flight running late past them) still leave the
            // summary's flight in the air to draw, as the old in-flight map did.
            legs = segment.isEmpty ? (Self.currentFlightLeg(of: status).map { [$0] } ?? []) : segment
        } else {
            legs = Self.currentFlightLeg(of: status).map { [$0] } ?? []
        }
        // A night at home or base in the middle of a trip (CrewLu's `.home` or `.base` leg between two duty periods)
        // reads as settled, and its upcoming trip is the rest of the trip under way. Only a trip with no leg started yet
        // is the next trip; shown as one, the trip under way would start on a date already past.
        let isNextTrip = isSettled && legs.allSatisfy { $0.startTime > now }
        guard let map = TripMap.make(tripLegs: legs, isNextTrip: isNextTrip,
                                     homeAirportCode: status.homeAirportCode ?? status.baseAirportCode,
                                     legacyDelayMinutes: status.flightDelayMinutes, at: now, coordinate: coordinate) else { return nil }
        self = map
    }

    /// The flight in the air, from the summary's `currentFlight*` fields: for a CrewLu that sends no legs,
    /// or legs that don't cover now.
    private static func currentFlightLeg(of status: SharedPilotStatus) -> TripLeg? {
        guard status.displayStatus == .inFlight,
              let departure = status.currentFlightDeparture, let arrival = status.currentFlightArrival,
              let start = status.currentFlightDepartureTime, let end = status.currentFlightArrivalTime else { return nil }
        return TripLeg(
            id: "current-flight", tripId: nil, type: .flight, startTime: start, endTime: end,
            airportCode: nil, city: nil, timezoneIdentifier: status.currentTimezone,
            arrivalTimezoneIdentifier: status.currentFlightArrivalTimezone, flightNumber: status.currentFlightNumber,
            departureAirport: departure, arrivalAirport: arrival, departureCity: nil, arrivalCity: nil,
            tripDayNumber: nil, tripTotalDays: nil, delayMinutes: nil, airlineCode: nil, label: nil
        )
    }
}
