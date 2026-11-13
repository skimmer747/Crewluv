//
//  TripMapInFlightBar.swift
//  CrewLuve
//
//  The bar under the card's map in flight (moving map spec §5.3): the flight number, which opens the tracking links
//  as before, and the landing time, in the family's time and the destination's.
//

import SwiftUI

struct TripMapInFlightBar: View {
    let leg: MapLeg

    @State private var isShowingTracking = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                flightBlock
                Spacer()
                landingBlock(alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 8) {
                flightBlock
                landingBlock(alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .fullScreenCover(isPresented: $isShowingTracking) {
            if let flightNumber = leg.flightNumber {
                FlightTrackingPopupView(flightNumber: flightNumber)
            }
        }
    }

    private var flightBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let flightNumber = leg.flightNumber {
                Button {
                    isShowingTracking = true
                } label: {
                    Text(flightNumber)
                        .font(.headline)
                        .underline()
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows live tracking links")
            }
            Text("In flight")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func landingBlock(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(TripMapWording.landsAt(for: leg))
                .font(.headline)
                .monospacedDigit()
            if let local = TripMapWording.arrivalLocalTime(for: leg) {
                Text(local)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
