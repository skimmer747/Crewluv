//
//  TripTimelineBlocks.swift
//  CrewLuve
//
//  The timeline bar's colored blocks (activity markers design §4.1): flying blue, driving gray, and each wait in its
//  marker's color, in full color up to the thumb and paler ahead. A wait's length is written on its block when it fits
//  at the current text size. Drawn on every tick of a replay, so it's one `Canvas`.
//

import CoreGraphics
import SwiftUI

struct TripTimelineBlocks: View {
    let blocks: [TripTimeline.Block]
    /// Where the replay is, 0...1.
    let progress: Double
    /// Half the thumb: the bar lays its blocks along the thumb's travel (`TripTimelineTrack`).
    let inset: CGFloat

    /// The share of its color a block keeps ahead of the replay.
    private static let aheadOpacity = 0.35
    /// The least room each side of a length inside its block.
    private static let labelPadding: CGFloat = 3
    /// How far each block runs under the next, so no seam shows between them.
    private static let seamOverlap: CGFloat = 0.5

    var body: some View {
        Canvas { context, size in
            let track = TripTimelineTrack(width: size.width, inset: inset)
            let rects = blocks.map { block in
                let edges = track.blockEdges(from: block.start, to: block.end)
                return CGRect(x: edges.leading, y: 0, width: max(0, edges.trailing - edges.leading), height: size.height)
            }
            let thumbX = track.x(at: progress)
            // Ahead: paler, as one layer, so the blocks' overlaps don't darken. Lengths in the text color, for the
            // blocks not yet wholly played.
            context.drawLayer { ahead in
                ahead.opacity = Self.aheadOpacity
                fill(rects, in: ahead)
            }
            writeLengths(in: rects, on: context, color: .primary) { $0.maxX > thumbX }
            // Played: full color up to the thumb, with white lengths for the blocks it has reached.
            var played = context
            played.clip(to: Path(CGRect(x: 0, y: 0, width: thumbX, height: size.height)))
            fill(rects, in: played)
            writeLengths(in: rects, on: played, color: .white) { $0.minX < thumbX }
        }
        .accessibilityHidden(true)
    }

    private func fill(_ rects: [CGRect], in context: GraphicsContext) {
        for (block, rect) in zip(blocks, rects) {
            let overlapping = CGRect(x: rect.minX, y: rect.minY, width: rect.width + Self.seamOverlap, height: rect.height)
            context.fill(Path(overlapping), with: .color(block.kind.color))
        }
    }

    /// Writes each wait's length in the middle of its block, when it fits with room to spare each side. Only blocks
    /// `isShown` accepts are measured: each pass skips the blocks the other one covers, as this runs on every tick.
    private func writeLengths(in rects: [CGRect], on context: GraphicsContext, color: Color,
                              isShown: (CGRect) -> Bool) {
        for (block, rect) in zip(blocks, rects) where isShown(rect) {
            guard let length = block.label else { continue }
            let text = context.resolve(Text(length).font(.caption2.weight(.semibold)).foregroundStyle(color))
            let size = text.measure(in: CGSize(width: CGFloat.infinity, height: CGFloat.infinity))
            guard size.width + 2 * Self.labelPadding <= rect.width, size.height <= rect.height else { continue }
            context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY))
        }
    }
}
