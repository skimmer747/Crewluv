//
//  TripMapPanel.swift
//  CrewLuve
//
//  The full-screen map's panel (moving map spec §6): where they are or when they land, and the timeline. Stage 2
//  adds a row for each kind of fact.
//

import SwiftUI

struct TripMapPanel: View {
    let headline: String
    @Binding var clock: TripReplayClock
    let time: Date
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !headline.isEmpty {
                Text(headline)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
            }
            TripTimelineControl(clock: $clock, time: time, now: now)
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}
