//
//  FactsHeader.swift
//  CrewLuve
//
//  The top of the iPhone sheet, all its small stop shows (Stage 2 spec §6.1): the headline and the timeline.
//

import SwiftUI

struct FactsHeader: View {
    let headline: String
    @Binding var clock: TripReplayClock
    /// The trip time on screen.
    let time: Date
    /// The real time of this tick.
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(headline)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            TripTimelineControl(clock: $clock, time: time, now: now)
        }
    }
}
