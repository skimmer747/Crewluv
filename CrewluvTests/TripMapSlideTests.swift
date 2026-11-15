//
//  TripMapSlideTests.swift
//  CrewluvTests
//
//  How far the trip map slides to keep the pilot's ground marker in view (base waits and card framing design §4.2):
//  not at all when it's clear, the least distance along each axis when it isn't, and centered when it can't fit.
//

import XCTest
import CoreGraphics
@testable import Crewluv

final class TripMapSlideTests: XCTestCase {

    /// A card's map, 360 × 220, inside its margins: 16 points each side, 44 at the top and bottom for the chips.
    private let band = CGRect(x: 16, y: 44, width: 328, height: 132)

    func test_markerFrame_standsOnThePoint_withRoomAllRound() {
        XCTAssertEqual(TripMapSlide.markerFrame(standingOn: CGPoint(x: 100, y: 100), size: CGSize(width: 24, height: 24)),
                       CGRect(x: 80, y: 68, width: 40, height: 40))
    }

    func test_offset_aMarkerInside_staysPut() {
        XCTAssertEqual(TripMapSlide.offset(moving: CGRect(x: 100, y: 80, width: 40, height: 40), inside: band), .zero)
    }

    func test_offset_offTheLeadingEdge_slidesJustInside() {
        XCTAssertEqual(TripMapSlide.offset(moving: CGRect(x: -60, y: 80, width: 40, height: 40), inside: band),
                       CGVector(dx: 76, dy: 0))
    }

    func test_offset_underTheBottomChip_slidesUpIntoTheBand() {
        XCTAssertEqual(TripMapSlide.offset(moving: CGRect(x: 100, y: 170, width: 40, height: 40), inside: band),
                       CGVector(dx: 0, dy: -34))
    }

    func test_offset_pastTheTrailingEdgeAndUnderTheTopChip_slidesAlongBothAxes() {
        XCTAssertEqual(TripMapSlide.offset(moving: CGRect(x: 330, y: 10, width: 40, height: 40), inside: band),
                       CGVector(dx: -26, dy: 34))
    }

    func test_offset_aMarkerTallerThanTheBand_isCenteredInIt() {
        let thinBand = CGRect(x: 16, y: 100, width: 328, height: 20)
        XCTAssertEqual(TripMapSlide.offset(moving: CGRect(x: 100, y: 0, width: 40, height: 40), inside: thinBand),
                       CGVector(dx: 0, dy: 90))
    }
}
