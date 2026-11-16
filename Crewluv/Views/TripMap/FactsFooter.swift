//
//  FactsFooter.swift
//  CrewLuve
//
//  Under the facts (Stage 2 spec §5.2, §7.2; Stage 3 spec §8): they're estimated from the schedule, the credit to
//  adsb.lol whenever a flight with live data shows, and Apple's Weather mark and legal link whenever a WeatherKit
//  forecast shows.
//

import SwiftUI

struct FactsFooter: View {
    let showsWeather: Bool
    /// A flight with live data shows: its position is adsb.lol's.
    let showsLiveCredit: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Estimated from the schedule")
                .font(.caption)
                .foregroundStyle(.secondary)
            if showsLiveCredit {
                Text(FactsWording.liveCredit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(FactsWording.spokenLiveCredit)
            }
            if showsWeather {
                WeatherAttributionView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
