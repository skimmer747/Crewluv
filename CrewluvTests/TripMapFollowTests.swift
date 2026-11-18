//
//  TripMapFollowTests.swift
//  CrewluvTests
//
//  The frame that follows the plane (follow the plane design §3). The flight is `FactsTestData`'s equator flight from E0 to
//  E20, 1,382 mi: its gates at 10:00 and 13:22 UTC, its plan in the air from 10:15 to 13:15, flown by the schedule.
//

import XCTest
import MapKit
@testable import Crewluv

final class TripMapFollowTests: XCTestCase {

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    private let flight = FactsTestData.equatorFlight(from: 0, to: 20)

    private func point(longitude: Double) -> MKMapPoint {
        MKMapPoint(CLLocationCoordinate2D(latitude: 0, longitude: longitude))
    }

    /// A rectangle as numbers XCTest can compare: MapKit's isn't `Equatable`.
    private func numbers(_ rect: MKMapRect?) -> [Double]? {
        rect.map { [$0.origin.x, $0.origin.y, $0.size.width, $0.size.height] }
    }

    private func holds(_ rect: MKMapRect, longitude: Double) -> Bool {
        rect.contains(point(longitude: longitude))
    }

    // MARK: - The frame

    func test_rect_midFlight_holdsThePlaneItsTailAndTheWayAhead_butNotTheStart() throws {
        let rect = try XCTUnwrap(TripMapFollow.rect(for: flight, at: at("11:45"), isReplay: false))
        let plane = flight.plane(at: at("11:45"), isReplay: false)
        XCTAssertTrue(rect.contains(MKMapPoint(plane.coordinate)))
        XCTAssertTrue(holds(rect, longitude: 20), "the destination")
        // The tail is 10% of the flight behind the plane, 2° of its 20, and the margin adds a fifth of the width.
        XCTAssertTrue(holds(rect, longitude: plane.coordinate.longitude - 3), "the tail and its margin")
        XCTAssertFalse(holds(rect, longitude: plane.coordinate.longitude - 5))
        XCTAssertFalse(holds(rect, longitude: 0), "E0 is left behind")
        let whole = try XCTUnwrap(TripMap(mode: .inFlight(legID: flight.id), legs: [flight], home: nil,
                                          span: DateInterval(start: flight.start, end: flight.end), tripDays: nil)
            .framingRect(focusingOn: flight))
        XCTAssertLessThan(rect.size.width, whole.size.width * 0.85)
    }

    func test_rect_holdsMoreAheadThanBehind_untilTheLastTenthOfTheFlight() throws {
        let rect = try XCTUnwrap(TripMapFollow.rect(for: flight, at: at("11:45"), isReplay: false))
        let plane = MKMapPoint(flight.plane(at: at("11:45"), isReplay: false).coordinate)
        XCTAssertGreaterThan(rect.maxX - plane.x, 2 * (plane.x - rect.minX))
    }

    func test_rect_growsSmallerAsTheFlightGoesOn() throws {
        let early = try XCTUnwrap(TripMapFollow.rect(for: flight, at: at("10:45"), isReplay: false))
        let middle = try XCTUnwrap(TripMapFollow.rect(for: flight, at: at("11:45"), isReplay: false))
        let late = try XCTUnwrap(TripMapFollow.rect(for: flight, at: at("12:45"), isReplay: false))
        XCTAssertGreaterThan(early.size.width, middle.size.width)
        XCTAssertGreaterThan(middle.size.width, late.size.width)
    }

    func test_rect_isNeverNarrowerThan300Miles() throws {
        // E0 to E2 is 138 mi: half way, the plane, a tail and the way ahead span far less than 300.
        let short = FactsTestData.equatorFlight(from: 0, to: 2, departure: at("10:00"), id: "short")
        let rect = try XCTUnwrap(TripMapFollow.rect(for: short, at: short.start.addingTimeInterval(short.end.timeIntervalSince(short.start) / 2),
                                                    isReplay: false))
        let least = TripMapFollow.leastWidth * MKMapPointsPerMeterAtLatitude(0)
        XCTAssertEqual(rect.size.width, least, accuracy: least * 0.01)
    }

