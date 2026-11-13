//
//  TripMapMarkers.swift
//  CrewLuve
//
//  The trip map's small fixed-size markers (moving map spec §5.1, §7.1). VoiceOver reads the card's sentence
//  instead of these.
//

import SwiftUI

enum TripMapMarkers {

    /// A white dot under each airport's code.
    struct Airport: View {
        var body: some View {
            Circle()
                .fill(.white)
                .frame(width: 7, height: 7)
                .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 0.5))
                .accessibilityHidden(true)
        }
    }

    /// Where the pilot is.
    struct Heart: View {
        var body: some View {
            Image(systemName: "heart.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.pink))
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                .accessibilityHidden(true)
        }
    }

    /// A drive, parked halfway along it, or where the pilot is while driving.
    struct Car: View {
        var body: some View {
            Image(systemName: "car.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.black.opacity(0.45)))
                .overlay(Circle().stroke(.white, lineWidth: 1))
                .accessibilityHidden(true)
        }
    }
}
