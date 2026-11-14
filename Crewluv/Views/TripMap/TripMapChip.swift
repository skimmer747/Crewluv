//
//  TripMapChip.swift
//  CrewLuve
//
//  A line of text on the card's map (moving map spec §5.2), on Liquid Glass so it reads over any map, with a symbol
//  before it when it's something to tap, like the recap's "Replay the trip" (Stage 2 spec §6.5).
//

import SwiftUI

struct TripMapChip: View {
    let text: String
    /// An SF Symbol before the text: the recap's "Replay the trip" plays.
    var systemImage: String? = nil

    var body: some View {
        label
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            // A long headline, like a border crossing with a nearby city, shrinks a little before it's cut off.
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(.regular, in: .capsule)
    }

    @ViewBuilder
    private var label: some View {
        if let systemImage {
            Label(text, systemImage: systemImage)
        } else {
            Text(text)
        }
    }
}
