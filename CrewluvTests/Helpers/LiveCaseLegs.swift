//
//  LiveCaseLegs.swift
//  CrewluvTests
//
//  The shared cases' flights (Fixtures/TripMap/live-cases.json) as the trip map and the status screen's model take
//  them: the map's flight, a leg of the map, and a leg of the pilot's summary.
//

import CoreLocation
import Foundation
@testable import Crewluv

extension TripMapFixtures.LiveCases {

    struct MissingFlight: Error {
        let name: String
    }

    func flight(named name: String) throws -> Flight {
        guard let flight = flights.first(where: { $0.name == name }) else { throw MissingFlight(name: name) }
        return flight
    }

    func moment(_ time: String, of flight: Flight) throws -> Flight.Moment {
        let at = try Date("2026-11-\(time)Z", strategy: .iso8601)
        guard let moment = flight.moments.first(where: { $0.at == at }) else { throw MissingFlight(name: "\(flight.name) at \(time)") }
        return moment
    }

    /// A flight case's live data, as `LiveFlightSource` keeps it. Nil where the door answers none for the leg.
    func live(_ flight: Flight) -> LiveFlight? {
        flight.flight.map { LiveFlight($0, trail: $0.trail) }
    }

    /// A flight case as the map's flight: its plan, its path and its record, made together.
    func mapFlight(_ flight: Flight, clockOffset: TimeInterval = 0) throws -> MapFlight {
        let made = MapFlight(departure: flight.departure, arrival: flight.arrival,
                             from: try coordinate(of: flight.from), to: try coordinate(of: flight.to),
                             live: live(flight), clockOffset: clockOffset)
        guard let made else { throw TripMapFixtures.MissingPlan(name: flight.name) }
        return made
    }

    /// A flight case as a leg of the map, between the gates at the times the case expects at `moment`: the real
    /// plane's, as the status screen's model hands them on.
    func mapLeg(_ flight: Flight, at moment: Flight.Moment, id: String = "f1") throws -> MapLeg {
        MapLeg(id: id, kind: .flight,
               origin: AirportMark(code: flight.from, city: nil, coordinate: try coordinate(of: flight.from), timeZone: nil),
               destination: AirportMark(code: flight.to, city: nil, coordinate: try coordinate(of: flight.to), timeZone: nil),
               start: moment.start, end: moment.end, flightNumber: "UPS207", flight: try mapFlight(flight))
    }

    /// A flight case as a leg of the pilot's summary. The case's gate times are the schedule's moved by any
    /// reported delay, so the leg's own are `delayMinutes` earlier.
    func tripLeg(_ flight: Flight, id: String = "f1", delayMinutes: Int? = nil) -> TripLeg {
        let delay = TimeInterval((delayMinutes ?? 0) * 60)
        return TripLeg(id: id, tripId: "T1", type: .flight, startTime: flight.departure.addingTimeInterval(-delay),
                       endTime: flight.arrival.addingTimeInterval(-delay), airportCode: nil, city: nil,
                       timezoneIdentifier: nil, arrivalTimezoneIdentifier: nil, flightNumber: "UPS207",
                       departureAirport: flight.from, arrivalAirport: flight.to, departureCity: nil, arrivalCity: nil,
                       tripDayNumber: nil, tripTotalDays: nil, delayMinutes: delayMinutes, airlineCode: nil, label: nil)
    }

    /// One of CrewLu's waits on the ground, from `start` to `end`.
    func wait(_ id: String, _ type: TripLeg.LegType, at code: String, from start: Date, to end: Date) -> TripLeg {
        TripLeg(id: id, tripId: "T1", type: type, startTime: start, endTime: end, airportCode: code, city: nil,
                timezoneIdentifier: nil, arrivalTimezoneIdentifier: nil, flightNumber: nil, departureAirport: nil,
                arrivalAirport: nil, departureCity: nil, arrivalCity: nil, tripDayNumber: nil, tripTotalDays: nil,
                delayMinutes: nil, airlineCode: nil, label: nil)
    }

    /// Where an airport of the cases is, by code, as `TripMap.make` and `LiveLegs.flights` ask.
    func coordinateOrNil(_ code: String) -> CLLocationCoordinate2D? {
        try? coordinate(of: code)
    }
}
