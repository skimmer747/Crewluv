//
//  TripMap.swift
//  CrewLuve
//
//  The trip the map shows (moving map spec §5.1): its drawable legs, CrewLu's ground legs, whether the pilot is flying,
//  on the ground mid-trip, or home with this trip ahead, and where the pilot is at any moment. What they're doing there
//  is in TripMap+Activity.swift.
//

import CoreLocation

nonisolated struct TripMap {

    nonisolated enum Mode: Equatable {
        /// A flight is between its gates.
        case inFlight(legID: String)
        /// On a trip, and not in the air.
        case onTrip
        /// At home or base, with this trip still ahead.
        case nextTrip
        /// Home, within a day of this trip ending: its recap (Stage 2 spec §8).
        case recap
    }

    let mode: Mode
    /// Never empty, earliest first.
    let legs: [MapLeg]
    /// CrewLu's layovers, turns, and stays at base and home, earliest first. They name the waits between legs
    /// (activity markers design §2.2), and aren't drawn.
    let groundStops: [GroundStop]
    let home: AirportMark?
    /// The pilot's base, as the trip's legs name it, or nil when none does (base waits design §2, §3).
    let base: AirportMark?
    /// With this trip ahead, the pilot waits at base rather than at home, as the status says (base waits design §3).
    let isWaitingAtBase: Bool
    /// From the first departure to the last arrival: the full-screen map's timeline.
    let span: DateInterval
    /// CrewLu's count of the trip's days, when the legs carry it.
    let tripDays: Int?

    var isInFlight: Bool {
        if case .inFlight = mode { return true }
        return false
    }

    /// The flight in the air when the map was made.
    var currentLeg: MapLeg? {
        guard case .inFlight(let legID) = mode else { return nil }
        return legs.first { $0.id == legID }
    }

    func legInMotion(at date: Date) -> MapLeg? {
        legs.first { $0.isMoving(at: date) }
    }

    func nextFlight(after date: Date) -> MapLeg? {
        legs.first { $0.kind == .flight && $0.start > date }
    }

    /// The trip's days: CrewLu's count when the legs carry it, else the calendar days it spans.
    func dayCount(in calendar: Calendar) -> Int {
        if let tripDays { return max(1, tripDays) }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: span.start), to: calendar.startOfDay(for: span.end)).day ?? 0
        return days + 1
    }

    /// Where the pilot is at `date` when nothing is moving, or nil while a leg is. Before a trip still ahead
    /// starts, that's home, or base while the pilot waits there.
    func pilotLocation(at date: Date) -> AirportMark? {
        guard legInMotion(at: date) == nil else { return nil }
        if mode == .recap, date >= span.end { return home ?? legs.last?.destination }
        if mode == .nextTrip, date < span.start { return (isWaitingAtBase ? base : home) ?? legs.first?.origin }
        return legs.last(where: { $0.end <= date })?.destination ?? legs.first?.origin
    }

    /// The places the camera must show: one leg's arc, or every leg's arcs and home.
    func framingCoordinates(focusingOn leg: MapLeg?) -> [CLLocationCoordinate2D] {
        let shown = leg.map { [$0] } ?? legs
        var coordinates = shown.flatMap {
            GreatCircle.points(from: $0.origin.coordinate, to: $0.destination.coordinate, count: 33)
        }
        if leg == nil, let home { coordinates.append(home.coordinate) }
        return coordinates
    }

    // MARK: - Making one

    /// The map of `tripLegs`, one trip's legs as the status screen picked them, or nil when none can be drawn.
    /// - `isNextTrip`: the legs are a trip still ahead, shown from home.
    /// - `isRecap`: the legs are a trip just finished, shown as its recap.
    /// - `baseAirportCode`: the pilot's base, which names a wait there that CrewLu doesn't (base waits design §2).
    /// - `isWaitingAtBase`: with a trip ahead, the status says the pilot is at base, not home (base waits design §3).
    /// - `legacyDelayMinutes`: the summary-wide delay from a CrewLu that doesn't tag legs. As `TripStateResolver`
    ///   does, it moves only the flight it covers, and only when no leg carries its own.
    /// - `coordinate`: where an airport is, by code.
    static func make(
        tripLegs: [TripLeg],
        isNextTrip: Bool,
        isRecap: Bool = false,
        homeAirportCode: String?,
        baseAirportCode: String? = nil,
        isWaitingAtBase: Bool = false,
        legacyDelayMinutes: Int?,
        at now: Date,
        coordinate: (String) -> CLLocationCoordinate2D?
    ) -> TripMap? {
        let sorted = tripLegs.sorted { $0.startTime < $1.startTime }
        let legacyDelay = legacyDelayedFlight(in: sorted, delayMinutes: legacyDelayMinutes, at: now)
        let legs = sorted.compactMap { leg in
            mapLeg(for: leg,
                   arrivalZoneFallback: sorted.first(where: { $0.startTime >= leg.endTime && $0.type != .flight })?.timezoneIdentifier,
                   extraDelayMinutes: leg.id == legacyDelay?.legID ? legacyDelay?.minutes : nil,
                   coordinate: coordinate)
        }
        guard let first = legs.first else { return nil }
        let groundStops = sorted.compactMap(GroundStop.init(leg:))
        let lastArrival = legs.map(\.end).max() ?? first.end
        let home = homeAirportCode.flatMap { code in
            coordinate(code).map { AirportMark(code: code, city: nil, coordinate: $0, timeZone: nil) }
        }
        let mode: Mode
        if isRecap {
            mode = .recap
        } else if isNextTrip {
            mode = .nextTrip
        } else if let flying = legs.first(where: { $0.kind == .flight && $0.isMoving(at: now) }) {
            mode = .inFlight(legID: flying.id)
        } else {
            mode = .onTrip
        }
        // Base as the legs name it, with its city and time zone: a wait or a marker there is at one of their airports.
        let base = baseAirportCode.flatMap { code in
            legs.flatMap { [$0.origin, $0.destination] }.first { $0.code == code }
        }
        let firstDeparture = legs.map(\.start).min() ?? first.start
        return TripMap(mode: mode, legs: legs, groundStops: groundStops, home: home, base: base,
                       isWaitingAtBase: mode == .nextTrip && isWaitingAtBase,
                       span: DateInterval(start: firstDeparture, end: max(lastArrival, firstDeparture)),
                       tripDays: tripLegs.compactMap(\.tripTotalDays).max())
    }

    private static func mapLeg(
        for leg: TripLeg,
        arrivalZoneFallback: String?,
        extraDelayMinutes: Int?,
        coordinate: (String) -> CLLocationCoordinate2D?
    ) -> MapLeg? {
        let kind: MapLeg.Kind
        switch leg.type {
        case .flight: kind = .flight
        case .drive: kind = .drive
        default: return nil
        }
        guard let originCode = leg.departureAirport, let destinationCode = leg.arrivalAirport,
              let originCoordinate = coordinate(originCode), let destinationCoordinate = coordinate(destinationCode) else { return nil }
        let delay = TimeInterval(((leg.delayMinutes ?? 0) + (extraDelayMinutes ?? 0)) * 60)
        let originZone = leg.timezoneIdentifier.flatMap(TimeZone.init(identifier:))
        let destinationZone = (leg.arrivalTimezoneIdentifier ?? arrivalZoneFallback).flatMap(TimeZone.init(identifier:))
        return MapLeg(
            id: leg.id,
            kind: kind,
            origin: AirportMark(code: originCode, city: leg.departureCity, coordinate: originCoordinate, timeZone: originZone),
            destination: AirportMark(code: destinationCode, city: leg.arrivalCity, coordinate: destinationCoordinate, timeZone: destinationZone),
            start: leg.startTime.addingTimeInterval(delay),
            end: leg.endTime.addingTimeInterval(delay),
            flightNumber: leg.flightNumber
        )
    }

    /// The flight the summary-wide delay applies to, as `TripStateResolver.resolve` picks it.
    private static func legacyDelayedFlight(in sorted: [TripLeg], delayMinutes: Int?, at now: Date) -> (legID: String, minutes: Int)? {
        guard let minutes = delayMinutes, minutes != 0,
              !sorted.contains(where: { ($0.delayMinutes ?? 0) != 0 }) else { return nil }
        let shift = TimeInterval(minutes * 60)
        let flight = sorted.first {
            $0.type == .flight && $0.startTime.addingTimeInterval(shift) <= now && now < $0.endTime.addingTimeInterval(shift)
        }
        return flight.map { ($0.id, minutes) }
    }
}
