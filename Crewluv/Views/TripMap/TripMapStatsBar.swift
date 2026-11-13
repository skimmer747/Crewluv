//
//  TripMapStatsBar.swift
//  CrewLuve
//
//  The bar under the card's map on the ground (moving map spec §5.3): "Day 2 of 4 · 2 cities · 4,350 mi so far",
//  or a trip ahead's dates, cities and miles.
//

import SwiftUI

struct TripMapStatsBar: View {
    let items: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if index > 0 { Spacer(minLength: 8) }
                    label(item).lineLimit(1)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    label(item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
    }
}
