//
//  NightBand.swift
//  CrewLuve
//
//  NightShade's shapes with stable identities, so the map's `ForEach` updates them in place (moving map spec §7.1).
//

import CoreLocation

nonisolated struct NightBand: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]

    /// Every shape of every night layer at `date`, shallowest layer first.
    static func bands(at date: Date) -> [NightBand] {
        NightShade.layers(at: date).enumerated().flatMap { layer, shapes in
            shapes.enumerated().map { index, shape in
                NightBand(id: "night-\(layer)-\(index)", coordinates: shape)
            }
        }
    }
}
