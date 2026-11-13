//
//  RouteFallbackView.swift
//  CrewLuve
//
//  "SDF → CGN" in place of the map when an airport isn't in Crewluve's list (moving map spec §12).
//

import SwiftUI

struct RouteFallbackView: View {
    let departure: String?
    let arrival: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "airplane")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("\(departure ?? "???") → \(arrival ?? "???")")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Flying from \(departure ?? "an unknown airport") to \(arrival ?? "an unknown airport")")
    }
}
