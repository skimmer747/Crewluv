//
//  TripMapPalette.swift
//  CrewLuve
//
//  The trip map's line colours and strokes, and its airport codes' colours (moving map spec §7.1). Satellite and
//  hybrid maps are dark in both light and dark mode, so their lines and codes are light; the standard map gets the
//  system blue, near-black flown legs and drives, and dark codes in light mode.
//

import SwiftUI

nonisolated struct TripMapPalette: Equatable {
    let upcoming: Color
    let flying: Color
    let flown: Color
    let drive: Color
    /// The real path flown (Stage 3 spec §6.2): where the plane was seen, and where it wasn't.
    let seen: Color
    let unseen: Color
    /// An airport's code, and the halo that keeps it readable over the map.
    let label: Color
    let labelHalo: Color

    /// One night layer. `NightShade` stacks seven of these.
    static let night = Color(red: 0.02, green: 0.05, blue: 0.16).opacity(NightShade.layerAlpha)

    static let onDarkMap = TripMapPalette(
        upcoming: Color(red: 0.62, green: 0.76, blue: 1.0),
        flying: Color(red: 0.62, green: 0.76, blue: 1.0),
        flown: Color(white: 0.82),
        drive: .white,
        seen: .white,
        unseen: .white,
        label: .white,
        labelHalo: .black.opacity(0.75)
    )

    /// Flown legs and drives on the standard map in light mode, as the website draws them. The system gray all but
    /// vanished under the night shading, about 1.1:1 against the map; this is about 3.5:1 there and 8–12:1 by day.
    private static let nearBlack = Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255)

    static let onLightMap = TripMapPalette(
        upcoming: .blue.opacity(0.6),
        flying: .blue,
        flown: nearBlack,
        drive: nearBlack,
        seen: .blue,
        unseen: .blue,
        label: Color(white: 0.12),
        labelHalo: .white
    )

    func color(for style: RouteSegment.Style) -> Color {
        switch style {
        case .upcoming: upcoming
        case .flying: flying
        case .flown: flown
        case .drive: drive
        case .seen: seen
        case .unseen: unseen
        }
    }

    func stroke(for style: RouteSegment.Style) -> StrokeStyle {
        switch style {
        case .upcoming: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 6])
        case .flying: StrokeStyle(lineWidth: 3, lineCap: .round)
        case .flown: StrokeStyle(lineWidth: 2.5, lineCap: .round)
        case .drive: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.5, 6])
        case .seen: StrokeStyle(lineWidth: 3, lineCap: .round)
        case .unseen: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.5, 6])
        }
    }
}
