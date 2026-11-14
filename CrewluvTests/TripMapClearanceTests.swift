//
//  TripMapClearanceTests.swift
//  CrewluvTests
//
//  How the full-screen map keeps clear of the facts sheet or panel (Stage 2 spec §6.1, §6.2): the margins that Apple's
//  logo sits in and the camera frames inside, with the safe area counted once.
//

import XCTest
import UIKit
@testable import Crewluv

final class TripMapClearanceTests: XCTestCase {

    /// An iPhone in portrait: the Dynamic Island above, the home indicator below.
    private let portrait = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
    /// An iPhone in landscape: the camera housing to one side, the home indicator below.
    private let landscape = UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59)
    /// An iPhone in landscape turned the other way, with the camera housing on the left.
    private let landscapeHousingLeft = UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 0)

    func test_marginsBeyondSafeArea_noClearance_addNothing() {
        XCTAssertEqual(TripMapClearance.none.marginsBeyondSafeArea(portrait, isRightToLeft: false), .zero)
    }

    func test_marginsBeyondSafeArea_sheetAboveTheHomeIndicator_addOnlyThePartAboveIt() {
        let clearance = TripMapClearance(leading: 0, bottom: 300)
        XCTAssertEqual(clearance.marginsBeyondSafeArea(portrait, isRightToLeft: false),
                       NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 266, trailing: 0))
    }

    func test_marginsBeyondSafeArea_sheetLowerThanTheHomeIndicator_addNothing() {
        let clearance = TripMapClearance(leading: 0, bottom: 20)
        XCTAssertEqual(clearance.marginsBeyondSafeArea(portrait, isRightToLeft: false), .zero)
    }

    func test_marginsBeyondSafeArea_panelOnTheLeadingEdge_addsThePartBeyondTheSafeArea() {
        // The panel's trailing edge from the screen's leading edge: 59 of safe area, 16 of padding, 380 of panel
        // and 16 more.
        let clearance = TripMapClearance(leading: 471, bottom: 0)
        XCTAssertEqual(clearance.marginsBeyondSafeArea(landscape, isRightToLeft: false),
                       NSDirectionalEdgeInsets(top: 0, leading: 412, bottom: 0, trailing: 0))
    }

    func test_marginsBeyondSafeArea_rightToLeft_measuresFromTheRightSafeArea() {
        // Right to left, the panel is on the right, where this way round there's no safe area.
        let clearance = TripMapClearance(leading: 471, bottom: 0)
        XCTAssertEqual(clearance.marginsBeyondSafeArea(landscapeHousingLeft, isRightToLeft: true),
                       NSDirectionalEdgeInsets(top: 0, leading: 471, bottom: 0, trailing: 0))
        XCTAssertEqual(clearance.marginsBeyondSafeArea(landscapeHousingLeft, isRightToLeft: false),
                       NSDirectionalEdgeInsets(top: 0, leading: 412, bottom: 0, trailing: 0))
    }
}
