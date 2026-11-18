//
//  TripMapCornerPlacementTests.swift
//  CrewluvTests
//
//  Where the latest event's banner and the key to the two planes go along the map's top (which plane design §2): the
//  key beside the banner where the two fit with a gap, else just under it, at the trailing edge either way.
//

import XCTest
import CoreGraphics
@testable import Crewluv

final class TripMapCornerPlacementTests: XCTestCase {

    private let banner = CGSize(width: 180, height: 44)
    private let key = CGSize(width: 170, height: 24)

    // MARK: - On the card, the banner at the leading edge

    func test_key_besideTheBanner_whereTheyFitWithAGap() {
        // 180 + 6 + 170 = 356.
        let placement = TripMapCornerPlacement(width: 356, banner: banner, reservedWidth: 180, key: key)
        XCTAssertEqual(placement.banner, CGRect(x: 0, y: 0, width: 180, height: 44))
        XCTAssertEqual(placement.key, CGRect(x: 186, y: 0, width: 170, height: 24))
        XCTAssertEqual(placement.height, 44)
    }

    func test_key_justUnderTheBanner_atTheTrailingEdge_whereTheyDont() {
        let placement = TripMapCornerPlacement(width: 355, banner: banner, reservedWidth: 180, key: key)
        XCTAssertEqual(placement.key, CGRect(x: 185, y: 50, width: 170, height: 24))
        XCTAssertEqual(placement.height, 74)
    }

    func test_key_goesByTheWidestTheBannerCanBe_soItDoesntMoveAsTheMinutesCountUp() {
        // "Just now" makes a narrow banner, but "About 88 h 88 min ago" wouldn't leave room beside it.
        let narrow = CGSize(width: 120, height: 44)
        let placement = TripMapCornerPlacement(width: 356, banner: narrow, reservedWidth: 200, key: key)
        XCTAssertEqual(placement.banner, CGRect(x: 0, y: 0, width: 120, height: 44))
        XCTAssertEqual(placement.key?.minY, 50)
        // A title wider than the widest "when" is what the banner reserves.
        let wide = TripMapCornerPlacement(width: 356, banner: CGSize(width: 190, height: 44), reservedWidth: 150, key: key)
        XCTAssertEqual(wide.key?.minY, 50)
    }

    // MARK: - On the full-screen map, the banner centred

    func test_centredBanner_keyBesideIt_whereItsTrailingHalfLeavesRoom() {
        // The banner's trailing edge is at (560 + 180) / 2 = 370; 370 + 6 + 170 = 546 fits in 560.
        let placement = TripMapCornerPlacement(width: 560, banner: banner, reservedWidth: 180, isCentered: true, key: key)
        XCTAssertEqual(placement.banner, CGRect(x: 190, y: 0, width: 180, height: 44))
        XCTAssertEqual(placement.key, CGRect(x: 390, y: 0, width: 170, height: 24))
    }

    func test_centredBanner_keyUnderIt_onAPhone() {
        let placement = TripMapCornerPlacement(width: 361, banner: banner, reservedWidth: 180, isCentered: true, key: key)
        XCTAssertEqual(placement.banner?.midX, 180.5)
        XCTAssertEqual(placement.key, CGRect(x: 191, y: 50, width: 170, height: 24))
        XCTAssertEqual(placement.height, 74)
    }

    // MARK: - One without the other

    func test_noBanner_keyAtTheTrailingEdgeOfTheTop() {
        let placement = TripMapCornerPlacement(width: 300, banner: nil, key: key)
        XCTAssertNil(placement.banner)
        XCTAssertEqual(placement.key, CGRect(x: 130, y: 0, width: 170, height: 24))
        XCTAssertEqual(placement.height, 24)
    }

    func test_noKey_theBannerAlone() {
        let placement = TripMapCornerPlacement(width: 300, banner: banner, reservedWidth: 260, key: nil)
        XCTAssertEqual(placement.banner, CGRect(x: 0, y: 0, width: 180, height: 44))
        XCTAssertNil(placement.key)
        XCTAssertEqual(placement.height, 44)
    }

    func test_neither_isNothing() {
        XCTAssertEqual(TripMapCornerPlacement(width: 300, banner: nil, key: nil).height, 0)
    }

    // MARK: - The widest "when"

    func test_widestEventWhen_isAtLeastAsLongAsAnyWhenAFlightCanShow() {
        let widest = FactsWording.widestEventWhen
        let event = Milestone(kind: .halfway, time: FactsTestData.equinox, isEstimate: true)
        for minutes in stride(from: 0, through: 24 * 60, by: 1) {
            let when = FactsWording.eventWhen(event, at: FactsTestData.equinox.addingTimeInterval(TimeInterval(minutes * 60)))
            XCTAssertLessThanOrEqual(when.count, widest.count, when)
        }
    }
}
