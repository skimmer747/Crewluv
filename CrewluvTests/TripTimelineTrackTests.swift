//
//  TripTimelineTrackTests.swift
//  CrewluvTests
//
//  Where a point of the timeline sits across the bar, and back (activity markers design §4.1): along the thumb's
//  travel, with the first and last blocks reaching the bar's ends.
//

import XCTest
import CoreGraphics
@testable import Crewluv

final class TripTimelineTrackTests: XCTestCase {

    /// A 228 pt bar with a 28 pt thumb: 200 pt of travel, from 14 to 214.
    private let track = TripTimelineTrack(width: 228, inset: 14)

    func test_x_runsAlongTheThumbsTravel_andIsHeldToItsEnds() {
        XCTAssertEqual(track.x(at: 0), 14)
        XCTAssertEqual(track.x(at: 0.5), 114)
        XCTAssertEqual(track.x(at: 1), 214)
        XCTAssertEqual(track.x(at: 1.5), 214)
    }

    func test_progressAtX_isTheInverse_andIsHeldToTheEnds() {
        XCTAssertEqual(track.progress(atX: 64), 0.25, accuracy: 1e-12)
        XCTAssertEqual(track.progress(atX: 0), 0)
        XCTAssertEqual(track.progress(atX: 300), 1)
    }

    func test_blockEdges_theFirstAndLastReachTheBarsEnds() {
        XCTAssertEqual(track.blockEdges(from: 0, to: 0.5).leading, 0)
        XCTAssertEqual(track.blockEdges(from: 0, to: 0.5).trailing, 114)
        XCTAssertEqual(track.blockEdges(from: 0.5, to: 1).trailing, 228)
    }

    func test_progressAtX_aBarNoWiderThanTheThumb_isZero() {
        XCTAssertEqual(TripTimelineTrack(width: 28, inset: 14).progress(atX: 20), 0)
    }
}
