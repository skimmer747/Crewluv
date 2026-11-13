//
//  PlaneHeading.swift
//  CrewLuve
//
//  Which way the trip map's plane points (moving map spec §7.2). Ported from CrewLu's moving map, keeping only
//  what a map that never rotates needs: its camera always faces north, so the angle comes from the coordinates
//  alone and no screen points are needed.
//
//  Angles are in radians as the screen draws them: 0 points right (east) and a quarter turn points down (south).
//  SF Symbols' "airplane" points right, so `rotationEffect(.radians(angle))` aims it.
//

import CoreLocation

nonisolated enum PlaneHeading {

    /// How far ahead along the leg the plane is aimed, as a share of the leg.
    static let lookAhead: Double = 0.005

    /// The two places on a leg to aim between when the plane is `fraction` of the way along it. Near the end of
    /// the leg there is no room ahead, so the aim is along the last stretch.
    static func aimFractions(at fraction: Double, lookAhead: Double = PlaneHeading.lookAhead) -> (from: Double, to: Double) {
        let here = min(max(fraction, 0), 1)
        if here + lookAhead <= 1 { return (here, here + lookAhead) }
        return (max(1 - lookAhead, 0), 1)
    }

    /// The smallest turn that takes the angle `from` to the angle `to`: never more than half a turn either way.
    static func shortestTurn(from: Double, to: Double) -> Double {
        var turn = (to - from).truncatingRemainder(dividingBy: 2 * .pi)
        if turn > .pi { turn -= 2 * .pi }
        if turn < -.pi { turn += 2 * .pi }
        return turn
    }

    /// The angle to show next when the plane was showing `previous` and should now point at `target`: `target`
    /// moved by whole turns to sit the short way round from `previous`, so an animated turn never spins the long way.
    static func continuing(_ previous: Double, toward target: Double) -> Double {
        previous + shortestTurn(from: previous, to: target)
    }

    /// The direction from one place to another on a flat map facing north. Nil when the two places are the same.
    static func flatMapAngle(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double? {
        var east = to.longitude - from.longitude
        if east > 180 { east -= 360 }
        if east < -180 { east += 360 }
        let dx = east * .pi / 180
        let north = flatMapY(to.latitude) - flatMapY(from.latitude)
        guard dx != 0 || north != 0 else { return nil }
        // The screen's y grows downward, so north is up the screen.
        return atan2(-north, dx)
    }

    /// How far north a latitude sits on a flat (Mercator) map, in the same units as longitude in radians. The
    /// poles are infinitely far up a flat map, so the latitude is held just short of them.
    private static func flatMapY(_ latitude: Double) -> Double {
        let held = min(max(latitude, -89.9), 89.9)
        return log(tan(.pi / 4 + held * .pi / 360))
    }
}
