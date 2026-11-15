//
//  PartnerLiveAnswer.swift
//  CrewLuve
//
//  partner_live's answer, as Crewlu Cloud writes it (CrewLu's supabase/partner-api.md, "The live plane")
//

import Foundation

/// partner_live's answer: Crewlu Cloud's clock, the cursor to send back, and each of the pilot's flights with live
/// data. Every time in it is milliseconds since 1970, unlike the summary's seconds.
nonisolated struct PartnerLiveAnswer: Equatable, Sendable {

    nonisolated struct Flight: Equatable, Sendable {
        /// The id of the flight's leg in the pilot's summary.
        let legID: String
        let callsign: String
        let state: LiveFlight.State
        let fix: LiveFlight.Fix?
        let landedAt: Date?
        /// The points after the cursor the call sent, or every point when it sent none.
        let trail: [LiveFlight.TrailPoint]
        /// How many points the flight has in all.
        let trailCount: Int
    }

    /// Crewlu Cloud's clock when it answered.
    let now: Date
    /// Sent back with the next call, so only the points after these come.
    let cursor: Int
    let flights: [Flight]
}

// MARK: - Reading It

nonisolated extension PartnerLiveAnswer: Decodable {
    private enum CodingKeys: String, CodingKey {
        case now, cursor, flights
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        now = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .now) / 1000)
        cursor = try container.decode(Int.self, forKey: .cursor)
        flights = try container.decode([Flight].self, forKey: .flights)
    }
}

nonisolated extension PartnerLiveAnswer.Flight: Decodable {
    private enum CodingKeys: String, CodingKey {
        case legID = "leg_id"
        case callsign, state, fix
        case landedAt = "landed_at"
        case trail
        case trailCount = "trail_count"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        legID = try container.decode(String.self, forKey: .legID)
        callsign = try container.decode(String.self, forKey: .callsign)
        // A state this Crewluve doesn't know is one it can't draw: the schedule's plane shows.
        state = LiveFlight.State(rawValue: try container.decode(String.self, forKey: .state)) ?? .waiting
        fix = try container.decodeIfPresent(LiveFlight.Fix.self, forKey: .fix)
        landedAt = try container.decodeIfPresent(Double.self, forKey: .landedAt).map { Date(timeIntervalSince1970: $0 / 1000) }
        trail = try container.decode([LiveFlight.TrailPoint].self, forKey: .trail)
        trailCount = try container.decode(Int.self, forKey: .trailCount)
    }
}

nonisolated extension LiveFlight.Fix: Decodable {
    private enum CodingKeys: String, CodingKey {
        case latitude = "lat"
        case longitude = "lon"
        case altitudeFeet = "altitude_ft"
        case groundSpeedKnots = "ground_speed_kt"
        case trackDegrees = "track_deg"
        case isOnGround = "on_ground"
        case registration
        case typeCode = "type_code"
        case seenAt = "seen_at"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        altitudeFeet = try container.decodeIfPresent(Double.self, forKey: .altitudeFeet)
        groundSpeedKnots = try container.decodeIfPresent(Double.self, forKey: .groundSpeedKnots)
        trackDegrees = try container.decodeIfPresent(Double.self, forKey: .trackDegrees)
        isOnGround = try container.decode(Bool.self, forKey: .isOnGround)
        registration = try container.decodeIfPresent(String.self, forKey: .registration)
        typeCode = try container.decodeIfPresent(String.self, forKey: .typeCode)
        seenAt = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .seenAt) / 1000)
    }
}

/// A trail point comes as `[time, latitude, longitude, altitude in feet]`, the altitude null when adsb.lol sent none.
nonisolated extension LiveFlight.TrailPoint: Decodable {
    init(from decoder: any Decoder) throws {
        var values = try decoder.unkeyedContainer()
        time = Date(timeIntervalSince1970: try values.decode(Double.self) / 1000)
        latitude = try values.decode(Double.self)
        longitude = try values.decode(Double.self)
        altitudeFeet = try values.decodeIfPresent(Double.self)
    }
}
