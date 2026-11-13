//
//  TripMapTestLegs.swift
//  CrewluvTests
//
//  Airports and legs for the trip map's tests: Louisville to Cologne to Dubai and home, plus a drive.
//

import CoreLocation
@testable import Crewluv

enum TripMapTestLegs {

    static let airports: [String: CLLocationCoordinate2D] = [
        "SDF": CLLocationCoordinate2D(latitude: 38.1744, longitude: -85.7360),
        "LEX": CLLocationCoordinate2D(latitude: 38.0365, longitude: -84.6059),
        "CGN": CLLocationCoordinate2D(latitude: 50.8659, longitude: 7.1427),
        "DXB": CLLocationCoordinate2D(latitude: 25.2532, longitude: 55.3657),
        "ANC": CLLocationCoordinate2D(latitude: 61.1743, longitude: -149.9963),
        "NRT": CLLocationCoordinate2D(latitude: 35.7720, longitude: 140.3929),
    ]

    static func coordinate(_ code: String) -> CLLocationCoordinate2D? { airports[code] }

    /// 2026-11-13 12:00 UTC, a Friday.
    static let tripStart = Date(timeIntervalSince1970: 1_794_571_200)

    static func leg(
        _ id: String,
        _ type: TripLeg.LegType = .flight,
        from departure: String? = nil,
        to arrival: String? = nil,
        start: Date,
        hours: Double,
        flightNumber: String? = nil,
        delayMinutes: Int? = nil,
        departureCity: String? = nil,
        arrivalCity: String? = nil,
        timezone: String? = nil,
        arrivalTimezone: String? = nil,
        tripId: String? = "T1"
    ) -> TripLeg {
        TripLeg(
            id: id,
            tripId: tripId,
            type: type,
            startTime: start,
            endTime: start.addingTimeInterval(hours * 3600),
            airportCode: nil,
            city: nil,
            timezoneIdentifier: timezone,
            arrivalTimezoneIdentifier: arrivalTimezone,
            flightNumber: flightNumber,
            departureAirport: departure,
            arrivalAirport: arrival,
            departureCity: departureCity,
            arrivalCity: arrivalCity,
            tripDayNumber: nil,
            tripTotalDays: nil,
            delayMinutes: delayMinutes,
            airlineCode: nil,
            label: nil
        )
    }

    /// SDF → CGN (8 h), a day in Cologne, CGN → DXB (6 h), 20 h in Dubai, DXB → SDF (14 h), from `start`.
    static func europeTrip(startingAt start: Date = tripStart, firstDelayMinutes: Int? = nil) -> [TripLeg] {
        func at(_ hours: Double) -> Date { start.addingTimeInterval(hours * 3600) }
        return [
            leg("f1", from: "SDF", to: "CGN", start: at(0), hours: 8, flightNumber: "UPS207", delayMinutes: firstDelayMinutes,
                departureCity: "Louisville", arrivalCity: "Cologne", timezone: "America/New_York", arrivalTimezone: "Europe/Berlin"),
            leg("l1", .layover, start: at(8), hours: 24, timezone: "Europe/Berlin"),
            leg("f2", from: "CGN", to: "DXB", start: at(32), hours: 6, flightNumber: "UPS208",
                departureCity: "Cologne", arrivalCity: "Dubai", timezone: "Europe/Berlin", arrivalTimezone: "Asia/Dubai"),
            leg("l2", .layover, start: at(38), hours: 20, timezone: "Asia/Dubai"),
            leg("f3", from: "DXB", to: "SDF", start: at(58), hours: 14, flightNumber: "UPS209",
                departureCity: "Dubai", arrivalCity: "Louisville", timezone: "Asia/Dubai", arrivalTimezone: "America/New_York"),
        ]
    }

    static func map(_ legs: [TripLeg], isNextTrip: Bool = false, legacyDelayMinutes: Int? = nil, at now: Date) -> TripMap? {
        TripMap.make(tripLegs: legs, isNextTrip: isNextTrip, homeAirportCode: "SDF",
                     legacyDelayMinutes: legacyDelayMinutes, at: now, coordinate: coordinate)
    }
}
