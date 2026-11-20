//
//  TripMap+Status.swift
//  CrewLuve
//
//  Which trip the status screen's map shows (moving map spec §5.1, §12):
//  - at home or base, the next trip, unless it's a night there in the middle of a trip: that trip is under way;
//  - at home or base within a day of a trip ending, that trip's recap, unless the next trip leaves within 12 hours;
//  - on a trip, the trip under way by its id, with the drives and jumpseats within 12 hours of its flights, and
//    between trips the flight or drive in motion, as the website's tripMapFor picks them (`TripMapLegs`);
//  - from a CrewLu too old to send legs, just the flight in the air.
//

import CoreLocation

extension TripMap {

    /// The status screen's trip map, or nil when there's nothing to draw. `flights` is each flight with live data,
    /// by its leg's id, as the screen's model hands them on with the status (Stage 3 spec §11).
    init?(status: SharedPilotStatus, flights: [String: MapFlight] = [:], at now: Date) {
        let airports = AirportDataProvider.shared
        let coordinate: (String) -> CLLocationCoordinate2D? = { code in
            airports.airportInfo(forIataCode: code).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }
        let tripLegs = status.tripLegs
        let isSettled = status.displayStatus.isSettled
        // The recap waits for home: a commuter at base still has the way home ahead.
        let recapLegs = status.displayStatus == .home ? Self.recapLegs(in: tripLegs, at: now) : nil
        let legs: [TripLeg]
        if let recapLegs {
            legs = recapLegs
        } else if isSettled {
            guard let trip = UpcomingTripInfo.from(tripLegs: tripLegs, at: now, homeAirportCode: status.homeAirportCode) else { return nil }
            legs = tripLegs.filter { $0.tripId == trip.tripId }
        } else if let underWay = TripMapLegs.ofTripUnderWay(in: tripLegs, at: now) {
            legs = underWay
        } else {
            // Between trips, the flight or drive in motion. With no legs, or legs that no longer cover now (stale, or
            // a flight running late past them), the summary's flight in the air, as the old in-flight map drew it.
            let inMotion = TripMapLegs.inMotion(in: tripLegs, at: now) ?? Self.currentFlightLeg(of: status)
            legs = inMotion.map { [$0] } ?? []
        }
        // A night at home or base in the middle of a trip (CrewLu's `.home` or `.base` leg between two duty periods)
        // reads as settled, and its upcoming trip is the rest of the trip under way. Only a trip with no leg started yet
        // is the next trip; shown as one, the trip under way would start on a date already past.
        let isNextTrip = recapLegs == nil && isSettled && legs.allSatisfy { $0.startTime > now }
        guard let map = TripMap.make(tripLegs: legs, isNextTrip: isNextTrip, isRecap: recapLegs != nil,
                                     homeAirportCode: status.homeAirportCode ?? status.baseAirportCode,
                                     baseAirportCode: status.baseAirportCode,
                                     isWaitingAtBase: status.displayStatus == .base,
                                     legacyDelayMinutes: status.flightDelayMinutes, flights: flights, at: now,
                                     coordinate: coordinate) else { return nil }
        self = map
    }

    /// How long a recap shows after its trip's last leg ends (Stage 2 spec §8.1).
    static let recapDuration: TimeInterval = 24 * 3600
    /// A next trip leaving this soon takes over from the recap.
    static let recapYieldsWithin: TimeInterval = 12 * 3600

    /// The legs of the trip whose last leg ended in the past 24 hours, or nil when there's none, another trip is under
    /// way (a night at home in the middle of it), or the next trip leaves within 12 hours. Legs with no trip, like a
    /// standalone jumpseat, aren't a trip.
    static func recapLegs(in tripLegs: [TripLeg], at now: Date) -> [TripLeg]? {
        let trips = Dictionary(grouping: tripLegs.filter { $0.tripId != nil }, by: \.tripId)
        let isTripUnderWay = trips.values.contains { legs in
            (legs.map(\.startTime).min() ?? .distantFuture) <= now && (legs.map(\.endTime).max() ?? .distantPast) > now
        }
        guard !isTripUnderWay else { return nil }
        let finished = trips.values.compactMap { legs -> (legs: [TripLeg], end: Date)? in
            guard let end = legs.map(\.endTime).max(), end <= now, now.timeIntervalSince(end) < recapDuration else { return nil }
            return (legs, end)
        }
        guard let recap = finished.max(by: { $0.end < $1.end }) else { return nil }
        let nextDeparture = tripLegs.filter { $0.tripId != nil && $0.startTime > now }.map(\.startTime).min()
        if let nextDeparture, nextDeparture.timeIntervalSince(now) <= recapYieldsWithin { return nil }
        return recap.legs
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
