//
//  LatestEventBanner.swift
//  CrewLuve
//
//  The newest event of the flight in the air, shown large (latest event design §1): on the card's map in its top
//  corner, and on the full-screen map under the pill. It stays until the next event.
//

import SwiftUI

struct LatestEventBanner: View {
    let event: LatestEvent
    /// Leading on the card, centred under the full-screen map's pill.
    var alignment: HorizontalAlignment = .leading

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(event.title)
                .font(.headline)
                // A long place name shrinks a little before it's cut off. At the largest text sizes it wraps instead.
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.8)
            Text(event.when)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(event.sentence)
    }
}
