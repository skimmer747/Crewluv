//
//  TripTimelineControl.swift
//  CrewLuve
//
//  Play, drag through the trip, go back to Live, and pick 1x to 10x (moving map spec §6).
//

import SwiftUI

struct TripTimelineControl: View {
    @Binding var clock: TripReplayClock
    /// The trip time on screen.
    let time: Date
    /// The real time of this tick.
    let now: Date

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                playButton
                Slider(value: sliderValue, in: range)
                    .accessibilityLabel("Trip time")
                    .accessibilityValue(TripMapWording.timelineTime(time))
                if !clock.isLive {
                    Button("Live") { clock.goLive() }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Shows where things are now")
                }
            }
            HStack {
                Text(TripMapWording.timelineTime(time))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Spacer()
                speedPicker
            }
        }
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

    private var range: ClosedRange<Double> {
        let lower = clock.span.start.timeIntervalSince1970
        return lower...max(clock.span.end.timeIntervalSince1970, lower + 1)
    }

    private var sliderValue: Binding<Double> {
        Binding(
            get: { min(max(time.timeIntervalSince1970, range.lowerBound), range.upperBound) },
            set: { clock.scrub(to: Date(timeIntervalSince1970: $0)) }
        )
    }

    private var speed: Binding<TripReplayClock.Speed> {
        Binding(get: { clock.speed }, set: { clock.setSpeed($0, at: .now) })
    }
}
