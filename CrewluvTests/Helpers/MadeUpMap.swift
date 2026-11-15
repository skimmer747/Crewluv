//
//  MadeUpMap.swift
//  CrewluvTests
//
//  A stand-in for the real map in `MapProjection`'s tests, ported from CrewLu's FlatMapFitTests. It slides, scales
//  and turns, and nothing else. The tests ask it about three places, as the app asks the real map, and then check
//  every other place against it.
//

import CoreGraphics
import Foundation
@testable import Crewluv

/// Shows the flat-map place `center` at `origin`, with one whole world `worldWidth` points wide, turned clockwise by
/// `degrees` as a twist of a real map would turn it.
struct MadeUpMap {
    let center: FlatMapPoint
    let origin: CGPoint
    let worldWidth: Double
    let degrees: Double

    func screen(_ point: FlatMapPoint) -> CGPoint {
        let dx = (point.x - center.x) * worldWidth
        let dy = (point.y - center.y) * worldWidth
        let turn = degrees * .pi / 180
        return CGPoint(x: Double(origin.x) + dx * cos(turn) - dy * sin(turn),
                       y: Double(origin.y) + dx * sin(turn) + dy * cos(turn))
    }

    /// The projection made the way the app makes it: ask about the centre and the two places `probes` gives.
    func projection(step: Double = 0.05) -> MapProjection? {
        let probes = MapProjection.probes(around: center, step: step)
        return MapProjection(center: center, eastProbe: probes.east, southProbe: probes.south,
                             centerOnScreen: screen(center), eastOnScreen: screen(probes.east),
                             southOnScreen: screen(probes.south))
    }
}
