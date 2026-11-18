//
//  LiveFlightDoor.swift
//  CrewLuve
//
//  The partner door's call for the live plane
//

import Foundation

/// partner_live: the pilot's flights with live data, for the partner whose device holds `key` (CrewLu's
/// `supabase/partner-api.md`, "The live plane"). It's apart from `PartnerDoor`, whose file the alert pushes' helper
/// builds: the helper has no use for the live plane, and so needs none of its types.
protocol LiveFlightDoor {
    /// `cursor` is the last answer's, so only the trail points since then come, or nil for every point.
    func live(key: String, after cursor: Int?) async throws(PartnerDoorError) -> PartnerLiveAnswer
}

extension LivePartnerDoor: LiveFlightDoor {
    func live(key: String, after cursor: Int?) async throws(PartnerDoorError) -> PartnerLiveAnswer {
        try await call("partner_live", LiveParameters(key: key, after: cursor))
    }
}

private struct LiveParameters: Encodable {
    let key: String
    /// Left out when nil, so the door sends every point.
    let after: Int?

    enum CodingKeys: String, CodingKey {
        case key = "p_key"
        case after = "p_after"
    }
}
