//
//  TripActivity.swift
//  CrewLuve
//
//  What the pilot is doing at a moment of the trip, and where (activity markers design §2, §4.2): flying, driving, on
//  a layover, at a turn, at base or at home. The pilot's marker and the timeline's blocks draw the kind
//  (TripActivity+Style.swift), and the line under the timeline says it.
//

import Foundation

nonisolated struct TripActivity {

    /// The raw values are the shared cases' names (CrewluvTests/Fixtures/TripMap/activity-cases.json).
    nonisolated enum Kind: String, CaseIterable {
        case flying, driving, layover, turn, base, home

        /// Flying and driving show as the plane and the car. The rest are waits on the ground, with the pilot's marker.
        var isMoving: Bool {
            switch self {
            case .flying, .driving: true
            case .layover, .turn, .base, .home: false
            }
        }
    }

    let kind: Kind
    /// The flight's or the drive's destination, or where the pilot waits.
    let place: AirportMark

    /// The words under the timeline (design §4.2): "Flying to San Francisco", "Layover in Denver", "Home". A place is
    /// its city, else its code.
    var words: String {
        switch kind {
        case .flying: "Flying to \(place.name)"
        case .driving: "Driving to \(place.name)"
        case .layover: "Layover in \(place.name)"
        case .turn: "Turn in \(place.name)"
        case .base: "At base in \(place.name)"
        case .home: "Home"
        }
    }
}
