//
//  TripMapCard.swift
//  CrewLuve
//
//  The trip map on the status screen (moving map spec §5, Stage 2 spec §6.4, §6.5). In flight it follows the plane,
//  with the headline fact on its chip; on the ground it shows the whole trip with a marker for what the pilot is doing
//  where they are (activity markers design §2); at home, the next trip, or for a day after a trip, its recap. Tapping
//  the map opens it full screen.
//

import SwiftUI

struct TripMapCard: View {
    let tripMap: TripMap
    let status: SharedPilotStatus
    let storyStore: LegStoryStore

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var camera: TripMapCamera
    @State private var isShowingFullScreen = false
    /// The chips' heights as last measured, for the band the trip is framed in (base waits and card framing design
    /// §4.1).
    @State private var topChipHeight: CGFloat = 0
    @State private var bottomChipHeight: CGFloat = 0

    /// How far the chips sit from the map's edges, and the gap kept between a chip and the trip.
    private static let chipInset: CGFloat = 10
    private static let chipGap: CGFloat = 4

    init(tripMap: TripMap, status: SharedPilotStatus, storyStore: LegStoryStore) {
        self.tripMap = tripMap
        self.status = status
        self.storyStore = storyStore
        _camera = State(initialValue: TripMapCamera(framing: tripMap.framingRect(focusingOn: tripMap.currentLeg),
                                                    keeping: tripMap.pilotLocation(at: .now)?.coordinate))
    }

    var body: some View {
        // Read outside the timeline, so the card updates as soon as the stories arrive, not at the next tick.
        let facts = storyStore.facts(for: tripMap, dayNumber: status.tripDayNumber, totalDays: status.tripTotalDays)
        // The plane moves about a pixel in ten seconds at this size, as today's map refreshed.
        TimelineView(.periodic(from: .now, by: 10)) { context in
            let cardChips = chips(from: facts, at: context.date)
            VStack(spacing: 0) {
                mapButton(facts: facts, chips: cardChips, at: context.date)
                if dynamicTypeSize.isAccessibilitySize {
                    stackedChips(cardChips)
                }
                if tripMap.isInFlight, status.hasFlightDelay, let delay = status.effectiveFlightDelayMinutes {
                    FlightDelayBanner(delayMinutes: delay)
                }
                bar(facts: facts, at: context.date)
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .task(id: LegStoryStore.preparationKey(for: tripMap)) {
            await storyStore.prepare(tripMap)
        }
        .onChange(of: tripMap.mode) { refit() }
        .onChange(of: tripMap.legs.map(\.id)) { refit() }
        .fullScreenCover(isPresented: $isShowingFullScreen) {
            TripMapScreen(tripMap: tripMap, storyStore: storyStore, dayNumber: status.tripDayNumber, totalDays: status.tripTotalDays)
        }
    }

    /// Frames the leg in the air, or the whole trip, afresh when the trip's state or legs change, keeping the pilot's
    /// ground marker in view.
    private func refit() {
        camera.frame(tripMap.framingRect(focusingOn: tripMap.currentLeg),
                     keeping: tripMap.pilotLocation(at: .now)?.coordinate, animated: false)
    }

    /// Stage 1's chips, with the headline fact on the bottom one in flight.
    private func chips(from facts: TripFacts, at date: Date) -> (top: String?, bottom: String?) {
        let chips = TripMapWording.cardChips(for: tripMap, at: date)
        guard tripMap.isInFlight else { return chips }
        return (chips.top, facts.headline(at: date) ?? chips.bottom)
    }

    private func mapButton(facts: TripFacts, chips: (top: String?, bottom: String?), at date: Date) -> some View {
        Button {
            isShowingFullScreen = true
        } label: {
            TripMapView(tripMap: tripMap, date: date, style: .hybrid, camera: $camera, clearance: clearance(for: chips))
                .allowsHitTesting(false)
                .frame(height: 220)
                .overlay(alignment: .topLeading) { overlayChip(chips.top, height: $topChipHeight) }
                .overlay(alignment: .bottomLeading) {
                    overlayChip(chips.bottom, systemImage: bottomChipSymbol, height: $bottomChipHeight)
                }
                .clipShape(.rect(topLeadingRadius: 20, topTrailingRadius: 20))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(facts.cardSummary(now: date, pilotName: status.pilotFirstName))
        .accessibilityHint(tripMap.mode == .recap ? "Opens the map to replay the trip" : "Opens the full-screen map")
    }

    @ViewBuilder
    private func bar(facts: TripFacts, at date: Date) -> some View {
        if let leg = tripMap.currentLeg {
            TripMapInFlightBar(leg: leg)
        } else if tripMap.mode == .recap {
            TripRecapBar(tiles: facts.recapTiles, longest: facts.recapLongestLine)
        } else {
            TripMapStatsBar(items: TripMapWording.statsItems(for: tripMap, at: date,
                                                             dayNumber: status.tripDayNumber, totalDays: status.tripTotalDays))
        }
    }

    /// A chip on the map, its height measured into `height`.
    @ViewBuilder
    private func overlayChip(_ text: String?, systemImage: String? = nil, height: Binding<CGFloat>) -> some View {
        if let text, !dynamicTypeSize.isAccessibilitySize {
            TripMapChip(text: text, systemImage: systemImage)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height.wrappedValue = $0 }
                .padding(Self.chipInset)
        }
    }

    /// The band between the chips on the map: from each edge to the far side of its chip, and a gap. With no chip on
    /// the map at an edge, nothing there.
    private func clearance(for chips: (top: String?, bottom: String?)) -> TripMapClearance {
        guard !dynamicTypeSize.isAccessibilitySize else { return .none }
        func depth(of chip: String?, height: CGFloat) -> CGFloat {
            chip == nil ? 0 : Self.chipInset + height + Self.chipGap
        }
        return TripMapClearance(top: depth(of: chips.top, height: topChipHeight),
                                bottom: depth(of: chips.bottom, height: bottomChipHeight))
    }

    /// The recap's "Replay the trip" plays.
    private var bottomChipSymbol: String? {
        tripMap.mode == .recap ? "play.fill" : nil
    }

    /// At the largest text sizes the chips would cover the map, so they move below it (moving map spec §14).
    private func stackedChips(_ chips: (top: String?, bottom: String?)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let top = chips.top {
                Text(top)
            }
            if let bottom = chips.bottom {
                if let bottomChipSymbol {
                    Label(bottom, systemImage: bottomChipSymbol)
                } else {
                    Text(bottom)
                }
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 10)
        .accessibilityHidden(true)
    }
}
