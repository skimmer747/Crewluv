//
//  PlaneKey.swift
//  CrewLuve
//
//  The key to the map's two planes (which plane design §2): the real plane's mark beside "Real plane", and the
//  ghost's beside "On schedule", each drawn as `PlaneMarker` draws it on the map, in the glass of the map's buttons.
//  It's the key to a picture VoiceOver doesn't see, so VoiceOver doesn't see it either: the card's sentence and the
//  pill say how the real plane is doing.
//

import SwiftUI

struct PlaneKey: View {
    var body: some View {
        // Side by side, or one over the other where the text is too large for that.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { items }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .glassEffect(.regular, in: .capsule)
            VStack(alignment: .leading, spacing: 4) { items }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }
        .font(.caption.weight(.semibold))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var items: some View {
        item("Real plane", isGhost: false)
        item("On schedule", isGhost: true)
    }

    private func item(_ name: String, isGhost: Bool) -> some View {
        HStack(spacing: 5) {
            Mark(isGhost: isGhost)
            Text(name)
                .lineLimit(1)
        }
    }

    /// A plane's mark, as on the map: the real plane a blue circle with a white border, the ghost a dashed outline.
    private struct Mark: View {
        let isGhost: Bool

        @ScaledMetric(relativeTo: .caption) private var diameter: CGFloat = 12

        var body: some View {
            Circle()
                .fill(isGhost ? Color.clear : Color.blue)
                .strokeBorder(isGhost ? Color.primary : Color.white,
                              style: StrokeStyle(lineWidth: 1.5, dash: isGhost ? [3, 2] : []))
                .frame(width: diameter, height: diameter)
        }
    }
}

#Preview {
    PlaneKey()
        .padding()
        .background(.teal)
}
