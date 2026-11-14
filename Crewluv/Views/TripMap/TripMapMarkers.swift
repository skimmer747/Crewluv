//
//  TripMapMarkers.swift
//  CrewLuve
//
//  The trip map's small fixed-size markers (moving map spec §5.1, §7.1). MapKit shows them through
//  `TripMapAnnotationView`. VoiceOver reads the card's sentence instead of these, and on the full-screen map each
//  airport's code.
//

import SwiftUI

enum TripMapMarkers {

    /// A white dot on each airport.
    struct Airport: View {
        static let dotDiameter: CGFloat = 7

        var body: some View {
            Circle()
                .fill(.white)
                .frame(width: Self.dotDiameter, height: Self.dotDiameter)
                .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 0.5))
                .accessibilityHidden(true)
        }
    }

    /// An airport's dot with its code under it. SwiftUI's map used to write the code itself, as each annotation's
    /// title.
    struct AirportLabel: View {
        let code: String
        let palette: TripMapPalette

        var body: some View {
            VStack(spacing: 2) {
                Airport()
                Text(code)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.label)
                    .shadow(color: palette.labelHalo, radius: 1)
                    .shadow(color: palette.labelHalo, radius: 1)
            }
            .fixedSize()
            // Grows with the text size, up to where a code would start to cover the route.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .accessibilityHidden(true)
        }
    }

    /// Where the pilot is.
    struct Heart: View {
        var body: some View {
            Image(systemName: "heart.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.pink))
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                .accessibilityHidden(true)
        }
    }

    /// A drive, parked halfway along it, or where the pilot is while driving.
    struct Car: View {
        var body: some View {
            Image(systemName: "car.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.black.opacity(0.45)))
                .overlay(Circle().stroke(.white, lineWidth: 1))
                .accessibilityHidden(true)
        }
    }
}
