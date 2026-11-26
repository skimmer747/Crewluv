//
//  TripMapInFlightBar.swift
//  CrewLuve
//
//  The bar under the card's map in flight (moving map spec §5.3, Stage 3 spec §9): the flight number, which opens
//  the tracking links as before, how the real plane is doing against the schedule, and the landing time, in the
//  family's time and the destination's.
//

import SwiftUI

struct TripMapInFlightBar: View {
    let leg: MapLeg
    /// "Live · 12 min ahead", "Not tracked live", or empty while the first answer is on its way (`TripMapWording.flightStatus`).
    let status: String
    /// "Lands 3:30 PM", or "At the gate 3:30 PM" once the real plane is down (`TripMapWording.barArrival`).
    let arrival: String

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
            if !status.isEmpty {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func landingBlock(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(arrival)
                .font(.headline)
                .monospacedDigit()
                .accessibilityLabel(ClockLabel.spoken(arrival))
                .clockLabelHelp(for: arrival)
            if let local = TripMapWording.arrivalLocalTime(for: leg) {
                Text(local)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
