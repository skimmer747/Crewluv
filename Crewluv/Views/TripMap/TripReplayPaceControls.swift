//
//  TripReplayPaceControls.swift
//  CrewLuve
//
//  Quick layovers and the replay's speeds, under the timeline (activity markers design §3.1). Equatable on what they
//  show, so a replay redrawing the timeline up to 60 times a second leaves them alone: redrawn under a tap, the
//  segmented speeds read back the speed they showed, and the tap was lost (Todd: "the speeds won't change when the map
//  is in motion").
//

import SwiftUI

struct TripReplayPaceControls: View, Equatable {
    let speed: TripReplayClock.Speed
    let isQuickLayovers: Bool
    let onSpeed: (TripReplayClock.Speed) -> Void
    let onQuickLayovers: (Bool) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The same speed and the same Quick layovers show the same controls, whatever the closures.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.speed == rhs.speed && lhs.isQuickLayovers == rhs.isQuickLayovers
    }

    /// Quick layovers beside the speeds, or above them when the two don't fit on one line.
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                quickLayoversToggle
                    .fixedSize()
                Spacer(minLength: 0)
                speedPicker
            }
            VStack(alignment: .leading, spacing: 8) {
                quickLayoversToggle
                speedPicker
            }
        }
    }

    private var quickLayoversToggle: some View {
        Toggle("Quick layovers", isOn: Binding(get: { isQuickLayovers }, set: onQuickLayovers))
            .font(.subheadline)
            .accessibilityHint("Plays the time on the ground faster")
    }

    /// A segmented control, or a menu at the largest text sizes where four segments won't fit.
    @ViewBuilder
    private var speedPicker: some View {
        let picker = Picker("Replay speed", selection: Binding(get: { speed }, set: onSpeed)) {
            ForEach(TripReplayClock.Speed.allCases) { speed in
                Text("\(speed.rawValue)×").tag(speed)
            }
        }
        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.menu)
        } else {
            picker.pickerStyle(.segmented).fixedSize()
        }
    }
}
