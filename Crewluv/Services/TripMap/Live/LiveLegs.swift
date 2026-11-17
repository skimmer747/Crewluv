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
        firstOfEachFlight(in: legs).values
            .sorted { ($0.startTime, $0.id) < ($1.startTime, $1.id) }
            .map {
                LiveFlightSource.Leg(id: $0.id, departure: $0.effectiveStart, arrival: $0.effectiveEnd)
            }
    }

    /// Each flight of `legs` that Crewlu Cloud answered, by its leg's id: its plan, from its scheduled times moved
    /// by its own delay, with the path and the record made from the answer. Legs that are one flight share its
    /// answer, so each shows the real plane and none is left on the schedule beside it.
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
        let answeredUnder = firstOfEachFlight(in: legs)
        var flights: [String: MapFlight] = [:]
        for leg in legs where leg.type == .flight {
            guard let first = answeredUnder[flightKey(of: leg)], let live = answered[first.id],
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

    /// The legs whose gate arrival, as `legs` show it, is the real plane's estimate, by id: the schedule's list says
    /// "about" before it, "7:00am est – about 9:10am est", as the status screen does (Stage 3 spec §9).
    static func estimatedArrivals(in legs: [TripLeg], flights: [String: MapFlight]) -> Set<String> {
        guard !flights.isEmpty else { return [] }
        return Set(legs.filter { isArrivalEstimated(of: $0, in: flights) }.map(\.id))
    }

    /// When the flight between its gates at `now` reaches its gate, while that time is the real plane's estimate:
    /// the time the cards say "about" of (spec §9). Nil with no such flight.
    static func estimatedArrival(in legs: [TripLeg], flights: [String: MapFlight], at now: Date) -> Date? {
        guard !flights.isEmpty else { return nil }
        return legs.first { leg in
            leg.type == .flight && leg.effectiveStart <= now && now < leg.effectiveEnd
                && isArrivalEstimated(of: leg, in: flights)
        }?.effectiveEnd
    }

    /// The flight between its gates at `now` whose real plane is still on the ground at its departure airport after
    /// the plan's takeoff time, by its leg's id: the status sentence says so (which plane design §4). Nil with no
    /// such flight.
    static func stillOnGroundFlight(in legs: [TripLeg], flights: [String: MapFlight], at now: Date) -> String? {
        guard !flights.isEmpty else { return nil }
        return legs.first { leg in
            leg.type == .flight && leg.effectiveStart <= now && now < leg.effectiveEnd
                && (flights[leg.id]?.isAtDeparture(at: now) ?? false)
        }?.id
    }

    /// `legs`, as `replacingTimes` gives them, for the schedule's list, which shows each leg's written times as they
    /// are and adds no delay. A time of a live flight that the real plane has moved is written less the leg's delay,
    /// so the list would show it wrong by that much: here it's the real time. A time the plane hasn't moved stays as
    /// it's written, where the wait beside it still meets it. The wait before a flight that's tagged late ends at
    /// the flight's written start, as the status has it: here it ends where the flight is shown to start, so the
    /// list has no hole before the flight. Every other leg is as it was.
    static func forTheSchedule(_ legs: [TripLeg], with flights: [String: MapFlight]) -> [TripLeg] {
        guard !flights.isEmpty else { return legs }
        var shown = legs
        for (index, leg) in legs.enumerated() {
            guard let flight = flights[leg.id], leg.delay != 0 else { continue }
            // A time `replacingTimes` left alone is the plan's own, to the bit.
            let isStartReal = leg.effectiveStart != flight.plan.departure
            let isEndReal = leg.effectiveEnd != flight.plan.arrival
            guard isStartReal || isEndReal else { continue }
            shown[index] = leg.with(startTime: isStartReal ? leg.effectiveStart : leg.startTime,
                                    endTime: isEndReal ? leg.effectiveEnd : leg.endTime, keepingDelay: false)
            guard isStartReal, leg.delay > 0 else { continue }
            for (place, wait) in legs.enumerated()
            where waitTypes.contains(wait.type) && abs(wait.endTime.timeIntervalSince(leg.startTime)) <= 60 {
                shown[place] = wait.with(startTime: wait.startTime, endTime: leg.effectiveStart)
            }
        }
        return shown
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

    /// What makes two legs one flight: the same number, departure airport and scheduled departure.
    private static func flightKey(of leg: TripLeg) -> String {
        "\(leg.flightNumber ?? "")|\(leg.departureAirport ?? "")|\(leg.startTime.timeIntervalSince1970)"
    }

    /// Of the legs that are each flight, the first by its id in text order: the one Crewlu Cloud answers under.
    private static func firstOfEachFlight(in legs: [TripLeg]) -> [String: TripLeg] {
        var firstOfEachFlight: [String: TripLeg] = [:]
        for leg in legs where leg.type == .flight {
            let flight = flightKey(of: leg)
            if let kept = firstOfEachFlight[flight], kept.id <= leg.id { continue }
            firstOfEachFlight[flight] = leg
        }
        return firstOfEachFlight
    }

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

    /// The leg at other times, with its delay or with none.
    func with(startTime: Date, endTime: Date, keepingDelay: Bool = true) -> TripLeg {
        TripLeg(id: id, tripId: tripId, type: type, startTime: startTime, endTime: endTime, airportCode: airportCode,
                city: city, timezoneIdentifier: timezoneIdentifier, arrivalTimezoneIdentifier: arrivalTimezoneIdentifier,
                flightNumber: flightNumber, departureAirport: departureAirport, arrivalAirport: arrivalAirport,
                departureCity: departureCity, arrivalCity: arrivalCity, tripDayNumber: tripDayNumber,
                tripTotalDays: tripTotalDays, delayMinutes: keepingDelay ? delayMinutes : nil, airlineCode: airlineCode,
                label: label)
    }
}
