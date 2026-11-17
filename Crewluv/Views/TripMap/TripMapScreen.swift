//
//  TripMapScreen.swift
//  CrewLuve
//
//  The full-screen trip map (moving map spec §6, Stage 2 spec §6): pan and zoom, change the style, replay the trip and
//  read its facts. On iPhone the facts are a sheet you drag up; on iPad and in landscape, a panel down the leading
//  edge. A recap opens paused at its trip's start. Weather on landing is fetched while the screen is open. Quick
//  layovers, remembered for every trip, hurries a replay through the waits on the ground (activity markers design §3).
//

import SwiftUI

struct TripMapScreen: View {
    /// Where Quick layovers is remembered. It's on until the family turns it off (activity markers design §3.1).
    static let quickLayoversKey = "tripMapQuickLayovers"

    let tripMap: TripMap
    let storyStore: LegStoryStore
    let dayNumber: Int?
    let totalDays: Int?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(TripMapScreen.quickLayoversKey) private var isQuickLayovers = true
    @State private var clock: TripReplayClock
    @State private var style: TripMapStyle = .hybrid
    @State private var camera: TripMapCamera
    @State private var weather = LandingWeather()
    @State private var sheetStop: FactsSheet.Stop = .small
    /// How far up the screen the sheet reaches.
    @State private var sheetHeight: CGFloat = 0
    /// The map's frame, the whole screen, in window coordinates.
    @State private var screenFrame: CGRect = .zero
    /// The side panel's trailing edge, in window coordinates.
    @State private var panelTrailingEdge: CGFloat = 0
    @State private var topBarHeight: CGFloat = 0
    /// The bottom of the top bar and the latest event's banner under it, in window coordinates.
    @State private var topChromeBottom: CGFloat = 0
    @State private var isPanelExpanded = true
    @State private var isClosing = false

    private static let panelWidth: CGFloat = 380

    init(tripMap: TripMap, storyStore: LegStoryStore, dayNumber: Int?, totalDays: Int?) {
        self.tripMap = tripMap
        self.storyStore = storyStore
        self.dayNumber = dayNumber
        self.totalDays = totalDays
        // The remembered setting, read from the defaults `@AppStorage` uses, since the property can't be read yet.
        // `onChange(of: isQuickLayovers, initial: true)` keeps the clock in step with it from then on.
        let rememberedQuickLayovers = UserDefaults.standard.object(forKey: Self.quickLayoversKey) as? Bool ?? true
        let clock = Self.clock(for: tripMap, isQuickLayovers: rememberedQuickLayovers)
        _clock = State(initialValue: clock)
        _camera = State(initialValue: TripMapCamera(framing: tripMap.framingRect(focusingOn: tripMap.currentLeg),
                                                    keeping: tripMap.pilotLocation(at: clock.time(at: .now))?.coordinate))
    }

