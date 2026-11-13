//
//  TripMapChip.swift
//  CrewLuve
//
//  A line of text on the card's map (moving map spec §5.2), on Liquid Glass so it reads over any map.
//

import SwiftUI

struct TripMapChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(.regular, in: .capsule)
    }
}
