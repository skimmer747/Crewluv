//
//  TripWait.swift
//  CrewLuve
//
//  A stretch of the trip with no leg moving (activity markers design §2.2): from one leg's end, delay included, to the
//  next leg's start, and what the pilot does there. With Quick layovers on the replay hurries through it (§3.2), and
//  the timeline colors it (§4.1).
//

import Foundation

nonisolated struct TripWait: Equatable {
    /// With no ground leg from CrewLu to name it, a wait this long or longer is a layover, and a shorter one a turn.
    static let shortestLayover: TimeInterval = 8 * 3600

    let start: Date
    let end: Date
    /// `.layover`, `.turn`, `.base` or `.home`.
    let kind: TripActivity.Kind
}
