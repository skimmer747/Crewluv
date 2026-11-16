//
//  PlanePositionTests.swift
//  CrewluvTests
//
//  Where the facts have a flight's plane (Stage 3 spec §8): wherever the map draws it, for every moment of the
//  shared cases in Fixtures/TripMap/live-cases.json, and where the record has it in a replay.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class PlanePositionTests: XCTestCase {

    private let nauticalMile = TripMapFixtures.nauticalMile

    private func assertSame(_ place: CLLocationCoordinate2D?, _ expected: CLLocationCoordinate2D?, _ name: String,
                            accuracy: Double = 1e-9, file: StaticString = #filePath, line: UInt = #line) {
        guard let place, let expected else {
            XCTFail("a place is missing: \(name)", file: file, line: line)
            return
        }
        XCTAssertEqual(place.latitude, expected.latitude, accuracy: accuracy, name, file: file, line: line)
        XCTAssertEqual(place.longitude, expected.longitude, accuracy: accuracy, name, file: file, line: line)
    }

    // MARK: - Now

    func test_now_everySharedMoment_isWhereTheMapDrawsThePlane() throws {
        let cases = try TripMapFixtures.liveCases()
        var real = 0
        var scheduled = 0
        for flightCase in cases.flights {
            for moment in flightCase.moments {
                let name = "\(flightCase.name) at \(moment.at)"
                let leg = try cases.mapLeg(flightCase, at: moment)
                guard leg.isMoving(at: moment.at) else { continue }
                let drawing = FlightDrawing(leg: leg, at: moment.at, isReplay: false)
                let plane = leg.plane(at: moment.at, isReplay: false)
                if let drawn = drawing.realPlane {
                    assertSame(plane.coordinate, drawn.coordinate, name)
                    XCTAssertEqual(plane.isEstimated, drawn.isEstimated, name)
                    XCTAssertEqual(plane.isEstimated, moment.phase == "estimated", name)
                    XCTAssertEqual(plane.isSeenInAir, moment.phase == "inAir", name)
                    // A plane on the ground somewhere else isn't on the path: it counts as far as it was last seen.
                    XCTAssertEqual(plane.distance / nauticalMile, moment.planeAlongNm ?? flightCase.path.flownNm, accuracy: 0.01, name)
                    real += 1
                } else {
                    assertSame(plane.coordinate, drawing.plane?.coordinate, name)
                    XCTAssertEqual(plane.distance, leg.progress(at: moment.at) * leg.pathLength, accuracy: 0.001, name)
                    XCTAssertFalse(plane.isEstimated, name)
                    XCTAssertFalse(plane.isSeenInAir, name)
                    scheduled += 1
                }
            }
        }
        XCTAssertGreaterThan(real, 20, "the cases' real planes")
        XCTAssertGreaterThan(scheduled, 2, "and the moments with the schedule's plane alone")
    }

    func test_now_anEstimatedPlane_saysHowLongAgoItWasSeen_byCrewluCloudsClock() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let seenAt = try XCTUnwrap(flightCase.flight?.fix?.seenAt)

        let estimated = try cases.moment("13T12:45:00", of: flightCase)
        let plane = try cases.mapFlight(flightCase).plane(at: estimated.at, isReplay: false)
        XCTAssertEqual(try XCTUnwrap(plane?.unseenFor), estimated.at.timeIntervalSince(seenAt), accuracy: 0.001)

        // This phone's clock is ten minutes slow: by Crewlu Cloud's the plane was last seen ten minutes longer ago.
        let inAir = try cases.moment("13T12:41:50", of: flightCase)
        let slow = try cases.mapFlight(flightCase, clockOffset: 600).plane(at: inAir.at, isReplay: false)
        XCTAssertEqual(try XCTUnwrap(slow?.unseenFor), inAir.at.timeIntervalSince(seenAt) + 600, accuracy: 0.001)
        XCTAssertEqual(slow?.isSeenInAir, false)
    }

    func test_now_aPlaneSeenInTheAir_isNoEstimate() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let plane = try XCTUnwrap(try cases.mapFlight(flightCase).plane(at: moment.at, isReplay: false))
        XCTAssertNil(plane.unseenFor)
        XCTAssertTrue(plane.isSeenInAir)
    }

    func test_now_onTheGroundSomewhereElse_countsAsFarAsItWasLastSeenFlying() throws {
        // It was seen flying as far as 6.75° E, and came down at a field off its path.
        let flown = FactsTestData.equatorLive(seenUntil: FactsTestData.date("2026-03-20T11:09:00Z"))
        let down = FactsTestData.date("2026-03-20T11:30:00Z")
        let fix = LiveFlight.Fix(latitude: 1.5, longitude: 7, altitudeFeet: nil, groundSpeedKnots: 0, trackDegrees: nil,
                                 isOnGround: true, registration: nil, typeCode: nil, seenAt: down)
        let live = LiveFlight(legID: "eq", callsign: "TST1", state: .ground, fix: fix, landedAt: nil, trail: flown.trail)
        let leg = try FactsTestData.equatorLiveLeg(live, at: down)

        let plane = leg.plane(at: down, isReplay: false)
        assertSame(plane.coordinate, fix.coordinate, "where it is")
        XCTAssertEqual(plane.distance, leg.path.flownLength, accuracy: 0.001)
        XCTAssertEqual(plane.distance, 6.75 * FactsTestData.metersADegree, accuracy: 1_000)
        XCTAssertFalse(plane.isEstimated)
        XCTAssertFalse(plane.isSeenInAir)
    }

    func test_now_aFlightThatIsntLive_withARealPath_isTheSchedulesPlane_thatShareOfTheWayAlongIt() throws {
        // It flew north of the great circle as far as 8° E, went back, and has sat at the gate unseen for ten minutes.
        let flown = FactsTestData.equatorLive(seenUntil: FactsTestData.liveTime(atLongitude: 8), latitude: FactsTestData.dogLeg)
        let now = FactsTestData.date("2026-03-20T12:00:00Z")
        let fix = LiveFlight.Fix(latitude: 0, longitude: 0, altitudeFeet: nil, groundSpeedKnots: 0, trackDegrees: nil,
                                 isOnGround: true, registration: nil, typeCode: nil, seenAt: now.addingTimeInterval(-600))
        let live = LiveFlight(legID: "eq", callsign: "TST1", state: .ground, fix: fix, landedAt: nil, trail: flown.trail)
        let leg = try FactsTestData.equatorLiveLeg(live, at: now)
        XCTAssertNil(leg.flight?.plane(at: now, isReplay: false), "no real plane shows")
        XCTAssertGreaterThan(leg.pathLength, leg.distance)

        let plane = leg.plane(at: now, isReplay: false)
        assertSame(plane.coordinate, FlightDrawing(leg: leg, at: now, isReplay: false).plane?.coordinate, "where the map draws the schedule's plane")
        XCTAssertEqual(plane.distance, leg.progress(at: now) * leg.pathLength, accuracy: 0.001)
        XCTAssertFalse(plane.isEstimated)
    }

    // MARK: - A replay

    func test_replay_everyPlaceOfTheSharedRecords_isWhereTheRecordHasIt() throws {
        let cases = try TripMapFixtures.liveCases()
        var checked = 0
        for flightCase in cases.flights {
            guard let record = flightCase.record else { continue }
            let flight = try cases.mapFlight(flightCase)
            for place in record.places {
                let name = "\(flightCase.name) at \(place.at)"
                let plane = try XCTUnwrap(flight.plane(at: place.at, isReplay: true), name)
                XCTAssertEqual(plane.distance / nauticalMile, place.alongNm, accuracy: 0.01, name)
                assertSame(plane.coordinate, CLLocationCoordinate2D(latitude: place.point[0], longitude: place.point[1]), name, accuracy: 0.0001)
                XCTAssertFalse(plane.isSeenInAir, "its height and speed are for now only: \(name)")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 20, "the cases' places")
    }

    func test_replay_pastWhereItWasLastSeen_isAnEstimate_andSaysForHowLong() throws {
        let cases = try TripMapFixtures.liveCases()
        let flight = try cases.mapFlight(try cases.flight(named: "ahead, in the air"))
        let lastSeen = try XCTUnwrap(flight.path.knots.last).time

        let before = try XCTUnwrap(flight.plane(at: lastSeen.addingTimeInterval(-300), isReplay: true))
        XCTAssertNil(before.unseenFor, "where it was seen, the replay shows it as it was")

        let after = try XCTUnwrap(flight.plane(at: lastSeen.addingTimeInterval(1200), isReplay: true))
        XCTAssertEqual(try XCTUnwrap(after.unseenFor), 1200, accuracy: 0.001)
        XCTAssertGreaterThan(after.distance, flight.path.flownLength)
    }

    func test_replay_aFlightThatLanded_isNeverAnEstimate() throws {
        let cases = try TripMapFixtures.liveCases()
        let flight = try cases.mapFlight(try cases.flight(named: "landed, seen all the way"))
        let touchdown = try XCTUnwrap(flight.record).touchdown
        let plane = try XCTUnwrap(flight.plane(at: touchdown.addingTimeInterval(3600), isReplay: true))
        XCTAssertNil(plane.unseenFor)
        XCTAssertEqual(plane.distance, flight.path.length, accuracy: 0.001)
    }

    func test_replay_withNoRecord_isTheSchedulesPlane() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "no live data")
        XCTAssertNil(try cases.mapFlight(flightCase).plane(at: flightCase.departure.addingTimeInterval(3600), isReplay: true))

        let leg = try cases.mapLeg(flightCase, at: try XCTUnwrap(flightCase.moments.first))
        let at = flightCase.departure.addingTimeInterval(3600)
        let plane = leg.plane(at: at, isReplay: true)
        XCTAssertEqual(plane.distance, leg.progress(at: at) * leg.distance, accuracy: 0.001)
        assertSame(plane.coordinate, leg.position(at: at), "the schedule's plane")
    }

    // MARK: - A leg made by hand

    func test_aLegWithNoFlight_isTheSchedulesPlane() {
        let leg = FactsTestData.equatorFlight(from: 0, to: 20)
        let at = FactsTestData.date("2026-03-20T11:45:00Z")
        let plane = leg.plane(at: at, isReplay: false)
        XCTAssertEqual(plane.distance, leg.distance / 2, accuracy: 0.001, "halfway through its time in the air")
        assertSame(plane.coordinate, CLLocationCoordinate2D(latitude: 0, longitude: 10), "10° E", accuracy: 1e-6)
    }
}
