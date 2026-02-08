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
    @State private var fadeOutTask: Task<Void, Never>?
    @State private var animationStart: Date?

    struct AnimationValues {
        var scale: Double = 1.0
        var verticalOffset: Double = 0.0
        var rotation: Double = 0.0
    }

    private struct HeartConfig: Identifiable {
        let id: Int
        let x: CGFloat
        let delay: Double
        let size: CGFloat
        let drift: CGFloat
    }

    private let hearts: [HeartConfig] = [
        HeartConfig(id: 0, x: -6,  delay: 0.05, size: 10, drift: -4),
        HeartConfig(id: 1, x: 8,   delay: 0.25, size: 8,  drift: 5),
        HeartConfig(id: 2, x: -2,  delay: 0.50, size: 12, drift: -2),
        HeartConfig(id: 3, x: 12,  delay: 0.75, size: 9,  drift: 6),
        HeartConfig(id: 4, x: -10, delay: 1.00, size: 7,  drift: -6),
        HeartConfig(id: 5, x: 4,   delay: 1.25, size: 11, drift: 3),
    ]

    var body: some View {
        TimelineView(.animation(paused: !isVisible)) { timeline in
            let elapsed: Double = {
                guard let start = animationStart else { return 0 }
                return timeline.date.timeIntervalSince(start)
            }()
            let armRaise = CGFloat(cos(elapsed * .pi * 3)) * 0.5 + 0.5

            ZStack {
                Canvas { context, size in
                    drawFigure(in: context, size: size, armRaise: armRaise)
                }
                .foregroundStyle(.green.gradient)
                .frame(width: 36, height: 28)

                ForEach(hearts) { heart in
                    let t = elapsed - heart.delay
                    if t > 0 && t < 1.0 {
                        let progress = t / 1.0
                        Image(systemName: "heart.fill")
                            .font(.system(size: heart.size))
                            .foregroundStyle(.red)
                            .offset(
                                x: heart.x + heart.drift * CGFloat(progress),
                                y: -CGFloat(progress) * 35 - 12
                            )
                            .opacity(1.0 - progress)
                            .scaleEffect(1.0 - progress * 0.4)
                    }
                }
            }
        }
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

    private func drawFigure(in context: GraphicsContext, size: CGSize, armRaise: CGFloat) {
        let cx = size.width / 2
        let headRadius = size.width * 0.15
        let headCenterY = headRadius + 1
        let shoulderY = headCenterY + headRadius * 1.4
        let lineWidth = size.width * 0.09
        let shading = GraphicsContext.Shading.foreground
        let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)

        // Head
        let headRect = CGRect(
            x: cx - headRadius, y: headCenterY - headRadius,
            width: headRadius * 2, height: headRadius * 2
        )
        context.fill(Circle().path(in: headRect), with: shading)

        // Torso (short and wide)
        let torsoStroke = StrokeStyle(lineWidth: lineWidth * 1.8, lineCap: .round)
        var torso = Path()
        torso.move(to: CGPoint(x: cx, y: shoulderY))
        torso.addLine(to: CGPoint(x: cx, y: size.height))
        context.stroke(torso, with: shading, style: torsoStroke)

        // Right arm (shoulder -> elbow -> hand)
        let rShoulder = CGPoint(x: cx + 1, y: shoulderY)
        let rElbow = CGPoint(
            x: lerp(size.width * 0.80, size.width * 0.74, t: armRaise),
            y: lerp(shoulderY * 0.75, shoulderY * 0.45, t: armRaise)
        )
        let rHand = CGPoint(
            x: lerp(size.width * 0.74, size.width * 0.62, t: armRaise),
            y: lerp(size.height * 0.10, max(0, size.height * -0.01), t: armRaise)
        )
        var rightArm = Path()
        rightArm.move(to: rShoulder)
        rightArm.addLine(to: rElbow)
        rightArm.addLine(to: rHand)
        context.stroke(rightArm, with: shading, style: stroke)

        // Left arm (mirrored)
        let lShoulder = CGPoint(x: cx - 1, y: shoulderY)
        let lElbow = CGPoint(x: size.width - rElbow.x, y: rElbow.y)
        let lHand = CGPoint(x: size.width - rHand.x, y: rHand.y)
        var leftArm = Path()
        leftArm.move(to: lShoulder)
        leftArm.addLine(to: lElbow)
        leftArm.addLine(to: lHand)
        context.stroke(leftArm, with: shading, style: stroke)
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private func startAnimation() {
        fadeOutTask?.cancel()
        fadeOutTask = nil
        animationStart = Date()
        isVisible = true
        isAnimating.toggle()
        fadeOutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                isVisible = false
            }
            fadeOutTask = nil
        }
    }
}
