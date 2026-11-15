//
//  FlatMapPoint.swift
//  CrewLuve
//
//  A place on the flat map, for the trip map's own drawing (`MapProjection`). Ported from CrewLu's moving map
//  (Duty/Duty/Views/Map/FlatMapFit.swift), where it shares a file with the fit.
//

import Foundation

/// A place on the flat map. `x` runs from 0 at 180 degrees west to 1 at 180 degrees east. `y` runs from 0 at the
/// map's top edge to 1 at its bottom edge. One whole world is 1 wide and 1 tall. An `x` outside 0...1 is the same
/// place on another copy of the world, further along.
nonisolated struct FlatMapPoint: Equatable {
    let x: Double
    let y: Double
}
