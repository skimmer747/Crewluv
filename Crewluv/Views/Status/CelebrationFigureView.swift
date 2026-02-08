//
//  CelebrationFigureView.swift
//  CrewLuv
//
//  Animated celebrating figure for the "Home In" card when < 24 hours away
//

import SwiftUI

struct CelebrationFigureView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isAnimating = false
    @State private var isVisible = false

    struct AnimationValues {
        var scale: Double = 1.0
        var verticalOffset: Double = 0.0
        var rotation: Double = 0.0
    }

    var body: some View {
        Image(systemName: "figure.arms.open")
            .font(.system(size: 36, weight: .bold))
            .foregroundStyle(.green.gradient)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            .keyframeAnimator(initialValue: AnimationValues(), trigger: isAnimating) { content, value in
                content
                    .scaleEffect(value.scale)
                    .offset(y: value.verticalOffset)
                    .rotationEffect(.degrees(value.rotation))
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.3, duration: 0.3)
                    SpringKeyframe(0.9, duration: 0.25)
                    SpringKeyframe(1.2, duration: 0.3)
                    SpringKeyframe(1.0, duration: 0.3)
                }
                KeyframeTrack(\.verticalOffset) {
                    SpringKeyframe(-12, duration: 0.25)
                    SpringKeyframe(0, duration: 0.2)
                    SpringKeyframe(-10, duration: 0.25)
                    SpringKeyframe(0, duration: 0.2)
                    SpringKeyframe(-6, duration: 0.2)
                    SpringKeyframe(0, duration: 0.2)
                }
                KeyframeTrack(\.rotation) {
                    SpringKeyframe(8, duration: 0.25)
                    SpringKeyframe(-8, duration: 0.3)
                    SpringKeyframe(6, duration: 0.25)
                    SpringKeyframe(-6, duration: 0.25)
                    SpringKeyframe(0, duration: 0.25)
                }
            }
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                startAnimation()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    startAnimation()
                }
            }
    }

    private func startAnimation() {
        isVisible = true
        isAnimating.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                isVisible = false
            }
        }
    }
}
