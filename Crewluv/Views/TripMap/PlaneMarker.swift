//
//  PlaneMarker.swift
//  CrewLuve
//
//  The schedule's plane (moving map spec §7.2): a white outline circle, turning the short way round between legs.
//  Stage 3 adds the filled live plane beside it.
//

import SwiftUI

struct PlaneMarker: View {
    /// `PlaneHeading`'s angle: 0 points east, positive turns clockwise.
    let angle: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownAngle: Double?

    var body: some View {
        Image(systemName: "airplane")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .rotationEffect(.radians(shownAngle ?? angle))
            .frame(width: 26, height: 26)
            .background(Circle().fill(.black.opacity(0.35)))
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
            .animation(reduceMotion ? nil : .snappy, value: shownAngle)
            .onChange(of: angle, initial: true) { _, newAngle in
                shownAngle = PlaneHeading.continuing(shownAngle ?? newAngle, toward: newAngle)
            }
            .accessibilityHidden(true)
    }
}