    var body: some View {
        // Once per update, not per frame: the facts change as their stories and forecasts arrive, and the timeline's
        // blocks as the clock's pace does.
        let facts = self.facts
        let timeline = TripTimeline(tripMap: tripMap, clock: clock)
        content(facts: facts, timeline: timeline)
            .sheet(isPresented: isShowingSheet, onDismiss: finishClosing) {
                FactsSheet(facts: facts, timeline: timeline, clock: $clock, isQuickLayovers: $isQuickLayovers,
                           stop: $sheetStop, screenHeight: screenFrame.height, height: $sheetHeight)
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
            .onChange(of: Self.replayLegs(of: tripMap)) {
                // New times, such as a delay or the real plane's newest landing estimate, give the timeline new ends
                // and a new pace. A replay carries on from the moment it was at (Stage 3 spec §7.3).
                clock = clock.carried(to: tripMap.span, legs: Self.replayLegs(of: tripMap),
                                      waits: Self.replayWaits(of: tripMap), at: .now)
            }
            .onChange(of: isQuickLayovers, initial: true) { _, isOn in
                // The replay carries on from the same moment at the new pace.
                clock.setQuickLayovers(isOn, at: .now)
            }
    }

    /// The map and its controls: every second live, and up to 60 times a second while a replay runs, so the night
    /// sweeps smoothly through a quick layover. The map draws its night and lines for each tick's time.
    private func content(facts: TripFacts, timeline: TripTimeline) -> some View {
        TimelineView(.animation(minimumInterval: clock.isPlaying ? 1.0 / 60 : 1)) { context in
            let time = clock.time(at: context.date)
            screen(time: time, now: context.date, facts: facts, timeline: timeline)
                .onChange(of: tripMap.legInMotion(at: time)?.id) { _, legID in
                    refit(legID: legID, at: time)
                }
                .onChange(of: clock.hasFinished(at: context.date)) { _, hasFinished in
                    // A finished replay holds its end, paused, so the map stops updating with nothing moving. Play
                    // starts it over, as before.
                    if hasFinished { clock.pause(at: .now) }
                }
        }
    }

    /// Live, or for a recap paused at its trip's start. A short leg slows the replay while it moves, and with Quick
    /// layovers on each wait hurries by.
    private static func clock(for tripMap: TripMap, isQuickLayovers: Bool) -> TripReplayClock {
        let legs = replayLegs(of: tripMap)
        let waits = replayWaits(of: tripMap)
        return tripMap.mode == .recap
            ? TripReplayClock(span: tripMap.span, legs: legs, waits: waits, isQuickLayovers: isQuickLayovers,
                              pausedAt: tripMap.span.start)
            : TripReplayClock(span: tripMap.span, legs: legs, waits: waits, isQuickLayovers: isQuickLayovers)
    }

    /// Each drive and flight, from its start to its end with any delay.
    private static func replayLegs(of tripMap: TripMap) -> [TripReplayClock.Stretch] {
        tripMap.legs.map { TripReplayClock.Stretch(start: $0.start, end: $0.end) }
    }

    /// Each wait on the ground, from its start to its end.
    private static func replayWaits(of tripMap: TripMap) -> [TripReplayClock.Stretch] {
        tripMap.waits.map { TripReplayClock.Stretch(start: $0.start, end: $0.end) }
    }

    /// The facts at the clock's moments. They're a replay's while the clock isn't live: a real plane is then where
    /// its record has it, with no height or speed (Stage 3 spec §7.3).
    private var facts: TripFacts {
        storyStore.facts(for: tripMap, forecasts: weather.forecasts, dayNumber: dayNumber, totalDays: totalDays,
                         isReplay: !clock.isLive)
    }

    @ViewBuilder
    private func screen(time: Date, now: Date, facts: TripFacts, timeline: TripTimeline) -> some View {
        let latest = facts.latestEvent(at: time)
        let showsKey = TripMapDrawing.showsPlaneKey(on: tripMap, at: time, isReplay: !clock.isLive)
        let base = ZStack(alignment: .top) {
            // The camera frames the trip in what the sheet or the panel leaves clear, and under the latest event and
            // the key.
            TripMapView(tripMap: tripMap, date: time, style: style, camera: $camera,
                        clearance: TripMapClearance(top: latest == nil && !showsKey ? 0 : mapTopClearance,
                                                    leading: mapLeadingClearance, bottom: mapBottomClearance),
                        isFullScreen: true, isReplay: !clock.isLive)
                .ignoresSafeArea()
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screenFrame = $0 }
            topChrome(time: time, latest: latest, showsKey: showsKey)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { topChromeBottom = $0 }
        }
        if usesSidePanel {
            base.overlay(alignment: .bottomLeading) {
                FactsPanel(facts: facts, timeline: timeline, clock: $clock, isQuickLayovers: $isQuickLayovers,
                           time: time, now: now, isExpanded: $isPanelExpanded)
                    .frame(width: Self.panelWidth)
                    .padding([.horizontal, .bottom])
                    .padding(.top, topBarHeight + 8)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxX } action: { panelTrailingEdge = $0 }
            }
        } else {
            base
        }
    }

    /// The top bar, and in flight the latest event's banner under its pill (latest event design §1) with the key to
    /// the two planes under the buttons (which plane design §2). Only the bar pads the side panel: the banner is
    /// centred and the key at the trailing edge, clear of it.
    private func topChrome(time: Date, latest: LatestEvent?, showsKey: Bool) -> some View {
        VStack(spacing: 8) {
            topBar(time: time)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topBarHeight = $0 }
            if latest != nil || showsKey {
                TripMapCorner(latest: latest, showsKey: showsKey, isCentered: true)
                    .padding(.horizontal)
            }
        }
    }

    private func topBar(time: Date) -> some View {
        TripMapTopBar(
            pill: TripMapWording.topPill(for: tripMap, at: time, dayNumber: dayNumber, totalDays: totalDays,
                                         isReplay: !clock.isLive),
            style: style,
            isShowingRecenter: camera.isPositionedByUser,
            onClose: close,
            onRecenter: { refit(legID: tripMap.legInMotion(at: time)?.id, at: time, force: true) },
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

    /// From the screen's top edge to a little below the latest event's banner and the key.
    private var mapTopClearance: CGFloat {
        max(0, topChromeBottom - screenFrame.minY) + 8
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

    /// Frames the leg in motion, or the whole trip, keeping the pilot's ground marker at `time` in view. Leaves a
    /// camera the family moved alone, unless they asked.
    private func refit(legID: String?, at time: Date, force: Bool = false) {
        guard force || !camera.isPositionedByUser else { return }
        let leg = legID.flatMap { id in tripMap.legs.first { $0.id == id } }
        camera.frame(tripMap.framingRect(focusingOn: leg), keeping: tripMap.pilotLocation(at: time)?.coordinate,
                     animated: !reduceMotion)
    }
}
