//
//  TripMap.swift
//  CrewLuve
//
//  The trip the map shows (moving map spec §5.1): its drawable legs, whether the pilot is flying, on the ground
//  mid-trip, or home with this trip ahead, and where the pilot is at any moment.
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
    }

    let mode: Mode
    /// Never empty, earliest first.
    let legs: [MapLeg]
    let home: AirportMark?
    /// From the first departure to the last arrival: the full-screen map's timeline.
    let span: DateInterval

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

    /// Where the pilot is at `date` when nothing is moving, or nil while a leg is. Before a trip still ahead
    /// starts, that's home.
    func pilotLocation(at date: Date) -> AirportMark? {
        guard legInMotion(at: date) == nil else { return nil }
        if mode == .nextTrip, date < span.start { return home ?? legs.first?.origin }
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
    /// - `legacyDelayMinutes`: the summary-wide delay from a CrewLu that doesn't tag legs. As `TripStateResolver`
    ///   does, it moves only the flight it covers, and only when no leg carries its own.
    /// - `coordinate`: where an airport is, by code.
    static func make(
        tripLegs: [TripLeg],
        isNextTrip: Bool,
        homeAirportCode: String?,
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
        let lastArrival = legs.map(\.end).max() ?? first.end
        let home = homeAirportCode.flatMap { code in
            coordinate(code).map { AirportMark(code: code, city: nil, coordinate: $0, timeZone: nil) }
        }
        let mode: Mode
        if isNextTrip {
            mode = .nextTrip
        } else if let flying = legs.first(where: { $0.kind == .flight && $0.isMoving(at: now) }) {
            mode = .inFlight(legID: flying.id)
        } else {
            mode = .onTrip
        }
        let firstDeparture = legs.map(\.start).min() ?? first.start
        return TripMap(mode: mode, legs: legs, home: home,
                       span: DateInterval(start: firstDeparture, end: max(lastArrival, firstDeparture)))
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
