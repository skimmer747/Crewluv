//
//  WeatherAttributionView.swift
//  CrewLuve
//
//  Displays the required Apple Weather attribution mark with a link to legal info
//

import SwiftUI

struct WeatherAttributionView: View {
    var body: some View {
        Link(destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!) {
            Text("\(Image(systemName: "apple.logo")) Weather")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Apple Weather")
        .accessibilityHint("Opens weather legal information")
    }
}
