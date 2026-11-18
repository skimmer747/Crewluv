//
//  TripMapPreviews.swift
//  CrewLuve
//
//  The trip map card in each state, around the time the canvas opens: Louisville to Cologne to Dubai and home with
//  CrewLu's layovers, an hour's turn in Cologne, a commuter at base, Anchorage to Tokyo across the date line, and the
//  Europe trip's recap. The full-screen map shows with Quick layovers on and off. Three more show a real plane,
//  made up here: in the air and ahead, estimated after an ocean nobody saw it over, and full screen. Each preview
//  builds its own story store.
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

    /// One of CrewLu's ground legs at `code`: a layover, a turn, or a stay at base or home.
    static func ground(_ id: String, _ type: TripLeg.LegType, at code: String, _ city: String,
                       start: Date, hours: Double, zone: String) -> TripLeg {
        TripLeg(id: id, tripId: "P1", type: type, startTime: start, endTime: start.addingTimeInterval(hours * 3600),
                airportCode: code, city: city, timezoneIdentifier: zone, arrivalTimezoneIdentifier: nil,
                flightNumber: nil, departureAirport: nil, arrivalAirport: nil, departureCity: nil, arrivalCity: nil,
                tripDayNumber: nil, tripTotalDays: nil, delayMinutes: nil, airlineCode: nil, label: nil)
    }

    /// A commuter's 90-minute drive from Lexington to base in Louisville.
    static func driveToBase(start: Date) -> TripLeg {
        TripLeg(id: "D1", tripId: "P1", type: .drive, startTime: start, endTime: start.addingTimeInterval(1.5 * 3600),
                airportCode: nil, city: nil, timezoneIdentifier: "America/New_York", arrivalTimezoneIdentifier: "America/New_York",
                flightNumber: nil, departureAirport: "LEX", arrivalAirport: "SDF", departureCity: "Lexington", arrivalCity: "Louisville",
                tripDayNumber: nil, tripTotalDays: nil, delayMinutes: nil, airlineCode: nil, label: nil)
    }

    /// Louisville to Cologne, a day there, Dubai, 20 hours there, and home, from `start`.
    static func europeLegs(from start: Date) -> [TripLeg] {
        [
            flight("UPS207", "SDF", "CGN", "Louisville", "Cologne", start: start, hours: 8, zone: "America/New_York", arrivalZone: "Europe/Berlin"),
            ground("L1", .layover, at: "CGN", "Cologne", start: start.addingTimeInterval(8 * 3600), hours: 24, zone: "Europe/Berlin"),
            flight("UPS208", "CGN", "DXB", "Cologne", "Dubai", start: start.addingTimeInterval(32 * 3600), hours: 6, zone: "Europe/Berlin", arrivalZone: "Asia/Dubai"),
            ground("L2", .layover, at: "DXB", "Dubai", start: start.addingTimeInterval(38 * 3600), hours: 20, zone: "Asia/Dubai"),
            flight("UPS209", "DXB", "SDF", "Dubai", "Louisville", start: start.addingTimeInterval(58 * 3600), hours: 14, zone: "Asia/Dubai", arrivalZone: "America/New_York"),
        ]
    }

    /// The Europe trip, `hoursIn` hours after its first departure.
    static func europe(hoursIn: Double, isNextTrip: Bool = false, isRecap: Bool = false) -> TripMap? {
        let now = Date()
        return TripMap.make(tripLegs: europeLegs(from: now.addingTimeInterval(-hoursIn * 3600)), isNextTrip: isNextTrip,
                            isRecap: isRecap, homeAirportCode: "SDF", legacyDelayMinutes: nil, at: now, coordinate: { coordinate($0) })
    }

    /// Louisville to Cologne and straight back after an hour's turn, half an hour into the turn.
    static var turn: TripMap? {
        let now = Date()
        let start = now.addingTimeInterval(-8.5 * 3600)
        let legs = [
            flight("UPS207", "SDF", "CGN", "Louisville", "Cologne", start: start, hours: 8, zone: "America/New_York", arrivalZone: "Europe/Berlin"),
            ground("T1", .turn, at: "CGN", "Cologne", start: start.addingTimeInterval(8 * 3600), hours: 1, zone: "Europe/Berlin"),
            flight("UPS206", "CGN", "SDF", "Cologne", "Louisville", start: start.addingTimeInterval(9 * 3600), hours: 9, zone: "Europe/Berlin", arrivalZone: "America/New_York"),
        ]
        return TripMap.make(tripLegs: legs, isNextTrip: false, homeAirportCode: "SDF", legacyDelayMinutes: nil, at: now, coordinate: { coordinate($0) })
    }

    /// A commuter who lives in Lexington, at base in Louisville, an hour and a half before the Europe trip.
    static var atBase: TripMap? {
        let now = Date()
        let legs = [driveToBase(start: now.addingTimeInterval(-2 * 3600)),
                    ground("B1", .base, at: "SDF", "Louisville", start: now.addingTimeInterval(-0.5 * 3600), hours: 2, zone: "America/New_York")]
            + europeLegs(from: now.addingTimeInterval(1.5 * 3600))
        return TripMap.make(tripLegs: legs, isNextTrip: false, homeAirportCode: "LEX", legacyDelayMinutes: nil, at: now, coordinate: { coordinate($0) })
    }

    /// A commuter who lives in Lexington, waiting at base in Louisville with the Europe trip a day ahead.
    static var waitingAtBase: TripMap? {
        let now = Date()
        return TripMap.make(tripLegs: europeLegs(from: now.addingTimeInterval(24 * 3600)), isNextTrip: true,
                            homeAirportCode: "LEX", baseAirportCode: "SDF", isWaitingAtBase: true,
                            legacyDelayMinutes: nil, at: now, coordinate: { coordinate($0) })
    }

    static var pacific: TripMap? {
        let start = Date().addingTimeInterval(-3 * 3600)
        let legs = [flight("UPS61", "ANC", "NRT", "Anchorage", "Tokyo", start: start, hours: 8, zone: "America/Anchorage", arrivalZone: "Asia/Tokyo")]
        return TripMap.make(tripLegs: legs, isNextTrip: false, homeAirportCode: "SDF", legacyDelayMinutes: nil, at: Date(), coordinate: { coordinate($0) })
    }

    /// A made-up real plane from `origin` to `destination` by way of `waypoint`, off at `takeoff` and seen every two
    /// minutes until `lastSeen`, except through `unseen`.
    static func liveFlight(legID: String, from origin: CLLocationCoordinate2D, via waypoint: CLLocationCoordinate2D,
                           to destination: CLLocationCoordinate2D, takeoff: Date, lastSeen: Date,
                           unseen: ClosedRange<Date>? = nil) -> LiveFlight {
        let speed = 560 * GreatCircle.metersPerNauticalMile / 3600
        let firstPart = GreatCircle.distance(from: origin, to: waypoint)
        let secondPart = GreatCircle.distance(from: waypoint, to: destination)
        func place(at time: Date) -> CLLocationCoordinate2D {
            let flown = min(time.timeIntervalSince(takeoff) * speed, firstPart + secondPart)
            return flown <= firstPart
                ? GreatCircle.point(from: origin, to: waypoint, fraction: flown / firstPart)
                : GreatCircle.point(from: waypoint, to: destination, fraction: (flown - firstPart) / secondPart)
        }
        let trail = stride(from: takeoff.addingTimeInterval(60), through: lastSeen, by: 120)
            .filter { !(unseen?.contains($0) ?? false) }
            .map { time -> LiveFlight.TrailPoint in
                let here = place(at: time)
                return LiveFlight.TrailPoint(time: time, latitude: here.latitude, longitude: here.longitude, altitudeFeet: 38_000)
            }
        let last = place(at: lastSeen)
        let fix = LiveFlight.Fix(latitude: last.latitude, longitude: last.longitude, altitudeFeet: 38_000, groundSpeedKnots: 560,
                                 trackDegrees: nil, isOnGround: false, registration: "N605UP", typeCode: "B748", seenAt: lastSeen)
        return LiveFlight(legID: legID, callsign: "UPS207", state: .airborne, fix: fix, landedAt: nil, trail: trail)
    }

    /// The Europe trip `hoursIn` hours after its first departure, with a real plane on the first flight: off ten
    /// minutes early, north of the great circle, and last seen `lastSeenMinutesAgo` minutes ago.
    static func europeLive(hoursIn: Double, lastSeenMinutesAgo: Double, hasUnseenOcean: Bool = false) -> TripMap? {
        let now = Date()
        let start = now.addingTimeInterval(-hoursIn * 3600)
        let legs = europeLegs(from: start)
        guard let origin = coordinate("SDF"), let destination = coordinate("CGN") else { return nil }
        let takeoff = start.addingTimeInterval(5 * 60)
        let unseen = hasUnseenOcean ? takeoff.addingTimeInterval(3600)...takeoff.addingTimeInterval(2 * 3600) : nil
        let live = liveFlight(legID: "UPS207", from: origin, via: CLLocationCoordinate2D(latitude: 58, longitude: -45),
                              to: destination, takeoff: takeoff, lastSeen: now.addingTimeInterval(-lastSeenMinutesAgo * 60),
                              unseen: unseen)
        let flights = LiveLegs.flights(for: legs, legacyDelayMinutes: nil, answered: ["UPS207": live], clockOffset: 0,
                                       coordinate: { coordinate($0) })
        return TripMap.make(tripLegs: LiveLegs.replacingTimes(in: legs, with: flights, at: now), isNextTrip: false,
                            homeAirportCode: "SDF", legacyDelayMinutes: nil, flights: flights, at: now,
                            coordinate: { coordinate($0) })
    }

    /// The Europe trip `minutesLate` minutes after its first flight's takeoff time, with its real plane still at the
    /// gate in Louisville (which plane design §4), or back there after an air return when `hasReturned`: out 30 nm and
    /// back, up to 9,000 ft (air return design §3).
    static func europeAtTheGate(minutesLate: Double, hasReturned: Bool = false) -> TripMap? {
        let now = Date()
        let start = now.addingTimeInterval(-minutesLate * 60 - FlightProgress.taxiOutAllowance)
        let legs = europeLegs(from: start)
        guard let origin = coordinate("SDF") else { return nil }
        let fix = LiveFlight.Fix(latitude: origin.latitude, longitude: origin.longitude, altitudeFeet: nil, groundSpeedKnots: 0,
                                 trackDegrees: nil, isOnGround: true, registration: "N605UP", typeCode: "B748",
                                 seenAt: now.addingTimeInterval(-30))
        let outAndBack = [(0.1, 2_000.0), (0.4, 7_000.0), (0.6, 9_000.0), (0.4, 6_000.0), (0.1, 1_500.0)]
        let trail = hasReturned ? outAndBack.enumerated().map { index, step in
            LiveFlight.TrailPoint(time: start.addingTimeInterval(FlightProgress.taxiOutAllowance + Double(index + 1) * 120),
                                  latitude: origin.latitude, longitude: origin.longitude + step.0, altitudeFeet: step.1)
        } : []
        let live = LiveFlight(legID: "UPS207", callsign: "UPS207", state: .ground, fix: fix, landedAt: nil, trail: trail)
        let flights = LiveLegs.flights(for: legs, legacyDelayMinutes: nil, answered: ["UPS207": live], clockOffset: 0,
                                       coordinate: { coordinate($0) })
        return TripMap.make(tripLegs: LiveLegs.replacingTimes(in: legs, with: flights, at: now), isNextTrip: false,
                            homeAirportCode: "SDF", legacyDelayMinutes: nil, flights: flights, at: now,
                            coordinate: { coordinate($0) })
    }

    /// The Europe trip with its first flight's real plane down in Cologne `minutesAgo` minutes ago, and not yet at the
    /// gate, the plan's 7 minutes of taxi in after its touchdown (landed before the gate design §3). It was seen all
    /// the way, at 560 kt.
    static func europeLanded(minutesAgo: Double) -> TripMap? {
        let now = Date()
        guard let origin = coordinate("SDF"), let destination = coordinate("CGN") else { return nil }
        let waypoint = CLLocationCoordinate2D(latitude: 58, longitude: -45)
        let length = GreatCircle.distance(from: origin, to: waypoint) + GreatCircle.distance(from: waypoint, to: destination)
        let landedAt = now.addingTimeInterval(-minutesAgo * 60)
        let takeoff = landedAt.addingTimeInterval(-length / (560 * GreatCircle.metersPerNauticalMile / 3600))
        let legs = europeLegs(from: takeoff.addingTimeInterval(-FlightProgress.taxiOutAllowance))
        let flown = liveFlight(legID: "UPS207", from: origin, via: waypoint, to: destination, takeoff: takeoff,
                               lastSeen: landedAt.addingTimeInterval(-120))
        let fix = LiveFlight.Fix(latitude: destination.latitude, longitude: destination.longitude, altitudeFeet: nil,
                                 groundSpeedKnots: 20, trackDegrees: nil, isOnGround: true, registration: "N605UP",
                                 typeCode: "B748", seenAt: landedAt)
        let live = LiveFlight(legID: "UPS207", callsign: "UPS207", state: .landed, fix: fix, landedAt: landedAt, trail: flown.trail)
        let flights = LiveLegs.flights(for: legs, legacyDelayMinutes: nil, answered: ["UPS207": live], clockOffset: 0,
                                       coordinate: { coordinate($0) })
        return TripMap.make(tripLegs: LiveLegs.replacingTimes(in: legs, with: flights, at: now), isNextTrip: false,
                            homeAirportCode: "SDF", legacyDelayMinutes: nil, flights: flights, at: now,
                            coordinate: { coordinate($0) })
    }

    /// A store with Quick layovers set, so each full-screen preview shows its pace whatever the canvas remembered.
    static func storage(quickLayovers isOn: Bool, followsPlane: Bool = false) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "TripMapPreviews.quickLayovers.\(isOn).follows.\(followsPlane)") ?? .standard
        defaults.set(isOn, forKey: TripMapScreen.quickLayoversKey)
        defaults.set(followsPlane, forKey: TripMapScreen.followsPlaneKey)
        return defaults
    }
}

