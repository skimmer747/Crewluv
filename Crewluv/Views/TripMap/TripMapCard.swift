//
//  TripMapCard.swift
//  CrewLuve
//
//  The trip map on the status screen (moving map spec §5). In flight it follows the plane; on the ground it shows
//  the whole trip with a heart where the pilot is; at home, the next trip. Tapping the map opens it full screen.
//

import MapKit
import SwiftUI

struct TripMapCard: View {
    let tripMap: TripMap
    let status: SharedPilotStatus

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var position: MapCameraPosition
    @State private var isShowingFullScreen = false

    init(tripMap: TripMap, status: SharedPilotStatus) {
        self.tripMap = tripMap
        self.status = status
        _position = State(initialValue: tripMap.camera(focusingOn: tripMap.currentLeg))
    }

    var body: some View {
        // The plane moves about a pixel in ten seconds at this size, as today's map refreshed.
        TimelineView(.periodic(from: .now, by: 10)) { context in
            VStack(spacing: 0) {
                mapButton(at: context.date)
                if dynamicTypeSize.isAccessibilitySize {
                    stackedChips(at: context.date)
                }
                if tripMap.isInFlight, status.hasFlightDelay, let delay = status.effectiveFlightDelayMinutes {
                    FlightDelayBanner(delayMinutes: delay)
                }
                if let leg = tripMap.currentLeg {
                    TripMapInFlightBar(leg: leg)
                } else {
                    TripMapStatsBar(items: TripMapWording.statsItems(for: tripMap, at: context.date,
                                                                     dayNumber: status.tripDayNumber, totalDays: status.tripTotalDays))
                }
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .onChange(of: tripMap.mode) {
            position = tripMap.camera(focusingOn: tripMap.currentLeg)
        }
        .onChange(of: tripMap.legs.map(\.id)) {
            position = tripMap.camera(focusingOn: tripMap.currentLeg)
        }
        .fullScreenCover(isPresented: $isShowingFullScreen) {
            TripMapScreen(tripMap: tripMap, dayNumber: status.tripDayNumber, totalDays: status.tripTotalDays)
        }
    }

    private func mapButton(at date: Date) -> some View {
        let chips = TripMapWording.cardChips(for: tripMap, at: date)
        return Button {
            isShowingFullScreen = true
        } label: {
            TripMapView(tripMap: tripMap, date: date, style: .hybrid, position: $position)
                .allowsHitTesting(false)
                .frame(height: 220)
                .overlay(alignment: .topLeading) { overlayChip(chips.top) }
                .overlay(alignment: .bottomLeading) { overlayChip(chips.bottom) }
                .clipShape(.rect(topLeadingRadius: 20, topTrailingRadius: 20))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TripMapWording.cardSummary(for: tripMap, now: date, pilotName: status.pilotFirstName))
        .accessibilityHint("Opens the full-screen map")
    }

    @ViewBuilder
    private func overlayChip(_ text: String?) -> some View {
        if let text, !dynamicTypeSize.isAccessibilitySize {
            TripMapChip(text: text)
                .padding(10)
        }
    }

    /// At the largest text sizes the chips would cover the map, so they move below it (moving map spec §14).
    private func stackedChips(at date: Date) -> some View {
        let chips = TripMapWording.cardChips(for: tripMap, at: date)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach([chips.top, chips.bottom].compactMap { $0 }, id: \.self) { chip in
                Text(chip).font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 10)
        .accessibilityHidden(true)
    }
}
