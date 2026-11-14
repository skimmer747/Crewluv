//
//  TripTimelineTrack.swift
//  CrewLuve
//
//  Where a point of the timeline sits across the bar, and back (activity markers design §4.1). The thumb's centre
//  travels between the bar's ends, inset by half the thumb as a slider's is. The blocks are laid along that travel, and
//  the first and last reach the bar's rounded ends.
//

import CoreGraphics

nonisolated struct TripTimelineTrack {
    let width: CGFloat
    /// Half the thumb: how far in from each end its centre stops.
    let inset: CGFloat

    /// The x of `progress`, 0...1, along the bar.
    func x(at progress: Double) -> CGFloat {
        inset + CGFloat(min(max(progress, 0), 1)) * travel
    }

    /// The point of the timeline at `x`, 0...1.
    func progress(atX x: CGFloat) -> Double {
        guard travel > 0 else { return 0 }
        return Double(min(max((x - inset) / travel, 0), 1))
    }

    /// Where a block from `start` to `end` begins and ends across the bar. The first block starts at the bar's leading
    /// end, and the last ends at its trailing end.
    func blockEdges(from start: Double, to end: Double) -> (leading: CGFloat, trailing: CGFloat) {
        (start <= 0 ? 0 : x(at: start), end >= 1 ? width : x(at: end))
    }

    private var travel: CGFloat { max(width - 2 * inset, 0) }
}
