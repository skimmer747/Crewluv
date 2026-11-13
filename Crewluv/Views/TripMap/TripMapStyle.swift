//
//  TripMapStyle.swift
//  CrewLuve
//
//  The map styles the full-screen map's style button cycles through, as on CrewLu's moving map (moving map spec §6).
//  Kept flat: no 3D globe, so the night drawn here is the only one.
//

import MapKit
import SwiftUI

enum TripMapStyle: CaseIterable {
    case hybrid, standard, imagery

    var next: TripMapStyle {
        switch self {
        case .hybrid: .standard
        case .standard: .imagery
        case .imagery: .hybrid
        }
    }

    /// The style's name for VoiceOver.
    var name: String {
        switch self {
        case .hybrid: "Hybrid"
        case .standard: "Map"
        case .imagery: "Satellite"
        }
    }

    var mapStyle: MapStyle {
        switch self {
        case .hybrid: .hybrid(elevation: .flat, pointsOfInterest: .excludingAll)
        case .standard: .standard(elevation: .flat, pointsOfInterest: .excludingAll)
        case .imagery: .imagery(elevation: .flat)
        }
    }

    /// The standard map is light only in light mode; hybrid and satellite are always dark.
    func palette(for colorScheme: ColorScheme) -> TripMapPalette {
        self == .standard && colorScheme == .light ? .onLightMap : .onDarkMap
    }
}
