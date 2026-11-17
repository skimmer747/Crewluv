//
//  TripMapFollowTests.swift
//  CrewluvTests
//
//  Following the plane (follow the plane design §3, §4). The flight is `FactsTestData`'s equator flight from E0 to
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
        // The tail is 20% of the flight behind the plane, 4° of its 20.
        XCTAssertTrue(holds(rect, longitude: plane.coordinate.longitude - 4))
        XCTAssertFalse(holds(rect, longitude: 0), "E0 is left behind")
        let whole = try XCTUnwrap(TripMap(mode: .inFlight(legID: flight.id), legs: [flight], home: nil,
                                          span: DateInterval(start: flight.start, end: flight.end), tripDays: nil)
            .framingRect(focusingOn: flight))
        XCTAssertLessThan(rect.size.width, whole.size.width * 0.85)
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
        XCTAssertTrue(holds(rect, longitude: 2), "its tail")
        XCTAssertEqual(TripMapFollow.places(for: leg, at: seenUntil, isReplay: false).map(\.longitude),
                       [plane.coordinate.longitude, 20])
    }

    func test_rect_ofARealPlaneStillAtTheGate_isTheWholeFlightNow_butFollowsTheReplaysPlane() throws {
        let fix = LiveFlight.Fix(latitude: 0, longitude: 0, altitudeFeet: nil, groundSpeedKnots: 0, trackDegrees: nil,
                                 isOnGround: true, registration: "N370UP", typeCode: "B763", seenAt: at("11:19"))
        let atTheGate = LiveFlight(legID: "eq", callsign: "TST1", state: .ground, fix: fix, landedAt: nil, trail: [])
        let leg = try FactsTestData.equatorLiveLeg(atTheGate, at: at("11:20"))
        XCTAssertNil(TripMapFollow.rect(for: leg, at: at("11:20"), isReplay: false), "it hasn't left")
        XCTAssertNotNil(TripMapFollow.rect(for: leg, at: at("11:20"), isReplay: true), "the replay's plane, by the schedule")
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

    // MARK: - When the camera moves

    private let shown = MKMapRect(x: 100_000_000, y: 100_000_000, width: 10_000_000, height: 10_000_000)
    private let inside = [MKMapPoint(x: 104_000_000, y: 105_000_000).coordinate]
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func wanted(_ share: Double) -> MKMapRect {
        MKMapRect(x: 102_000_000, y: 102_000_000, width: 10_000_000 * share, height: 10_000_000 * share)
    }

    private func moves(to share: Double, after seconds: TimeInterval?, keeping places: [CLLocationCoordinate2D]? = nil) -> Bool {
        TripMapFollow.shouldMove(from: shown, to: wanted(share), keeping: places ?? inside,
                                 lastMove: seconds.map { start.addingTimeInterval(-$0) }, now: start)
    }

    func test_shouldMove_inOnlyBy15PercentOrMore() {
        XCTAssertFalse(moves(to: 0.9, after: 60))
        XCTAssertFalse(moves(to: 0.86, after: 60))
        XCTAssertTrue(moves(to: 0.85, after: 60))
        XCTAssertTrue(moves(to: 0.5, after: nil), "the first move")
        XCTAssertFalse(moves(to: 1.2, after: 60), "bigger, with the plane and the destination still in view")
        let narrower = MKMapRect(x: 102_000_000, y: 100_000_000, width: 5_000_000, height: 10_000_000)
        XCTAssertFalse(TripMapFollow.shouldMove(from: shown, to: narrower, keeping: inside, lastMove: nil, now: start),
                       "narrower but as tall: it would cut the height")
    }

    func test_shouldMove_inNoSoonerThan5SecondsAfterTheLast() {
        XCTAssertFalse(moves(to: 0.5, after: 4.9))
        XCTAssertTrue(moves(to: 0.5, after: 5))
    }

    func test_shouldMove_outAtOnce_whenThePlaneOrTheDestinationIsOutOfView() {
        let outside = [MKMapPoint(x: 115_000_000, y: 105_000_000).coordinate]
        XCTAssertTrue(moves(to: 1.2, after: 1, keeping: inside + outside))
        XCTAssertTrue(TripMapFollow.shouldMove(from: nil, to: wanted(1), keeping: inside, lastMove: start, now: start),
                      "nothing framed yet")
    }

    func test_shouldMove_holdsAPlaceAcrossTheDateLine() {
        // A frame that runs on past the map's right edge holds a place just east of the date line.
        let world = MKMapSize.world.width
        let across = MKMapRect(x: world - 5_000_000, y: 100_000_000, width: 10_000_000, height: 10_000_000)
        let eastOfIt = MKMapPoint(x: 2_000_000, y: 105_000_000).coordinate
        XCTAssertFalse(TripMapFollow.shouldMove(from: across, to: across, keeping: [eastOfIt], lastMove: nil, now: start))
    }

    // MARK: - The camera

    func test_follow_movesTheCamera_andSpacesItsSteps() {
        var camera = TripMapCamera(framing: shown)
        camera.follow(wanted(0.5), keeping: inside, at: start, animated: true)
        XCTAssertEqual(numbers(camera.rect), numbers(wanted(0.5)))
        XCTAssertEqual(camera.framingNumber, 1)
        XCTAssertTrue(camera.isAnimated)
        XCTAssertEqual(camera.followedAt, start)
        XCTAssertNil(camera.keptInView, "no ground marker to keep in flight")
        camera.follow(wanted(0.25), keeping: [], at: start.addingTimeInterval(2), animated: true)
        XCTAssertEqual(numbers(camera.rect), numbers(wanted(0.5)), "two seconds on")
    }

    func test_mayFollow_onlyWhenAMoveCouldBeDue() {
        var camera = TripMapCamera(framing: shown)
        XCTAssertTrue(camera.mayFollow(keeping: inside, at: start), "never followed yet")
        camera.follow(wanted(0.5), keeping: inside, at: start, animated: true)
        let held = [MKMapPoint(x: 104_000_000, y: 104_000_000).coordinate]
        XCTAssertFalse(camera.mayFollow(keeping: held, at: start.addingTimeInterval(4)))
        XCTAssertTrue(camera.mayFollow(keeping: held, at: start.addingTimeInterval(5)))
        let outside = [MKMapPoint(x: 115_000_000, y: 105_000_000).coordinate]
        XCTAssertTrue(camera.mayFollow(keeping: outside, at: start.addingTimeInterval(1)), "out at once")
        camera.markPositionedByUser()
        XCTAssertFalse(camera.mayFollow(keeping: outside, at: start.addingTimeInterval(10)), "the family's camera")
    }

    func test_follow_saysWhetherItMoved() {
        var camera = TripMapCamera(framing: shown)
        XCTAssertTrue(camera.follow(wanted(0.5), keeping: inside, at: start, animated: true))
        XCTAssertFalse(camera.follow(wanted(0.25), keeping: inside, at: start.addingTimeInterval(1), animated: true))
    }

    func test_follow_leavesACameraTheFamilyMoved() {
        var camera = TripMapCamera(framing: shown)
        camera.markPositionedByUser()
        camera.follow(wanted(0.5), keeping: inside, at: start, animated: true)
        XCTAssertEqual(numbers(camera.rect), numbers(shown))
        XCTAssertEqual(camera.framingNumber, 0)
    }
}
