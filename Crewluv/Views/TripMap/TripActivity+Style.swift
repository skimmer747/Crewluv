//
//  TripActivity+Style.swift
//  CrewLuve
//
//  How the trip map draws each kind of activity (activity markers design §2.1, §4.1): the SF Symbol on the pilot's
//  marker, and the color of the marker and of the timeline's blocks. They're system colors, so they adapt to Dark Mode,
//  and no wait's color is a route line's.
//

import SwiftUI

nonisolated extension TripActivity.Kind {

    /// The symbol on the pilot's marker. The plane and the car have markers of their own, and these match them.
    var symbolName: String {
        switch self {
        case .flying: "airplane"
        case .driving: "car.fill"
        case .layover: "bed.double.fill"
        case .turn: "hourglass"
        case .base: "briefcase.fill"
        case .home: "house.fill"
        }
    }

    /// The pilot's marker's circle, and the timeline block's fill.
    var color: Color {
        switch self {
        case .flying: .blue
        case .driving: .gray
        case .layover: .indigo
        case .turn: .orange
        case .base: .teal
        case .home: .green
        }
    }
}
