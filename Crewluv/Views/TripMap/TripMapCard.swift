//
//  TripMapCard.swift
//  CrewLuve
//
//  The trip map on the status screen (moving map spec §5, Stage 2 spec §6.4, §6.5). In flight it follows the plane,
//  with the headline fact on its chip; on the ground it shows the whole trip with a heart where the pilot is; at home,
//  the next trip, or for a day after a trip, its recap. Tapping the map opens it full screen.
//

import MapKit
import SwiftUI

struct TripMapCard: View {
    let tripMap: TripMap
    let status: SharedPilotStatus
    let storyStore: LegStoryStore

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var position: MapCameraPosition
    @State private var isShowingFullScreen = false

    init(tripMap: TripMap, status: SharedPilotStatus, storyStore: LegStoryStore) {
        self.tripMap = tripMap
        self.status = status
        self.storyStore = storyStore
        _position = State(initialValue: tripMap.camera(focusingOn: tripMap.currentLeg))
    }

    var body: some View {
        // The plane moves about a pixel in ten seconds at this size, as today's map refreshed.
        TimelineView(.periodic(from: .now, by: 10)) { context in
            let facts = storyStore.facts(for: tripMap, dayNumber: status.tripDayNumber, totalDays: status.tripTotalDays)
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
        .task(id: storyKey) {
            await storyStore.prepare(tripMap)
        }
        .onChange(of: tripMap.mode) {
            position = tripMap.camera(focusingOn: tripMap.currentLeg)
        }
        .onChange(of: tripMap.legs.map(\.id)) {
            position = tripMap.camera(focusingOn: tripMap.currentLeg)
        }
        .fullScreenCover(isPresented: $isShowingFullScreen) {
            TripMapScreen(tripMap: tripMap, storyStore: storyStore, dayNumber: status.tripDayNumber, totalDays: status.tripTotalDays)
        }
    }

    /// The flights, their routes and their times: a new route or delay builds again.
    private var storyKey: [String] {
        tripMap.legs.map(LegStoryStore.timesKey(for:))
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
            TripMapView(tripMap: tripMap, date: date, style: .hybrid, position: $position)
                .allowsHitTesting(false)
                .frame(height: 220)
                .overlay(alignment: .topLeading) { overlayChip(chips.top) }
                .overlay(alignment: .bottomLeading) { overlayChip(chips.bottom, systemImage: bottomChipSymbol) }
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

    @ViewBuilder
    private func overlayChip(_ text: String?, systemImage: String? = nil) -> some View {
        if let text, !dynamicTypeSize.isAccessibilitySize {
            TripMapChip(text: text, systemImage: systemImage)
                .padding(10)
        }
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
