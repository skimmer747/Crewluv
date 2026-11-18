//
//  PlaneMarker.swift
//  CrewLuve
//
//  The trip map's planes (moving map spec §7.2, Stage 3 spec §5.4), each turning the short way round as its angle
//  changes: the schedule's plane alone, a white outline; the real plane, filled blue, and faded while it's an
//  estimate; and the ghost beside it, a dashed outline where an on-schedule plane would be.
//

import SwiftUI

struct PlaneMarker: View {

    enum Look: Equatable {
        /// The schedule's plane, alone.
        case schedule
        /// The real plane. `isEstimated` once it hasn't been seen for a while.
        case real(isEstimated: Bool)
        /// Where an on-schedule plane would be, beside the real one.
        case ghost
    }

    /// `PlaneHeading`'s angle: 0 points east, positive turns clockwise.
    let angle: Double
    var look: Look = .schedule

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownAngle: Double?

    var body: some View {
        Image(systemName: "airplane")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white.opacity(look == .ghost ? 0.6 : 1))
            .rotationEffect(.radians(shownAngle ?? angle))
            .frame(width: 26, height: 26)
            .background(Circle().fill(fill))
            .overlay(Circle().stroke(.white, style: outline))
            .opacity(look == .real(isEstimated: true) ? 0.6 : 1)
            .animation(reduceMotion ? nil : .snappy, value: shownAngle)
            .onChange(of: angle, initial: true) { _, newAngle in
                shownAngle = PlaneHeading.continuing(shownAngle ?? newAngle, toward: newAngle)
            }
            .accessibilityHidden(true)
    }

    private var fill: Color {
        switch look {
        case .schedule: .black.opacity(0.35)
        case .real: .blue
        case .ghost: .black.opacity(0.15)
        }
    }

    private var outline: StrokeStyle {
        look == .ghost ? StrokeStyle(lineWidth: 1.5, dash: [3, 3]) : StrokeStyle(lineWidth: 1.5)
    }
}
