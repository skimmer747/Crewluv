//
//  TripTimelineControl.swift
//  CrewLuve
//
//  Play, drag through the trip, go back to Live, pick 1x to 10x, and hurry through waits on the ground (moving map
//  spec §6; activity markers design §3.1, §4). The bar measures replay time and is colored by what the pilot is doing;
//  the line under it says when and what.
//

import SwiftUI

struct TripTimelineControl: View {
    @Binding var clock: TripReplayClock
    @Binding var isQuickLayovers: Bool
    /// The bar's blocks, at the clock's pace.
    let timeline: TripTimeline
    /// What the pilot is doing at `time`.
    let activity: TripActivity?
    /// The trip time on screen.
    let time: Date
    /// The real time of this tick.
    let now: Date

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                playButton
                TripTimelineBar(timeline: timeline, progress: clock.progress(at: time),
                                spokenValue: TripMapWording.timelineSpokenValue(time, activity: activity),
                                onScrub: scrub(to:))
                if !clock.isLive && !dynamicTypeSize.isAccessibilitySize {
                    liveButton
                }
            }
            // At the largest text sizes Live goes under the bar, which would otherwise be squeezed to nothing.
            if !clock.isLive && dynamicTypeSize.isAccessibilitySize {
                liveButton
            }
            Text(TripMapWording.timelineLine(time, activity: activity))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                // The bar's VoiceOver value says the same.
                .accessibilityHidden(true)
            paceControls
        }
    }

    /// Quick layovers beside the speeds, or above them when the two don't fit on one line.
    private var paceControls: some View {
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
        Toggle("Quick layovers", isOn: $isQuickLayovers)
            .font(.subheadline)
            .accessibilityHint("Plays the time on the ground faster")
    }

    /// A segmented control, or a menu at the largest text sizes where four segments won't fit.
    @ViewBuilder
    private var speedPicker: some View {
        let picker = Picker("Replay speed", selection: speed) {
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

    private var liveButton: some View {
        Button("Live") { clock.goLive() }
            .buttonStyle(.bordered)
            .accessibilityHint("Shows where things are now")
    }

    private var isShowingPause: Bool {
        clock.isPlaying && !clock.hasFinished(at: now)
    }

    private var playButton: some View {
        Button {
            if isShowingPause { clock.pause(at: .now) } else { clock.play(at: .now) }
        } label: {
            Image(systemName: isShowingPause ? "pause.fill" : "play.fill")
                .imageScale(.large)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel(isShowingPause ? "Pause replay" : "Replay the trip")
    }

    /// Moves the replay to `progress` along the bar, paused there.
    private func scrub(to progress: Double) {
        clock.scrub(to: clock.tripTime(atProgress: progress))
    }

    private var speed: Binding<TripReplayClock.Speed> {
        Binding(get: { clock.speed }, set: { clock.setSpeed($0, at: .now) })
    }
}
