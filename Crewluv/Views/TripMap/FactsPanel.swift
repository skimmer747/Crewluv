//
//  FactsPanel.swift
//  CrewLuve
//
//  The facts on iPad and in landscape (Stage 2 spec §6.2): a panel down the leading edge. Its rows scroll between the
//  headline and the timeline, and the chevron folds it down to just those two. At the largest text sizes all of it
//  scrolls together.
//

import SwiftUI

struct FactsPanel: View {
    let facts: TripFacts
    /// The timeline bar's blocks, at the clock's pace.
    let timeline: TripTimeline
    @Binding var clock: TripReplayClock
    @Binding var isQuickLayovers: Bool
    /// The trip time on screen.
    let time: Date
    /// The real time of this tick.
    let now: Date
    @Binding var isExpanded: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        content
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    @ViewBuilder
    private var content: some View {
        if dynamicTypeSize.isAccessibilitySize {
            // The headline and the timeline alone can be taller than a landscape screen, so all of it scrolls.
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if isExpanded { factsBody }
                    timelineControl
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                header
                if isExpanded {
                    ScrollView { factsBody }
                        .frame(maxHeight: .infinity)
                }
                timelineControl
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(facts.sheetHeadline(at: time))
                .font(.headline)
                .accessibilityLabel(ClockLabel.spoken(facts.sheetHeadline(at: time)))
                .accessibilityAddTraits(.isHeader)
                .clockLabelHelp(for: facts.sheetHeadline(at: time))
            Spacer(minLength: 0)
            Button(action: toggle) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel(isExpanded ? "Hide facts" : "Show facts")
        }
    }

    private var factsBody: some View {
        FactsBody(rows: facts.rows(at: time, now: now), tripSoFar: facts.tripSoFar(at: time),
                  showsLiveCredit: facts.showsLiveData)
    }

    private var timelineControl: some View {
        TripTimelineControl(clock: $clock, isQuickLayovers: $isQuickLayovers, timeline: timeline,
                            activity: facts.tripMap.activity(at: time), flight: facts.flightNow(at: time),
                            time: time, now: now)
    }

    private func toggle() {
        if reduceMotion {
            isExpanded.toggle()
        } else {
            withAnimation(.snappy) { isExpanded.toggle() }
        }
    }
}
