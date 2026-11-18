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
    /// Where the flight's real plane is on the ground, now: the line under the bar names it in place of flying.
    let onGround: FlightOnGround?
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
                                spokenValue: TripMapWording.timelineSpokenValue(time, activity: activity, onGround: onGround),
                                onScrub: scrub(to:))
                if !clock.isLive && !dynamicTypeSize.isAccessibilitySize {
                    liveButton
                }
            }
            // At the largest text sizes Live goes under the bar, which would otherwise be squeezed to nothing.
            if !clock.isLive && dynamicTypeSize.isAccessibilitySize {
                liveButton
            }
            Text(TripMapWording.timelineLine(time, activity: activity, onGround: onGround))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                // The bar's VoiceOver value says the same.
                .accessibilityHidden(true)
            // Apart from the timeline's every tick, so a tap on a speed isn't lost while a replay plays.
            TripReplayPaceControls(speed: clock.speed, isQuickLayovers: isQuickLayovers,
                                   onSpeed: { clock.setSpeed($0, at: .now) },
                                   onQuickLayovers: { isQuickLayovers = $0 })
                .equatable()
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
}
