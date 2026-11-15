//
//  LiveFlight.swift
//  CrewLuve
//
//  One flight's live data, as Crewlu Cloud keeps it from adsb.lol (Stage 3 spec §10.5, §10.6): its state, the last
//  place it was seen, and the path it flew.
//

import CoreLocation

nonisolated struct LiveFlight: Equatable, Sendable {

    nonisolated enum State: String, Sendable {
        /// Watched, and never seen.
        case waiting
        /// On the ground: at the departure airport, or somewhere else after a diversion.
        case ground
        case airborne
        /// Seen on the ground at the arrival airport, after being in the air.
        case landed
    }

    /// The last place the aircraft was seen.
    nonisolated struct Fix: Equatable, Sendable {
        let latitude: Double
        let longitude: Double
        /// Nil on the ground.
        let altitudeFeet: Double?
        let groundSpeedKnots: Double?
        /// 0 to 360, or nil when the aircraft sent none.
        let trackDegrees: Double?
        let isOnGround: Bool
        let registration: String?
        /// The aircraft's ICAO type code, like "B763".
        let typeCode: String?
        /// By Crewlu Cloud's clock.
        let seenAt: Date

        var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    }

    /// One point of the path flown: about one every 2 minutes while the flight is seen in the air.
    nonisolated struct TrailPoint: Equatable, Sendable {
        let time: Date
        let latitude: Double
        let longitude: Double
        let altitudeFeet: Double?

        var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    }

    /// The id of the flight's leg in the pilot's summary.
    let legID: String
    let callsign: String
    let state: State
    /// Nil before the flight is first seen.
    let fix: Fix?
    /// When it was first seen on the ground at the arrival airport.
    let landedAt: Date?
    /// Every point of the path flown, in the order Crewlu Cloud sent them, which isn't always the order of their
    /// times: `FlightPath` sorts them.
    let trail: [TrailPoint]
}

nonisolated extension LiveFlight {
    /// One of partner_live's flights, with the whole of its `trail`: an answer may bring only the newest points.
    init(_ answered: PartnerLiveAnswer.Flight, trail: [TrailPoint]) {
        self.init(legID: answered.legID, callsign: answered.callsign, state: answered.state, fix: answered.fix,
                  landedAt: answered.landedAt, trail: trail)
    }
}
