//
//  LiveLegs.swift
//  CrewLuve
//
//  One landing time (Stage 3 spec §7.1). The status screen's model hands the summary's legs to everything that
//  reads them: the status, the map, the countdown, the narrative and the trip cards. Before it does, each flight
//  with live data gets its real times here in place of the schedule's, so no card works them out itself.
//

import CoreLocation

nonisolated enum LiveLegs {

    /// The summary's flights for `LiveFlightSource` to watch: each one's id, and its gate times moved by its delay.
    /// Legs that are one flight, with the same number, departure airport and scheduled departure, are answered
    /// once by Crewlu Cloud, under the first of their ids in text order: only that one is watched, or the others'
    /// windows would stay open after the flight had landed.
    static func watched(in legs: [TripLeg]) -> [LiveFlightSource.Leg] {
        var firstOfEachFlight: [String: TripLeg] = [:]
        for leg in legs where leg.type == .flight {
            let flight = "\(leg.flightNumber ?? "")|\(leg.departureAirport ?? "")|\(leg.startTime.timeIntervalSince1970)"
            if let kept = firstOfEachFlight[flight], kept.id <= leg.id { continue }
            firstOfEachFlight[flight] = leg
        }
        return firstOfEachFlight.values
            .sorted { ($0.startTime, $0.id) < ($1.startTime, $1.id) }
            .map {
                LiveFlightSource.Leg(id: $0.id, departure: $0.effectiveStart, arrival: $0.effectiveEnd)
            }
    }

    /// Each flight of `legs` that Crewlu Cloud answered, by its leg's id: its plan, from its scheduled times moved
    /// by its own delay, with the path and the record made from the answer.
    /// - Parameters:
    ///   - legacyDelayMinutes: the summary-wide delay of a CrewLu that doesn't tag legs. While one is in effect
    ///     there's no leg to hold the real times against, so no flight has live data and the schedule shows.
    ///   - answered: `LiveFlightSource.flights`.
    ///   - clockOffset: `LiveFlightSource.clockOffset`.
    ///   - coordinate: where an airport is, by code.
    static func flights(
        for legs: [TripLeg], legacyDelayMinutes: Int?, answered: [String: LiveFlight], clockOffset: TimeInterval,
        coordinate: (String) -> CLLocationCoordinate2D?
    ) -> [String: MapFlight] {
        let isDelaySummaryWide = (legacyDelayMinutes ?? 0) != 0 && !legs.contains { ($0.delayMinutes ?? 0) != 0 }
        guard !answered.isEmpty, !isDelaySummaryWide else { return [:] }
        var flights: [String: MapFlight] = [:]
        for leg in legs where leg.type == .flight {
            guard let live = answered[leg.id],
                  let origin = leg.departureAirport.flatMap(coordinate),
                  let destination = leg.arrivalAirport.flatMap(coordinate) else { continue }
            flights[leg.id] = MapFlight(departure: leg.effectiveStart, arrival: leg.effectiveEnd,
                                        from: origin, to: destination, live: live, clockOffset: clockOffset)
        }
        return flights
    }

    /// `legs` with each live flight's real times at `now`, this device's time, in place of the schedule's
    /// (`LiveProgress.start` and `.end`). The wait before such a flight ends, and the wait after it starts, where
    /// the flight does: the wait next in line, when its own edge is where the flight's was. A leg's delay stays on
    /// it, and its times are set so that the delay moves them to the real ones, as every reader of a leg expects.
    /// What comes back is what `SharedPilotStatus.tripLegs` reads from it again, unchanged.
    static func replacingTimes(in legs: [TripLeg], with flights: [String: MapFlight], at now: Date) -> [TripLeg] {
        guard !flights.isEmpty else { return legs }
        var replaced = legs
        // The legs that follow one another: flights, drives and CrewLu's waits, in the order they start.
        let chain = legs.indices
            .filter { legs[$0].type == .flight || legs[$0].type == .drive || waitTypes.contains(legs[$0].type) }
            .sorted { (legs[$0].startTime, $0) < (legs[$1].startTime, $1) }
        for (place, index) in chain.enumerated() {
            let leg = legs[index]
            guard leg.type == .flight, let flight = flights[leg.id] else { continue }
            let progress = flight.progress(at: now)
            let isStartReal = progress.start != flight.plan.departure
            let isEndReal = progress.end != flight.plan.arrival
            guard isStartReal || isEndReal, progress.end > progress.start else { continue }
            let writtenStart = isStartReal ? progress.start.addingTimeInterval(-leg.delay) : leg.startTime
            replaced[index] = leg.with(startTime: writtenStart,
                                       endTime: isEndReal ? progress.end.addingTimeInterval(-leg.delay) : leg.endTime)
            if isStartReal, place > 0 {
                let before = replaced[chain[place - 1]]
                // The wait ends at the flight's real start. A late flight's written start is before its real one,
                // by its delay, and its wait ends there instead, as CrewLu writes every delayed flight's:
                // `SharedPilotStatus.tripLegs` would cut it there anyway, since it ends any wait a flight's written
                // start falls in.
                let end = min(progress.start, writtenStart)
                if waitTypes.contains(before.type), meets(before.endTime, leg.startTime, leg.effectiveStart),
                   end > before.startTime {
                    replaced[chain[place - 1]] = before.with(startTime: before.startTime, endTime: end)
                }
            }
            if isEndReal, place + 1 < chain.count {
                let after = replaced[chain[place + 1]]
                if waitTypes.contains(after.type), meets(after.startTime, leg.endTime, leg.effectiveEnd),
                   progress.end < after.endTime {
                    replaced[chain[place + 1]] = after.with(startTime: progress.end, endTime: after.endTime)
                }
            }
        }
        return replaced
    }

    /// Whether the gate arrival `leg` shows is the real plane's estimate, which the words mark with "about"
    /// (spec §9).
    static func isArrivalEstimated(of leg: TripLeg, in flights: [String: MapFlight]) -> Bool {
        flights[leg.id]?.isEstimate(leg.effectiveEnd) ?? false
    }

    /// The legs as the status carries them, written as `CloudSummary` writes them: sorted keys give the same legs
    /// the same bytes on every run.
    static func blob(_ legs: [TripLeg]) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(legs)
    }

    // MARK: - Private

    /// CrewLu's waits on the ground, which a flight's real times move the edges of.
    private static let waitTypes: Set<TripLeg.LegType> = [.turn, .layover, .home, .base]

    /// Whether a wait's `edge` is where its flight's was, within a minute: at the scheduled time, as CrewLu writes
    /// its waits, or at that time moved by the flight's delay. A wait that begins later, after an event say, isn't
    /// the flight's to move.
    private static func meets(_ edge: Date, _ scheduled: Date, _ delayed: Date) -> Bool {
        abs(edge.timeIntervalSince(scheduled)) <= 60 || abs(edge.timeIntervalSince(delayed)) <= 60
    }
}

nonisolated private extension TripLeg {
    /// The leg's own reported delay, in seconds: early when negative.
    var delay: TimeInterval { TimeInterval((delayMinutes ?? 0) * 60) }

    /// Leaving the gate and reaching it, moved by the leg's own delay, as `TripStateResolver` moves them.
    var effectiveStart: Date { startTime.addingTimeInterval(delay) }
    var effectiveEnd: Date { endTime.addingTimeInterval(delay) }

    /// The leg at other times.
    func with(startTime: Date, endTime: Date) -> TripLeg {
        TripLeg(id: id, tripId: tripId, type: type, startTime: startTime, endTime: endTime, airportCode: airportCode,
                city: city, timezoneIdentifier: timezoneIdentifier, arrivalTimezoneIdentifier: arrivalTimezoneIdentifier,
                flightNumber: flightNumber, departureAirport: departureAirport, arrivalAirport: arrivalAirport,
                departureCity: departureCity, arrivalCity: arrivalCity, tripDayNumber: tripDayNumber,
                tripTotalDays: tripTotalDays, delayMinutes: delayMinutes, airlineCode: airlineCode, label: label)
    }
}
