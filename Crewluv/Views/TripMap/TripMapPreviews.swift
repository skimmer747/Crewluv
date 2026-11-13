//
//  TripMapPreviews.swift
//  CrewLuve
//
//  The trip map card in each state, around the time the canvas opens: Louisville to Cologne to Dubai and home,
//  and Anchorage to Tokyo across the date line.
//

#if DEBUG
import CoreLocation
import SwiftUI

private enum TripMapPreviewData {

    static func coordinate(_ code: String) -> CLLocationCoordinate2D? {
        AirportDataProvider.shared.airportInfo(forIataCode: code).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    static func flight(_ flightNumber: String, _ from: String, _ to: String, _ fromCity: String, _ toCity: String,
                       start: Date, hours: Double, zone: String, arrivalZone: String) -> TripLeg {
        TripLeg(id: flightNumber, tripId: "P1", type: .flight, startTime: start, endTime: start.addingTimeInterval(hours * 3600),
                airportCode: nil, city: nil, timezoneIdentifier: zone, arrivalTimezoneIdentifier: arrivalZone,
                flightNumber: flightNumber, departureAirport: from, arrivalAirport: to,
                departureCity: fromCity, arrivalCity: toCity, tripDayNumber: nil, tripTotalDays: nil,
                delayMinutes: nil, airlineCode: nil, label: nil)
    }

    /// The Europe trip, `hoursIn` hours after its first departure.
    static func europe(hoursIn: Double, isNextTrip: Bool = false) -> TripMap? {
        let now = Date()
        let start = now.addingTimeInterval(-hoursIn * 3600)
        let legs = [
            flight("UPS207", "SDF", "CGN", "Louisville", "Cologne", start: start, hours: 8, zone: "America/New_York", arrivalZone: "Europe/Berlin"),
            flight("UPS208", "CGN", "DXB", "Cologne", "Dubai", start: start.addingTimeInterval(32 * 3600), hours: 6, zone: "Europe/Berlin", arrivalZone: "Asia/Dubai"),
            flight("UPS209", "DXB", "SDF", "Dubai", "Louisville", start: start.addingTimeInterval(58 * 3600), hours: 14, zone: "Asia/Dubai", arrivalZone: "America/New_York"),
        ]
        return TripMap.make(tripLegs: legs, isNextTrip: isNextTrip, homeAirportCode: "SDF", legacyDelayMinutes: nil, at: now, coordinate: { coordinate($0) })
    }

    static var pacific: TripMap? {
        let start = Date().addingTimeInterval(-3 * 3600)
        let legs = [flight("UPS61", "ANC", "NRT", "Anchorage", "Tokyo", start: start, hours: 8, zone: "America/Anchorage", arrivalZone: "Asia/Tokyo")]
        return TripMap.make(tripLegs: legs, isNextTrip: false, homeAirportCode: "SDF", legacyDelayMinutes: nil, at: Date(), coordinate: { coordinate($0) })
    }
}

#Preview("In flight") {
    if let map = TripMapPreviewData.europe(hoursIn: 4) {
        TripMapCard(tripMap: map, status: .demo).padding()
    }
}

#Preview("Layover") {
    if let map = TripMapPreviewData.europe(hoursIn: 12) {
        TripMapCard(tripMap: map, status: .demo).padding()
    }
}

#Preview("Next trip") {
    if let map = TripMapPreviewData.europe(hoursIn: -48, isNextTrip: true) {
        TripMapCard(tripMap: map, status: .demo).padding()
    }
}

#Preview("Across the date line") {
    if let map = TripMapPreviewData.pacific {
        TripMapCard(tripMap: map, status: .demo).padding()
    }
}

#Preview("Full screen, in flight") {
    if let map = TripMapPreviewData.europe(hoursIn: 4) {
        TripMapScreen(tripMap: map, dayNumber: 1, totalDays: 4)
    }
}
#endif
