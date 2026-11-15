//
//  FactsFooter.swift
//  CrewLuve
//
//  Under the facts (Stage 2 spec §5.2, §7.2): they're estimated from the schedule, and Apple's Weather mark and legal
//  link whenever a WeatherKit forecast shows.
//

import SwiftUI

struct FactsFooter: View {
    let showsWeather: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Estimated from the schedule")
                .font(.caption)
                .foregroundStyle(.secondary)
            if showsWeather {
                WeatherAttributionView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
