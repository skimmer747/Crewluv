//
//  TripMapScreen.swift
//  CrewLuve
//
//  The full-screen trip map (moving map spec §6, Stage 2 spec §6): pan and zoom, change the style, replay the trip and
//  read its facts. On iPhone the facts are a sheet you drag up; on iPad and in landscape, a panel down the leading
//  edge. A recap opens paused at its trip's start. Weather on landing is fetched while the screen is open.
//

import MapKit
import SwiftUI

struct TripMapScreen: View {
    let tripMap: TripMap
    let storyStore: LegStoryStore
    let dayNumber: Int?
    let totalDays: Int?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock: TripReplayClock
    @State private var style: TripMapStyle = .hybrid
    @State private var position: MapCameraPosition
    @State private var weather = LandingWeather()
    @State private var sheetStop: FactsSheet.Stop = .small
    /// How far up the screen the sheet reaches.
    @State private var sheetHeight: CGFloat = 0
    /// The map's frame, the whole screen, in window coordinates.
    @State private var screenFrame: CGRect = .zero
    /// The side panel's trailing edge, in window coordinates.
    @State private var panelTrailingEdge: CGFloat = 0
    @State private var topBarHeight: CGFloat = 0
    @State private var isPanelExpanded = true
    @State private var isClosing = false

    private static let panelWidth: CGFloat = 380

    init(tripMap: TripMap, storyStore: LegStoryStore, dayNumber: Int?, totalDays: Int?) {
        self.tripMap = tripMap
        self.storyStore = storyStore
        self.dayNumber = dayNumber
        self.totalDays = totalDays
        _clock = State(initialValue: Self.clock(for: tripMap))
        _position = State(initialValue: tripMap.camera(focusingOn: tripMap.currentLeg))
    }

    var body: some View {
        // Once per update, not per frame: the facts change as their stories and forecasts arrive.
        let facts = self.facts
        // Every second live; about 30 times a second while a replay runs.
        TimelineView(.periodic(from: .now, by: clock.isPlaying ? 1.0 / 30 : 1)) { context in
            let time = clock.time(at: context.date)
            screen(time: time, now: context.date, facts: facts)
                .onChange(of: tripMap.legInMotion(at: time)?.id) { _, legID in
                    refit(legID: legID)
                }
        }
        .sheet(isPresented: isShowingSheet, onDismiss: finishClosing) {
            FactsSheet(facts: facts, clock: $clock, stop: $sheetStop, screenHeight: screenFrame.height, height: $sheetHeight)
        }
        // Both start again when a flight's route or times change, so a new delay fetches the new landing hour.
        .task(id: LegStoryStore.preparationKey(for: tripMap)) { await storyStore.prepare(tripMap) }
        .task(id: LegStoryStore.preparationKey(for: tripMap)) { await weather.keepRefreshing(for: tripMap) }
        .task(id: isClosing) {
            // Should the sheet never report going, as when Close comes while it's still sliding up, the map closes anyway.
            guard isClosing, (try? await Task.sleep(for: .seconds(1))) != nil else { return }
            dismiss()
        }
        .onChange(of: usesSidePanel) { _, isSidePanel in
            if !isSidePanel { sheetStop = .small }
        }
        .onChange(of: tripMap.span) {
            // A new schedule, such as a delay, gives the timeline new ends.
            clock = Self.clock(for: tripMap)
        }
    }

    /// Live, or for a recap paused at its trip's start.
    private static func clock(for tripMap: TripMap) -> TripReplayClock {
        tripMap.mode == .recap
            ? TripReplayClock(span: tripMap.span, pausedAt: tripMap.span.start)
            : TripReplayClock(span: tripMap.span)
    }

    private var facts: TripFacts {
        storyStore.facts(for: tripMap, forecasts: weather.forecasts, dayNumber: dayNumber, totalDays: totalDays)
    }

    @ViewBuilder
    private func screen(time: Date, now: Date, facts: TripFacts) -> some View {
        let base = ZStack(alignment: .top) {
            TripMapView(tripMap: tripMap, date: time, style: style, nightStep: nightStep,
                        position: $position, isInteractive: true)
                // The camera frames the trip in what the sheet or the panel leaves clear.
                .safeAreaPadding(.bottom, mapBottomClearance)
                .safeAreaPadding(.leading, mapLeadingClearance)
                .ignoresSafeArea()
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screenFrame = $0 }
            topBar(time: time)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topBarHeight = $0 }
        }
        if usesSidePanel {
            base.overlay(alignment: .bottomLeading) {
                FactsPanel(facts: facts, clock: $clock, time: time, now: now, isExpanded: $isPanelExpanded)
                    .frame(width: Self.panelWidth)
                    .padding([.horizontal, .bottom])
                    .padding(.top, topBarHeight + 8)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxX } action: { panelTrailingEdge = $0 }
            }
        } else {
            base
        }
    }

    private func topBar(time: Date) -> some View {
        TripMapTopBar(
            pill: TripMapWording.topPill(for: tripMap, at: time, dayNumber: dayNumber, totalDays: totalDays),
            style: style,
            isShowingRecenter: position.positionedByUser,
            onClose: close,
            onRecenter: { refit(legID: tripMap.legInMotion(at: time)?.id, force: true) },
            onNextStyle: { style = style.next }
        )
    }

    /// iPad, and iPhone in landscape.
    private var usesSidePanel: Bool {
        horizontalSizeClass == .regular || verticalSizeClass == .compact
    }

    /// The sheet's height, up to the middle stop: higher, the map is mostly covered and stays framed as it was.
    private var mapBottomClearance: CGFloat {
        usesSidePanel ? 0 : min(sheetHeight, screenFrame.height / 2)
    }

    /// From the screen's leading edge to the panel's trailing edge, open or folded, with its padding.
    private var mapLeadingClearance: CGFloat {
        usesSidePanel ? max(0, panelTrailingEdge - screenFrame.minX) : 0
    }

    /// The sheet shows on iPhone in portrait until Close. The family can't dismiss it themselves.
    private var isShowingSheet: Binding<Bool> {
        Binding(get: { !usesSidePanel && !isClosing }, set: { _ in })
    }

    /// With the sheet up, it goes first and the map follows in `finishClosing`.
    private func close() {
        if usesSidePanel {
            dismiss()
        } else {
            isClosing = true
        }
    }

    private func finishClosing() {
        if isClosing { dismiss() }
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
