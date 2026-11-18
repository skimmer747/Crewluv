//
//  FlightDrawingTests.swift
//  CrewluvTests
//
//  What one flight draws at a moment (Stage 3 spec §5.1, §6.2, §7.3): the real path and the two planes, by what
//  the live data says, and the schedule's plane where there's none. Held to the shared cases in Fixtures/TripMap.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class FlightDrawingTests: XCTestCase {

    private typealias Moment = TripMapFixtures.LiveCases.Flight.Moment

    private func assertSame(_ place: CLLocationCoordinate2D?, _ expected: CLLocationCoordinate2D?, _ name: String = "",
                            accuracy: Double = 1e-9, file: StaticString = #filePath, line: UInt = #line) {
        guard let place, let expected else {
            XCTFail("a place is missing: \(name)", file: file, line: line)
            return
        }
        XCTAssertEqual(place.latitude, expected.latitude, accuracy: accuracy, name, file: file, line: line)
        XCTAssertEqual(place.longitude, expected.longitude, accuracy: accuracy, name, file: file, line: line)
    }

    /// Where a line starts and ends along the flight. A dotted line is written from the plane's side back.
    private func ends(of segment: RouteSegment) -> (start: CLLocationCoordinate2D?, end: CLLocationCoordinate2D?) {
        segment.style == .unseen
            ? (segment.coordinates.last, segment.coordinates.first)
            : (segment.coordinates.first, segment.coordinates.last)
    }

    private func place(_ pair: [Double]?) -> CLLocationCoordinate2D? {
        pair.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
    }

    /// The leg of a shared case at one of its moments, and its drawing then.
    private func drawing(of name: String, at time: String, isReplay: Bool = false) throws -> (drawing: FlightDrawing, leg: MapLeg, moment: Moment) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let moment = try cases.moment(time, of: flightCase)
        let leg = try cases.mapLeg(flightCase, at: moment)
        return (FlightDrawing(leg: leg, at: moment.at, isReplay: isReplay), leg, moment)
    }

    // MARK: - Now

    func test_now_everySharedMoment_drawsThePlanesTheCaseExpects() throws {
        let cases = try TripMapFixtures.liveCases()
        var real = 0
        var scheduled = 0
        for flightCase in cases.flights {
            for moment in flightCase.moments {
                let name = "\(flightCase.name) at \(moment.at)"
                let leg = try cases.mapLeg(flightCase, at: moment)
                guard leg.isMoving(at: moment.at) else { continue }
                let drawing = FlightDrawing(leg: leg, at: moment.at, isReplay: false)
                if let plane = place(moment.plane) {
                    assertSame(drawing.realPlane?.coordinate, plane, name, accuracy: 0.0001)
                    XCTAssertEqual(drawing.realPlane?.isEstimated, moment.phase == "estimated", name)
                    XCTAssertNil(drawing.plane, name)
                    if let ghost = place(moment.ghost) {
                        assertSame(drawing.ghost?.coordinate, ghost, name, accuracy: 0.0001)
                    } else {
                        XCTAssertNil(drawing.ghost, name)
                    }
                    real += 1
                } else {
                    XCTAssertNotNil(drawing.plane, name)
                    XCTAssertNil(drawing.realPlane, name)
                    XCTAssertNil(drawing.ghost, name)
                    scheduled += 1
                }
                // The lines run from the departure airport to the arrival airport without a break.
                assertSame(drawing.segments.first.flatMap { ends(of: $0).start }, leg.origin.coordinate, name)
                assertSame(drawing.segments.last.flatMap { ends(of: $0).end }, leg.destination.coordinate, name)
                for (earlier, later) in zip(drawing.segments, drawing.segments.dropFirst()) {
                    assertSame(ends(of: later).start, ends(of: earlier).end, name)
                }
            }
        }
        XCTAssertGreaterThanOrEqual(real, 12)
        XCTAssertGreaterThanOrEqual(scheduled, 3)
    }

    func test_now_inTheAir_theRealPathIsSolidBehindThePlane_andDashedAhead() throws {
        let (drawing, leg, _) = try drawing(of: "ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(drawing.segments.map(\.style), [.seen, .upcoming])
        XCTAssertEqual(drawing.segments.map(\.id), ["f1-seen-0", "f1-upcoming"])
        let path = try XCTUnwrap(leg.flight?.path)
        XCTAssertEqual(drawing.segments[0].coordinates.count, path.knots.count + 1, "the airport, and every place it was seen")
        assertSame(drawing.segments[0].coordinates.last, drawing.realPlane?.coordinate, "the line meets the plane")
        XCTAssertEqual(drawing.segments[1].coordinates.count, 2, "from the plane straight to the airport")
        XCTAssertTrue(drawing.segments.allSatisfy(\.isGeodesic))
    }

    func test_now_inTheAir_thePlanePointsTheWayItsReallyGoing() throws {
        let (drawing, leg, _) = try drawing(of: "ahead, in the air", at: "13T12:41:50")
        let track = try XCTUnwrap(leg.flight?.live?.fix?.trackDegrees)
        XCTAssertEqual(try XCTUnwrap(drawing.realPlane?.angle), (track - 90) * .pi / 180, accuracy: 1e-9)
    }

    func test_now_inTheAir_aTrackOfNorthPointsUpTheScreen_andEastToTheRight() throws {
        // The plane's symbol points right at angle 0, and a positive angle turns it clockwise.
        let start = TripMapTestLegs.tripStart
        let louisville = TripMapTestLegs.airports["SDF"]!
        let cologne = TripMapTestLegs.airports["CGN"]!
        func angle(track: Double?) throws -> Double {
            let fix = LiveFlight.Fix(latitude: 45, longitude: -60, altitudeFeet: 38_000, groundSpeedKnots: 480, trackDegrees: track,
                                     isOnGround: false, registration: nil, typeCode: nil, seenAt: start.addingTimeInterval(3 * 3600))
            let live = LiveFlight(legID: "f", callsign: "UPS207", state: .airborne, fix: fix, landedAt: nil, trail: [])
            let flight = try XCTUnwrap(MapFlight(departure: start, arrival: start.addingTimeInterval(8 * 3600),
                                                 from: louisville, to: cologne, live: live))
            let leg = MapLeg(id: "f", kind: .flight,
                             origin: AirportMark(code: "SDF", city: nil, coordinate: louisville, timeZone: nil),
                             destination: AirportMark(code: "CGN", city: nil, coordinate: cologne, timeZone: nil),
                             start: start, end: start.addingTimeInterval(8 * 3600), flightNumber: nil, flight: flight)
            let drawing = FlightDrawing(leg: leg, at: fix.seenAt.addingTimeInterval(30), isReplay: false)
            return try XCTUnwrap(drawing.realPlane?.angle)
        }
        XCTAssertEqual(try angle(track: 0), -.pi / 2, accuracy: 1e-12, "north is up the screen")
        XCTAssertEqual(try angle(track: 90), 0, accuracy: 1e-12, "east is to the right")
        XCTAssertEqual(try angle(track: 180), .pi / 2, accuracy: 1e-12)
        // With no track the plane points along its path: from here towards Cologne, north of east.
        let alongThePath = try angle(track: nil)
        XCTAssertLessThan(alongThePath, 0)
        XCTAssertGreaterThan(alongThePath, -.pi / 2)
    }

    func test_now_aStretchNobodySaw_isDotted() throws {
        let (drawing, leg, _) = try drawing(of: "behind, with a late first point and an unseen ocean", at: "14T00:13:00")
        let path = try XCTUnwrap(leg.flight?.path)
        var expected: [RouteSegment.Style] = []
        for stretch in path.stretches where stretch.kind != .planned {
            let style: RouteSegment.Style = stretch.kind == .seen ? .seen : .unseen
            if expected.last != style { expected.append(style) }
        }
        XCTAssertEqual(drawing.segments.map(\.style), expected + [.upcoming])
        XCTAssertEqual(drawing.segments.first?.style, .unseen, "it was first seen far from the airport")
        XCTAssertGreaterThanOrEqual(drawing.segments.filter { $0.style == .unseen }.count, 2, "and not at all over the ocean")
    }

    func test_now_estimated_thePlanIsDottedBehindThePlane_whichIsFaded() throws {
        let (drawing, leg, _) = try drawing(of: "ahead, in the air", at: "13T12:45:00")
        XCTAssertEqual(drawing.segments.map(\.style), [.seen, .unseen, .upcoming])
        let path = try XCTUnwrap(leg.flight?.path)
        assertSame(ends(of: drawing.segments[1]).start, path.point(atDistance: path.flownLength), "from where it was last seen")
        assertSame(ends(of: drawing.segments[1]).end, drawing.realPlane?.coordinate, "to where the plan has it now")
        XCTAssertEqual(drawing.realPlane?.isEstimated, true)
        XCTAssertNotNil(drawing.ghost)
    }

    func test_now_estimated_theDottedLineIsWrittenFromThePlaneBack_soItsDotsStayPut() throws {
        // The map lays a dotted line from its last place. That must be where the plane was last seen, which doesn't
        // move, and not the plane, which does.
        let (first, leg, moment) = try drawing(of: "ahead, in the air", at: "13T12:45:00")
        let later = FlightDrawing(leg: leg, at: moment.at.addingTimeInterval(600), isReplay: false)
        let path = try XCTUnwrap(leg.flight?.path)
        XCTAssertEqual(later.realPlane?.isEstimated, true)
        for drawing in [first, later] {
            XCTAssertEqual(drawing.segments.map(\.style), [.seen, .unseen, .upcoming])
            // Without its three lines the test has failed already, and there's no dotted line to read.
            guard drawing.segments.count == 3 else { continue }
            assertSame(drawing.segments[1].coordinates.last, path.point(atDistance: path.flownLength))
            assertSame(drawing.segments[1].coordinates.first, drawing.realPlane?.coordinate)
            // And the line still to come ends at the airport.
            assertSame(drawing.segments[2].coordinates.first, drawing.realPlane?.coordinate)
            assertSame(drawing.segments[2].coordinates.last, leg.destination.coordinate)
        }
        let moved = GreatCircle.distance(from: try XCTUnwrap(first.realPlane?.coordinate), to: try XCTUnwrap(later.realPlane?.coordinate))
        XCTAssertGreaterThan(moved, 50 * GreatCircle.metersPerNauticalMile, "the plane has flown on in ten minutes")
    }

    func test_now_onTheGroundPastThePlansTakeoff_theWholePathIsAhead_andTheGhostHasLeft() throws {
        let (drawing, leg, _) = try drawing(of: "still on the ground twenty minutes after", at: "13T12:35:00")
        XCTAssertEqual(drawing.segments.map(\.style), [.upcoming])
        let fix = try XCTUnwrap(leg.flight?.live?.fix)
        assertSame(drawing.realPlane?.coordinate, fix.coordinate)
        XCTAssertEqual(drawing.realPlane?.isEstimated, false)
        let ghost = try XCTUnwrap(drawing.ghost)
        XCTAssertGreaterThan(GreatCircle.distance(from: ghost.coordinate, to: leg.origin.coordinate), 100 * GreatCircle.metersPerNauticalMile)
    }

    func test_now_landedAndNeverSeenInTheAir_theGreatCircleIsDotted_withThePlaneAtTheAirport() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "landed, and never seen in the air")
        let leg = try cases.mapLeg(flightCase, at: flightCase.moments[0])
        // Two minutes before it reaches the gate.
        let drawing = FlightDrawing(leg: leg, at: leg.end.addingTimeInterval(-120), isReplay: false)
        XCTAssertEqual(drawing.segments.map(\.style), [.unseen])
        assertSame(drawing.realPlane?.coordinate, leg.destination.coordinate)
        XCTAssertNil(drawing.ghost, "a landed flight has no ghost")
    }

    func test_now_onTheGroundSomewhereElse_showsTheRealPlaneWhereItIs_withNoGhost() throws {
        let (drawing, leg, _) = try drawing(of: "on the ground somewhere else", at: "13T13:21:00")
        let fix = try XCTUnwrap(leg.flight?.live?.fix)
        assertSame(drawing.realPlane?.coordinate, fix.coordinate)
        XCTAssertNil(drawing.ghost)
        XCTAssertNil(drawing.plane)
        XCTAssertEqual(drawing.segments.map(\.style), [.upcoming])
    }

    func test_now_aFlightThatIsntLive_drawsTheSchedulesPlane_asBefore() throws {
        for (name, time) in [("waiting to be seen", "13T12:30:00"), ("no live data", "13T12:30:00"),
                             ("on the ground before the plan's takeoff", "13T12:13:00")] {
            let (drawing, leg, moment) = try drawing(of: name, at: time)
            // The schedule's plane taxis for its first 15 minutes, with nothing flown behind it.
            let isTaxiingOut = leg.progress(at: moment.at) == 0
            XCTAssertEqual(drawing.segments.map(\.id), isTaxiingOut ? ["f1-upcoming"] : ["f1-flying", "f1-upcoming"], name)
            XCTAssertEqual(drawing.segments.map(\.style), isTaxiingOut ? [.upcoming] : [.flying, .upcoming], name)
            assertSame(drawing.plane?.coordinate, leg.position(at: moment.at), name)
            XCTAssertNil(drawing.realPlane, name)
            XCTAssertNil(drawing.ghost, name)
        }
    }

    // MARK: - Before and after

    func test_afterItReachesTheGate_isOneGreyLineAlongItsRealPath() throws {
        let (drawing, leg, moment) = try drawing(of: "landed, seen all the way", at: "13T13:30:00")
        XCTAssertGreaterThanOrEqual(moment.at, leg.end)
        XCTAssertEqual(drawing.segments.map(\.id), ["f1-flown"])
        XCTAssertEqual(drawing.segments.map(\.style), [.flown])
        XCTAssertEqual(drawing.segments[0].coordinates.count, try XCTUnwrap(leg.flight?.path.stretches.count) + 1)
        XCTAssertNil(drawing.realPlane)
        XCTAssertNil(drawing.plane)
    }

    func test_beforeItLeavesTheGate_isDashedAlongItsPath_withNoPlane() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "on the ground before the plan's takeoff")
        let leg = try cases.mapLeg(flightCase, at: flightCase.moments[0])
        // Seen on the ground at the gate, ten minutes before it's due to leave.
        let drawing = FlightDrawing(leg: leg, at: leg.start.addingTimeInterval(-600), isReplay: false)
        XCTAssertEqual(drawing.segments.map(\.id), ["f1-upcoming"])
        XCTAssertEqual(drawing.segments.map(\.style), [.upcoming])
        XCTAssertNil(drawing.realPlane, "the real plane shows from the gate to the gate")
        XCTAssertNil(drawing.ghost)
        XCTAssertNil(drawing.plane)
    }

    // MARK: - The replay

    func test_replay_aFlightWithARecord_fliesIt_alone() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let leg = try cases.mapLeg(flightCase, at: moment)
        let record = try XCTUnwrap(leg.flight?.record)
        let path = try XCTUnwrap(leg.flight?.path)
        let earlier = moment.at.addingTimeInterval(-900)

        let drawing = FlightDrawing(leg: leg, at: earlier, isReplay: true)

        assertSame(drawing.realPlane?.coordinate, record.position(at: earlier))
        XCTAssertEqual(drawing.realPlane?.isEstimated, false)
        XCTAssertNil(drawing.ghost, "the ghost is for now only")
        XCTAssertNil(drawing.plane)
        XCTAssertEqual(drawing.segments.map(\.style), [.seen, .upcoming])
        XCTAssertLessThan(drawing.segments[0].coordinates.count, path.knots.count + 1, "only as far as it had flown then")
        assertSame(drawing.segments[0].coordinates.last, drawing.realPlane?.coordinate)
        XCTAssertEqual(try XCTUnwrap(drawing.realPlane?.angle), try XCTUnwrap(path.heading(atDistance: record.distance(at: earlier))), accuracy: 1e-9)
    }

    func test_replay_beforeThePlaneWasFirstSeen_fliesTheDottedStretchFromTheAirport() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "behind, with a late first point and an unseen ocean")
        let leg = try cases.mapLeg(flightCase, at: flightCase.moments[0])
        let record = try XCTUnwrap(leg.flight?.record)
        let path = try XCTUnwrap(leg.flight?.path)
        let firstSeen = try XCTUnwrap(path.knots.first)
        // Halfway between the first place it was seen and the moment the record has it leave the airport.
        let leftAirport = record.time(atDistance: 0)
        let moment = leftAirport.addingTimeInterval(firstSeen.time.timeIntervalSince(leftAirport) / 2)
        XCTAssertTrue(leg.isMoving(at: moment))

        let drawing = FlightDrawing(leg: leg, at: moment, isReplay: true)

        XCTAssertEqual(drawing.segments.map(\.style), [.unseen, .upcoming])
        assertSame(drawing.realPlane?.coordinate, record.position(at: moment))
        XCTAssertEqual(drawing.realPlane?.isEstimated, false, "it did fly this: nobody saw it, which the dotted line says")
        assertSame(ends(of: drawing.segments[0]).start, leg.origin.coordinate)
        assertSame(ends(of: drawing.segments[0]).end, drawing.realPlane?.coordinate)
    }

    func test_replay_aheadOfWhereItWasLastSeen_isAnEstimate() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let leg = try cases.mapLeg(flightCase, at: moment)
        let later = moment.at.addingTimeInterval(1200)

        let drawing = FlightDrawing(leg: leg, at: later, isReplay: true)

        XCTAssertEqual(drawing.realPlane?.isEstimated, true)
        XCTAssertEqual(drawing.segments.map(\.style), [.seen, .unseen, .upcoming])
        XCTAssertNil(drawing.ghost)
    }

    func test_replay_aLandedFlight_isNeverAnEstimate() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "landed, seen all the way")
        let leg = try cases.mapLeg(flightCase, at: flightCase.moments[0])
        for minutes in stride(from: 1.0, to: leg.end.timeIntervalSince(leg.start) / 60, by: 7) {
            let drawing = FlightDrawing(leg: leg, at: leg.start.addingTimeInterval(minutes * 60), isReplay: true)
            XCTAssertEqual(drawing.realPlane?.isEstimated, false, "\(minutes) minutes in")
            XCTAssertFalse(drawing.segments.contains { $0.style == .unseen }, "\(minutes) minutes in")
        }
    }

    func test_replay_aFlightWithNoRecord_drawsTheSchedulesPlane() throws {
        for name in ["no live data", "still on the ground twenty minutes after"] {
            let cases = try TripMapFixtures.liveCases()
            let flightCase = try cases.flight(named: name)
            let leg = try cases.mapLeg(flightCase, at: flightCase.moments[0])
            let drawing = FlightDrawing(leg: leg, at: leg.start.addingTimeInterval(1800), isReplay: true)
            XCTAssertNotNil(drawing.plane, name)
            XCTAssertNil(drawing.realPlane, name)
            XCTAssertEqual(drawing.segments.map(\.style), [.flying, .upcoming], name)
        }
    }

    // MARK: - A leg made by hand

    func test_aLegWithNoFlight_drawsTheSchedulesPlane() {
        let leg = MapLeg(id: "f", kind: .flight,
                         origin: AirportMark(code: "SDF", city: nil, coordinate: TripMapTestLegs.airports["SDF"]!, timeZone: nil),
                         destination: AirportMark(code: "CGN", city: nil, coordinate: TripMapTestLegs.airports["CGN"]!, timeZone: nil),
                         start: TripMapTestLegs.tripStart, end: TripMapTestLegs.tripStart.addingTimeInterval(8 * 3600), flightNumber: nil)
        let drawing = FlightDrawing(leg: leg, at: TripMapTestLegs.tripStart.addingTimeInterval(4 * 3600), isReplay: false)
        XCTAssertEqual(drawing.segments.map(\.style), [.flying, .upcoming])
        XCTAssertNotNil(drawing.plane)
    }
}
