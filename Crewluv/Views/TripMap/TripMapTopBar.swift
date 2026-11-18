//
//  TripMapTopBar.swift
//  CrewLuve
//
//  Close, what's happening, recenter, follow the plane and map style, along the top of the full-screen map (moving map
//  spec §6, follow the plane design §2).
//

import SwiftUI

struct TripMapTopBar: View {
    let pill: String
    let style: TripMapStyle
    let isShowingRecenter: Bool
    let isFollowingPlane: Bool
    let onClose: () -> Void
    let onRecenter: () -> Void
    let onToggleFollow: () -> Void
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
                followButton
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

    /// Follow the plane: tinted in the accent colour while it's on, plain glass like the others when it's off (follow
    /// the plane design §2).
    @ViewBuilder
    private var followButton: some View {
        let button = Button(action: onToggleFollow) {
            Image(systemName: "airplane.circle")
                .symbolVariant(isFollowingPlane ? .fill : .none)
        }
        .accessibilityLabel("Follow the plane")
        .accessibilityValue(isFollowingPlane ? "On" : "Off")
        .accessibilityHint("Keeps the map on the plane and where it's headed.")
        .accessibilityAddTraits(.isToggle)
        if isFollowingPlane {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.glass)
        }
    }
}
