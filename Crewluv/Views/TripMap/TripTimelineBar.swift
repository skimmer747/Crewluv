//
//  TripTimelineBar.swift
//  CrewLuve
//
//  The timeline's bar (activity markers design §4.1, §4.3): the blocks, played and ahead, with a thumb where the replay
//  is. It's drawn by the app rather than `Slider`, so it can be colored by part. A drag moves through the trip in the
//  bar's measure, and VoiceOver reads and adjusts it as a slider. Its height is the same at every text size.
//

import SwiftUI

struct TripTimelineBar: View {
    let timeline: TripTimeline
    /// Where the replay is, 0...1.
    let progress: Double
    /// VoiceOver's value: "Saturday 1:40 PM, layover in Denver".
    let spokenValue: String
    /// Moves the replay to a point along the bar, 0...1.
    let onScrub: (Double) -> Void

    private static let barHeight: CGFloat = 24
    private static let thumbDiameter: CGFloat = 28
    /// The least touch target.
    private static let touchHeight: CGFloat = 44

    var body: some View {
        GeometryReader { proxy in
            let track = TripTimelineTrack(width: proxy.size.width, inset: Self.thumbDiameter / 2)
            ZStack(alignment: .leading) {
                TripTimelineBlocks(blocks: timeline.blocks, progress: progress, inset: track.inset)
                    .frame(height: Self.barHeight)
                    .clipShape(.capsule)
                thumb
                    .offset(x: track.x(at: progress) - track.inset)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).onChanged { onScrub(track.progress(atX: $0.location.x)) })
        }
        .frame(height: Self.touchHeight)
        .accessibilityRepresentation {
            Slider(value: Binding(get: { progress }, set: onScrub), in: 0...1)
                .accessibilityLabel("Trip time")
                .accessibilityValue(spokenValue)
        }
    }

    private var thumb: some View {
        Circle()
            .fill(.white)
            .overlay(Circle().stroke(.black.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .frame(width: Self.thumbDiameter, height: Self.thumbDiameter)
    }
}
