//
//  FlightTrackingPopupView.swift
//  CrewLuve
//
//  Compact popup for opening flight on FlightRadar24 or FlightAware
//

import SwiftUI
import UIKit

struct FlightTrackingPopupView: View {
    let flightNumber: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Dismissable backdrop
            Color.black.opacity(appeared ? 0.3 : 0)
                .background(.ultraThinMaterial.opacity(appeared ? 1 : 0))
                .ignoresSafeArea()
                .onTapGesture { dismissView() }

            // Card
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "airplane")
                        .foregroundColor(.blue)
                    Text(FlightTrackingHelper.displayFlightNumber(flightNumber))
                        .font(.title3)
                        .fontWeight(.bold)
                    Spacer()
                    Button { dismissView() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.secondary)
                    }
                }

                Text("Track this flight")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // FlightRadar24 button
                if let fr24URL = FlightTrackingHelper.flightRadar24URL(for: flightNumber) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        openURL(fr24URL)
                        dismissView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.title3)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("FlightRadar24")
                                    .font(.headline)
                                Text("Live tracking map")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                // FlightAware button
                if let faURL = FlightTrackingHelper.flightAwareURL(for: flightNumber) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        openURL(faURL)
                        dismissView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "location.fill.viewfinder")
                                .font(.title3)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("FlightAware")
                                    .font(.headline)
                                Text("Flight status & history")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.12))
                        .foregroundColor(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(maxWidth: 340)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .scaleEffect(appeared ? 1.0 : 0.5)
            .opacity(appeared ? 1.0 : 0)
        }
        .presentationBackground(.clear)
        .onAppear {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }

    private func dismissView() {
        withAnimation(.easeOut(duration: 0.2)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
        }
    }
}
