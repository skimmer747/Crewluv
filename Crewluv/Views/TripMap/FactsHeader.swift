//
//  FactsHeader.swift
//  CrewLuve
//
//  The top of the iPhone sheet, all its small stop shows (Stage 2 spec §6.1): the headline and the timeline.
//

import SwiftUI

struct FactsHeader: View {
    let headline: String
    /// The timeline bar's blocks, at the clock's pace.
    let timeline: TripTimeline
    /// What the pilot is doing at `time`.
    let activity: TripActivity?
    /// What the line under the bar names of the flight now, in place of flying: where its real plane is on the ground, or by the schedule alone.
    let flight: FlightNow?
    @Binding var clock: TripReplayClock
    @Binding var isQuickLayovers: Bool
    /// The trip time on screen.
    let time: Date
    /// The real time of this tick.
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(headline)
                .font(.headline)
                .accessibilityLabel(ClockLabel.spoken(headline))
                .accessibilityAddTraits(.isHeader)
                .clockLabelHelp(for: headline)
            TripTimelineControl(clock: $clock, isQuickLayovers: $isQuickLayovers, timeline: timeline,
                                activity: activity, flight: flight, time: time, now: now)
        }
    }
}
