//
//  TripMapScreen.swift
//  CrewLuve
//
//  The full-screen trip map (moving map spec §6): pan and zoom, change the style, and replay the trip. Opens on the
//  leg in the air, or on the whole trip. On iPhone the panel sits at the bottom; on iPad and in landscape it floats
//  at the side.
//

import MapKit
import SwiftUI

struct TripMapScreen: View {
    let tripMap: TripMap
    let dayNumber: Int?
    let totalDays: Int?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock: TripReplayClock
    @State private var style: TripMapStyle = .hybrid
    @State private var position: MapCameraPosition

    init(tripMap: TripMap, dayNumber: Int?, totalDays: Int?) {
        self.tripMap = tripMap
        self.dayNumber = dayNumber
        self.totalDays = totalDays
        _clock = State(initialValue: TripReplayClock(span: tripMap.span))
        _position = State(initialValue: tripMap.camera(focusingOn: tripMap.currentLeg))
    }

    var body: some View {
        // Every second live; about 30 times a second while a replay runs.
        TimelineView(.periodic(from: .now, by: clock.isPlaying ? 1.0 / 30 : 1)) { context in
            let time = clock.time(at: context.date)
            screen(time: time, now: context.date)
                .onChange(of: tripMap.legInMotion(at: time)?.id) { _, legID in
                    refit(legID: legID)
                }
        }
    }

    @ViewBuilder
    private func screen(time: Date, now: Date) -> some View {
        let base = ZStack(alignment: .top) {
            TripMapView(tripMap: tripMap, date: time, style: style, nightStep: nightStep,
                        position: $position, isInteractive: true)
                .ignoresSafeArea()
            topBar(time: time)
        }
        let panel = TripMapPanel(headline: TripMapWording.panelHeadline(for: tripMap, at: time),
                                 clock: $clock, time: time, now: now)
        if usesSidePanel {
            base.overlay(alignment: .bottomLeading) {
                panel.frame(maxWidth: 380).padding()
            }
        } else {
            base.safeAreaInset(edge: .bottom) {
                panel.padding(.horizontal).padding(.bottom, 8)
            }
        }
    }

    private func topBar(time: Date) -> some View {
        TripMapTopBar(
            pill: TripMapWording.topPill(for: tripMap, at: time, dayNumber: dayNumber, totalDays: totalDays),
            style: style,
            isShowingRecenter: position.positionedByUser,
            onClose: { dismiss() },
            onRecenter: { refit(legID: tripMap.legInMotion(at: time)?.id, force: true) },
            onNextStyle: { style = style.next }
        )
    }

    /// iPad, and iPhone in landscape.
    private var usesSidePanel: Bool {
        horizontalSizeClass == .regular || verticalSizeClass == .compact
    }

    /// Night moves about a degree every four minutes. Live it's redrawn each minute; in replay about ten times a
    /// second of real time, whatever the speed (moving map spec §10).
    private var nightStep: TimeInterval {
        clock.isPlaying ? TripReplayClock.baseRate / 10 * Double(clock.speed.rawValue) : 60
    }

    /// Frames the leg in motion, or the whole trip. Leaves a camera the family moved alone, unless they asked.
    private func refit(legID: String?, force: Bool = false) {
        guard force || !position.positionedByUser else { return }
        let leg = legID.flatMap { id in tripMap.legs.first { $0.id == id } }
        let camera = tripMap.camera(focusingOn: leg)
        if reduceMotion {
            position = camera
        } else {
            withAnimation(.smooth) { position = camera }
        }
    }
}
