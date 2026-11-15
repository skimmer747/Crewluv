//
//  TripMapStyle.swift
//  CrewLuve
//
//  The map styles the full-screen map's style button cycles through, as on CrewLu's moving map (moving map spec §6).
//  Kept flat: Apple lights its 3D globe for the real clock, never the replay's, so the night drawn here is the only one.
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

    /// MapKit's configuration for the style, flat and without points of interest.
    var configuration: MKMapConfiguration {
        switch self {
        case .hybrid:
            let configuration = MKHybridMapConfiguration(elevationStyle: .flat)
            configuration.pointOfInterestFilter = .excludingAll
            return configuration
        case .standard:
            let configuration = MKStandardMapConfiguration(elevationStyle: .flat)
            configuration.pointOfInterestFilter = .excludingAll
            return configuration
        case .imagery:
            return MKImageryMapConfiguration(elevationStyle: .flat)
        }
    }

    /// The standard map is light only in light mode; hybrid and satellite are always dark.
    func palette(for colorScheme: ColorScheme) -> TripMapPalette {
        self == .standard && colorScheme == .light ? .onLightMap : .onDarkMap
    }
}