#Preview("In flight") {
    if let map = TripMapPreviewData.europe(hoursIn: 4) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Layover") {
    if let map = TripMapPreviewData.europe(hoursIn: 12) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Turn") {
    if let map = TripMapPreviewData.turn {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("At base") {
    if let map = TripMapPreviewData.atBase {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Next trip") {
    if let map = TripMapPreviewData.europe(hoursIn: -48, isNextTrip: true) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Next trip, waiting at base") {
    if let map = TripMapPreviewData.waitingAtBase {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Recap") {
    if let map = TripMapPreviewData.europe(hoursIn: 75, isRecap: true) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Across the date line") {
    if let map = TripMapPreviewData.pacific {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Following the plane") {
    if let map = TripMapPreviewData.europeLive(hoursIn: 6, lastSeenMinutesAgo: 0.5) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
            .defaultAppStorage(TripMapPreviewData.storage(quickLayovers: true, followsPlane: true))
    }
}

#Preview("Full screen, following the plane") {
    if let map = TripMapPreviewData.europeLive(hoursIn: 6, lastSeenMinutesAgo: 0.5) {
        TripMapScreen(tripMap: map, storyStore: LegStoryStore(), dayNumber: 1, totalDays: 4)
            .defaultAppStorage(TripMapPreviewData.storage(quickLayovers: true, followsPlane: true))
    }
}

#Preview("Real plane, in the air") {
    if let map = TripMapPreviewData.europeLive(hoursIn: 4, lastSeenMinutesAgo: 0.5) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Real plane, estimated past an unseen ocean") {
    // Last seen long enough ago that the dotted line to the plane reaches out from under the ghost.
    if let map = TripMapPreviewData.europeLive(hoursIn: 4, lastSeenMinutesAgo: 75, hasUnseenOcean: true) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Real plane, still at the gate") {
    if let map = TripMapPreviewData.europeAtTheGate(minutesLate: 25) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Real plane, returned to the gate") {
    if let map = TripMapPreviewData.europeAtTheGate(minutesLate: 40, hasReturned: true) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Full screen, real plane returned to the gate") {
    if let map = TripMapPreviewData.europeAtTheGate(minutesLate: 40, hasReturned: true) {
        TripMapScreen(tripMap: map, storyStore: LegStoryStore(), dayNumber: 1, totalDays: 4)
            .defaultAppStorage(TripMapPreviewData.storage(quickLayovers: true))
    }
}

#Preview("Real plane, landed, not yet at the gate") {
    if let map = TripMapPreviewData.europeLanded(minutesAgo: 2) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Full screen, real plane landed, not yet at the gate") {
    if let map = TripMapPreviewData.europeLanded(minutesAgo: 2) {
        TripMapScreen(tripMap: map, storyStore: LegStoryStore(), dayNumber: 1, totalDays: 4)
            .defaultAppStorage(TripMapPreviewData.storage(quickLayovers: true))
    }
}

