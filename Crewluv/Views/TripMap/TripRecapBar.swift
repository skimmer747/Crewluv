//
//  TripRecapBar.swift
//  CrewLuve
//
//  The bar under the recap card's map (Stage 2 spec §6.5): up to four numbers, then the longest flight. At the
//  largest text sizes the numbers stack. VoiceOver reads the card's button, which says all of it in one sentence.
//

import SwiftUI

struct TripRecapBar: View {
    let tiles: [RecapTile]
    let longest: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            tileLayout {
                ForEach(tiles) { tile in
                    VStack(spacing: 2) {
                        Text(tile.value)
                            .font(.headline)
                            .monospacedDigit()
                        Text(tile.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center)
                }
            }
            if let longest {
                Text(longest)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .accessibilityHidden(true)
    }

    private var tileLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 8))
    }
}
