//
//  TripMapPalette.swift
//  CrewLuve
//
//  The trip map's line colours and strokes, and its airport codes' colours (moving map spec §7.1). Satellite and
//  hybrid maps are dark in both light and dark mode, so their lines and codes are light; the standard map gets the
//  system blue and dark codes in light mode.
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

    static let onLightMap = TripMapPalette(
        upcoming: .blue.opacity(0.6),
        flying: .blue,
        flown: .gray,
        drive: .gray,
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
