//
//  TripMapTopBar.swift
//  CrewLuve
//
//  Close, what's happening, recenter and map style, along the top of the full-screen map (moving map spec §6).
//

import SwiftUI

struct TripMapTopBar: View {
    let pill: String
    let style: TripMapStyle
    let isShowingRecenter: Bool
    let onClose: () -> Void
    let onRecenter: () -> Void
    let onNextStyle: () -> Void

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 12) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Close map")

                Spacer(minLength: 0)
                Text(pill)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
                Spacer(minLength: 0)

                if isShowingRecenter {
                    Button(action: onRecenter) {
                        Image(systemName: "location.fill")
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Recenter map")
                }
                Button(action: onNextStyle) {
                    Image(systemName: "map")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Map style")
                .accessibilityValue(style.name)
            }
            .buttonBorderShape(.circle)
            .controlSize(.large)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
