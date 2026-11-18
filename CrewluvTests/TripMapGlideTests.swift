//
//  TripMapGlideTests.swift
//  CrewluvTests
//
//  The glide toward the frame that follows the plane (follow the plane design §4).
//

import XCTest
import MapKit
@testable import Crewluv

final class TripMapGlideTests: XCTestCase {

    private let current = MKMapRect(x: 100_000_000, y: 100_000_000, width: 8_000_000, height: 8_000_000)
    private let frame: TimeInterval = 1.0 / 60

    private func numbers(_ rect: MKMapRect) -> [Double] {
        [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height]
    }

    func test_step_closesPartOfTheGap_inItsMiddleAndItsZoomAlike() {
        let target = MKMapRect(x: 104_000_000, y: 102_000_000, width: 2_000_000, height: 2_000_000)
        let next = TripMapGlide.step(from: current, toward: target, over: TripMapGlide.timeConstant)
        let share = 1 - exp(-1.0)
        XCTAssertEqual(next.midX, current.midX + (target.midX - current.midX) * share, accuracy: 1)
        XCTAssertEqual(next.midY, current.midY + (target.midY - current.midY) * share, accuracy: 1)
        // The zoom eases by the same share of its log: from 8 to 2 million is a quarter, so 4^0.632 smaller.
        XCTAssertEqual(next.size.width, 8_000_000 / pow(4, share), accuracy: 1)
        XCTAssertEqual(next.size.height, next.size.width, accuracy: 1)
    }

    func test_step_catchesUp_inAboutASecond_frameByFrame() {
        let target = MKMapRect(x: 104_000_000, y: 102_000_000, width: 2_000_000, height: 2_000_000)
        var rect = current
        for _ in 0..<60 { rect = TripMapGlide.step(from: rect, toward: target, over: frame) }
        XCTAssertLessThan(abs(rect.midX - target.midX), 0.06 * abs(current.midX - target.midX), "within 6% after a second")
        for _ in 0..<240 { rect = TripMapGlide.step(from: rect, toward: target, over: frame) }
        XCTAssertEqual(numbers(rect), numbers(target), "there, exactly, and no further")
    }

    func test_step_isNeverInAHurry() {
        // A fifth of a second on, more than half the gap is still to go.
        let target = MKMapRect(x: 104_000_000, y: 100_000_000, width: 8_000_000, height: 8_000_000)
        let next = TripMapGlide.step(from: current, toward: target, over: 0.2)
        XCTAssertGreaterThan(target.midX - next.midX, 0.5 * (target.midX - current.midX))
    }

    func test_step_neverOvershoots() {
        let target = MKMapRect(x: 104_000_000, y: 102_000_000, width: 2_000_000, height: 2_000_000)
        let next = TripMapGlide.step(from: current, toward: target, over: 60)
        XCTAssertEqual(numbers(next), numbers(target))
        XCTAssertEqual(numbers(TripMapGlide.step(from: current, toward: target, over: 0)), numbers(current), "no time, no move")
    }

    func test_step_goesTheShortWayAcrossTheDateLine() {
        let world = MKMapSize.world.width
        let west = MKMapRect(x: world - 6_000_000, y: 100_000_000, width: 4_000_000, height: 4_000_000)
        let east = MKMapRect(x: 2_000_000, y: 100_000_000, width: 4_000_000, height: 4_000_000)
        let next = TripMapGlide.step(from: west, toward: east, over: TripMapGlide.timeConstant)
        // Its middle moves east across the line, 6.32 million of the 8 million, not back across the world.
        let moved = (next.midX - west.midX + world).truncatingRemainder(dividingBy: world)
        XCTAssertEqual(moved, 8_000_000 * (1 - exp(-1.0)), accuracy: 1)
        XCTAssertGreaterThanOrEqual(next.minX, 0)
        XCTAssertLessThan(next.minX, world)
        // And back west across it, still starting on the map.
        let back = TripMapGlide.step(from: east, toward: west, over: TripMapGlide.timeConstant)
        XCTAssertGreaterThanOrEqual(back.minX, 0)
        XCTAssertLessThan(back.minX, world)
    }

    func test_isThere_onlyWhenTheGapIsTiny() {
        let nudged = MKMapRect(x: current.origin.x + 4_000, y: current.origin.y, width: current.size.width, height: current.size.height)
        XCTAssertTrue(TripMapGlide.isThere(current, at: nudged), "4,000 of 8 million: a twentieth of a percent")
        let moved = MKMapRect(x: current.origin.x + 80_000, y: current.origin.y, width: current.size.width, height: current.size.height)
        XCTAssertFalse(TripMapGlide.isThere(current, at: moved))
    }
}
