//
//  FactsSheet.swift
//  CrewLuve
//
//  The facts on iPhone (Stage 2 spec §6.1): SwiftUI's sheet over the full-screen map, in three stops. Small, the
//  headline and the timeline, measured so they fit at any text size; in the middle, a row per kind of fact; all the
//  way up, the trip so far. The map stays usable up to the middle stop, and the sheet can't be swiped away: Close
//  dismisses it.
//

import SwiftUI

struct FactsSheet: View {
    /// Where the sheet rests.
    enum Stop {
        /// The headline and the timeline.
        case small
        /// A row per kind of fact.
        case medium
        /// The trip so far.
        case large
    }

    let facts: TripFacts
    /// The timeline bar's blocks, at the clock's pace.
    let timeline: TripTimeline
    @Binding var clock: TripReplayClock
    @Binding var isQuickLayovers: Bool
    @Binding var stop: Stop
    /// The full-screen map's height. The small stop stays under half of it, below the middle stop.
    let screenHeight: CGFloat
    /// How far up the screen the sheet reaches, which the map keeps clear.
    @Binding var height: CGFloat

    /// The small stop until the header has been measured, growing with the text size.
    @ScaledMetric(relativeTo: .headline) private var estimatedHeaderHeight: CGFloat = 200
    /// The headline and the timeline, with the padding above and below them.
    @State private var headerHeight: CGFloat?
    /// The home indicator's room under the sheet's content.
    @State private var bottomInset: CGFloat = 0

    private nonisolated static let content = NamedCoordinateSpace.named("FactsSheet.content")
    /// The small stop's share of the screen at most.
    private static let smallStopLimit: CGFloat = 0.45

    var body: some View {
        // Its own clock: a sheet is a separate presentation from the map under it. Up to 60 times a second during a
        // replay, as the map, so the bar's thumb moves as smoothly.
        TimelineView(.animation(minimumInterval: clock.isPlaying ? 1.0 / 60 : 1)) { context in
            let time = clock.time(at: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FactsHeader(headline: facts.sheetHeadline(at: time), timeline: timeline,
                                activity: facts.tripMap.activity(at: time), stillOnGroundIn: facts.stillOnGroundAirport(at: time),
                                clock: $clock,
                                isQuickLayovers: $isQuickLayovers, time: time, now: context.date)
                        .onGeometryChange(for: CGFloat.self) { Self.headerExtent($0) } action: { headerHeight = $0 }
                    FactsBody(rows: facts.rows(at: time, now: context.date), tripSoFar: facts.tripSoFar(at: time),
                              showsLiveCredit: facts.showsLiveData)
                }
                .padding()
                .coordinateSpace(Self.content)
            }
            // At the small stop a drag grows the sheet, unless the header is too tall to fit and has to scroll.
            .scrollDisabled(stop == .small && !isSmallStopLimited)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height + $0.safeAreaInsets.bottom } action: { height = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomInset = $0 }
        .presentationDetents([smallDetent, .medium, .large], selection: selection)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
    }

    // MARK: - The small stop

    /// The header's height with the padding above it, and the same again below it. Nonisolated, since
    /// `onGeometryChange` takes a sendable measure.
    private nonisolated static func headerExtent(_ proxy: GeometryProxy) -> CGFloat {
        let frame = proxy.frame(in: Self.content)
        return frame.maxY + frame.minY
    }

    /// What the small stop needs to show the whole header.
    private var neededSmallHeight: CGFloat {
        (headerHeight ?? estimatedHeaderHeight) + bottomInset
    }

    private var isSmallStopLimited: Bool {
        screenHeight > 0 && neededSmallHeight > screenHeight * Self.smallStopLimit
    }

    private var smallDetent: PresentationDetent {
        .height(isSmallStopLimited ? screenHeight * Self.smallStopLimit : neededSmallHeight)
    }

    /// The stop as a detent. The small stop's height can change as the header is measured; the stop stays small.
    private var selection: Binding<PresentationDetent> {
        Binding(
            get: {
                switch stop {
                case .small: smallDetent
                case .medium: .medium
                case .large: .large
                }
            },
            set: { detent in
                stop = detent == .large ? .large : detent == .medium ? .medium : .small
            }
        )
    }
}