#Preview("Full screen, real plane still at the gate") {
    if let map = TripMapPreviewData.europeAtTheGate(minutesLate: 25) {
        TripMapScreen(tripMap: map, storyStore: LegStoryStore(), dayNumber: 1, totalDays: 4)
            .defaultAppStorage(TripMapPreviewData.storage(quickLayovers: true))
    }
}

#Preview("Full screen, real plane") {
    if let map = TripMapPreviewData.europeLive(hoursIn: 4, lastSeenMinutesAgo: 0.5, hasUnseenOcean: true) {
        TripMapScreen(tripMap: map, storyStore: LegStoryStore(), dayNumber: 1, totalDays: 4)
            .defaultAppStorage(TripMapPreviewData.storage(quickLayovers: true))
    }
}

#Preview("Full screen, in flight, Quick layovers on") {
    if let map = TripMapPreviewData.europe(hoursIn: 4) {
        TripMapScreen(tripMap: map, storyStore: LegStoryStore(), dayNumber: 1, totalDays: 4)
            .defaultAppStorage(TripMapPreviewData.storage(quickLayovers: true))
    }
}

#Preview("Full screen, recap, Quick layovers off") {
    if let map = TripMapPreviewData.europe(hoursIn: 75, isRecap: true) {
        TripMapScreen(tripMap: map, storyStore: LegStoryStore(), dayNumber: nil, totalDays: nil)
            .defaultAppStorage(TripMapPreviewData.storage(quickLayovers: false))
    }
}
#endif
