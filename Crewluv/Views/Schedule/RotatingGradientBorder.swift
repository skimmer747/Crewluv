//
//  RotatingGradientBorder.swift
//  CrewLuve
//
//  Animated rotating gradient border used to highlight the "up next" timeline event
//

import SwiftUI

struct RotatingGradientBorder: View {
    var cornerRadius: CGFloat = 14
    var lineWidth: CGFloat = 2
    var isAnimating: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion || !isAnimating {
            staticBorder
        } else {
            animatedBorder
        }
    }

    // MARK: - Static Fallback

    private var staticBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(Color.cyan.opacity(0.6), lineWidth: lineWidth)
    }

    // MARK: - Animated Border

    private var animatedBorder: some View {
        TimelineView(.animation(paused: !isAnimating)) { context in
            let angle = Angle.degrees(
                context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4 * 360
            )

            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    AngularGradient(
                        colors: [.cyan, .blue, .cyan.opacity(0.3), .blue.opacity(0.3), .cyan],
                        center: .center,
                        angle: angle
                    ),
                    lineWidth: lineWidth
                )
        }
    }
}