    func test_rect_isNone_beforeThePlaneHasLeft_afterTheGate_andOnADrive() {
        XCTAssertNil(TripMapFollow.rect(for: flight, at: at("10:10"), isReplay: false), "taxiing out: the whole flight")
        XCTAssertNil(TripMapFollow.rect(for: flight, at: at("13:30"), isReplay: false), "at the gate")
        let drive = MapLeg(id: "d1", kind: .drive, origin: flight.origin, destination: flight.destination,
                           start: flight.start, end: flight.end, flightNumber: nil)
        XCTAssertNil(TripMapFollow.rect(for: drive, at: at("11:45"), isReplay: false))
    }

    func test_rect_followsTheRealPlane_whereTheMapDrawsIt() throws {
        // The real plane is seen to 6° E at 11:03, ahead of the schedule's.
        let seenUntil = FactsTestData.liveTime(atLongitude: 6)
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: seenUntil), at: seenUntil)
        let rect = try XCTUnwrap(TripMapFollow.rect(for: leg, at: seenUntil, isReplay: false))
        let plane = leg.plane(at: seenUntil, isReplay: false)
        XCTAssertEqual(plane.coordinate.longitude, 6, accuracy: 0.1)
        XCTAssertTrue(rect.contains(MKMapPoint(plane.coordinate)))
        XCTAssertTrue(holds(rect, longitude: 4.5), "its tail")
    }

    func test_rect_ofARealPlaneStillAtTheGate_isTheWholeFlightNow_butFollowsTheReplaysPlane() throws {
        let fix = LiveFlight.Fix(latitude: 0, longitude: 0, altitudeFeet: nil, groundSpeedKnots: 0, trackDegrees: nil,
                                 isOnGround: true, registration: "N370UP", typeCode: "B763", seenAt: at("11:19"))
        let atTheGate = LiveFlight(legID: "eq", callsign: "TST1", state: .ground, fix: fix, landedAt: nil, trail: [])
        let leg = try FactsTestData.equatorLiveLeg(atTheGate, at: at("11:20"))
        XCTAssertNil(TripMapFollow.rect(for: leg, at: at("11:20"), isReplay: false), "it hasn't left")
        XCTAssertNotNil(TripMapFollow.rect(for: leg, at: at("11:20"), isReplay: true), "the replay's plane, by the schedule")
    }

    func test_followCaption_saysWhatTheMapDoesNow() {
        XCTAssertEqual(TripMapWording.followCaption(isOn: true, hasFlightInAir: true), "Following the plane")
        XCTAssertEqual(TripMapWording.followCaption(isOn: false, hasFlightInAir: true), "Showing the whole flight")
        XCTAssertEqual(TripMapWording.followCaption(isOn: true, hasFlightInAir: false),
                       "Follows the plane when a flight is in the air")
        XCTAssertEqual(TripMapWording.followCaption(isOn: false, hasFlightInAir: false), "Showing the whole flight")
    }

    func test_framingRect_followsOnlyWhenAsked() throws {
        let map = TripMap(mode: .inFlight(legID: flight.id), legs: [flight], home: nil,
                          span: DateInterval(start: flight.start, end: flight.end), tripDays: nil)
        let whole = map.framingRect(focusingOn: flight)
        XCTAssertEqual(numbers(map.framingRect(focusingOn: flight, at: at("11:45"), followsPlane: false, isReplay: false)), numbers(whole))
        XCTAssertEqual(numbers(map.framingRect(focusingOn: flight, at: at("11:45"), followsPlane: true, isReplay: false)),
                       numbers(TripMapFollow.rect(for: flight, at: at("11:45"), isReplay: false)))
        XCTAssertEqual(numbers(map.framingRect(focusingOn: flight, at: at("10:10"), followsPlane: true, isReplay: false)), numbers(whole),
                       "before the plane has left")
    }
}
