//
//  TripMapTests.swift
//  CrewluvTests
//
//  The trip map's model (moving map spec §5.1, §7.1, §12): which legs it draws, its mode, and where the pilot is.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class TripMapTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { start.addingTimeInterval(value * 3600) }

    func test_make_duringTheFirstFlight_isInFlightOnIt() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(4)))
        XCTAssertEqual(map.mode, .inFlight(legID: "f1"))
        XCTAssertEqual(map.currentLeg?.id, "f1")
        XCTAssertEqual(map.legs.map(\.id), ["f1", "f2", "f3"], "layovers aren't drawn")
    }

    func test_make_onTheLayover_isOnTripWithThePilotInCologne() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        XCTAssertEqual(map.mode, .onTrip)
        XCTAssertNil(map.currentLeg)
        let place = try XCTUnwrap(map.pilotLocation(at: hours(12)))
        XCTAssertEqual(place.code, "CGN")
        XCTAssertEqual(place.city, "Cologne")
        XCTAssertEqual(place.timeZone?.identifier, "Europe/Berlin")
    }

    func test_make_nextTrip_putsThePilotAtHomeUntilItStarts() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), isNextTrip: true, at: hours(-48)))
        XCTAssertEqual(map.mode, .nextTrip)
        XCTAssertEqual(map.pilotLocation(at: hours(-48))?.code, "SDF")
        XCTAssertNil(map.pilotLocation(at: hours(4)), "replaying it, the plane shows instead")
    }

    func test_make_unknownAirport_leavesThatLegOut() throws {
        var legs = TripMapTestLegs.europeTrip()
        legs[2] = TripMapTestLegs.leg("f2", from: "CGN", to: "ZZZ", start: hours(32), hours: 6)
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(12)))
        XCTAssertEqual(map.legs.map(\.id), ["f1", "f3"])
    }

    func test_make_nothingDrawable_isNil() {
        let legs = [TripMapTestLegs.leg("x", from: "ZZZ", to: "YYY", start: hours(0), hours: 2)]
        XCTAssertNil(TripMapTestLegs.map(legs, at: hours(1)))
        XCTAssertNil(TripMapTestLegs.map([], at: hours(1)))
    }

    func test_make_legDelay_movesThatLeg() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(firstDelayMinutes: 45), at: hours(4)))
        let first = try XCTUnwrap(map.legs.first)
        XCTAssertEqual(first.start, hours(0.75))
        XCTAssertEqual(first.end, hours(8.75))
        XCTAssertEqual(map.legs[1].start, hours(32), "other legs keep their times")
    }

    func test_make_legacyDelay_movesOnlyTheFlightItCovers() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), legacyDelayMinutes: 60, at: hours(8.5)))
        XCTAssertEqual(map.mode, .inFlight(legID: "f1"), "an hour late, the first flight is still in the air")
        XCTAssertEqual(map.legs[0].end, hours(9))
        XCTAssertEqual(map.legs[1].start, hours(32))
    }

    func test_make_legacyDelay_isIgnoredWhenAnyLegCarriesItsOwn() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(firstDelayMinutes: 30), legacyDelayMinutes: 120, at: hours(4)))
        XCTAssertEqual(map.legs[0].end, hours(8.5))
    }

    func test_make_arrivalTimeZone_fallsBackToTheNextGroundLeg() throws {
        var legs = TripMapTestLegs.europeTrip()
        legs[0] = TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(0), hours: 8, arrivalCity: "Cologne")
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(4)))
        XCTAssertEqual(map.legs[0].destination.timeZone?.identifier, "Europe/Berlin")
    }

    func test_make_drive_isADriveLeg() throws {
        let legs = [TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(0), hours: 1.5)]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(0.5)))
        XCTAssertEqual(map.legs.first?.kind, .drive)
        XCTAssertEqual(map.mode, .onTrip, "only a flight makes the map in flight")
    }

    func test_span_runsFromTheFirstDepartureToTheLastArrival() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        XCTAssertEqual(map.span.start, hours(0))
        XCTAssertEqual(map.span.end, hours(72))
    }

    func test_legInMotion_onlyBetweenGateTimes() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        XCTAssertEqual(map.legInMotion(at: hours(35))?.id, "f2")
        XCTAssertNil(map.legInMotion(at: hours(40)))
    }

    func test_nextFlight_afterTheLayoverStarts_isCologneToDubai() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        XCTAssertEqual(map.nextFlight(after: hours(12))?.id, "f2")
        XCTAssertNil(map.nextFlight(after: hours(70)))
    }

    func test_framingCoordinates_aLeg_holdsOnlyThatLegsArc() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(4)))
        XCTAssertEqual(map.framingCoordinates(focusingOn: map.currentLeg).count, 33)
        XCTAssertEqual(map.framingCoordinates(focusingOn: nil).count, 3 * 33 + 1, "every leg, and home")
    }

    func test_mapLeg_positionAndHeading_followTheSchedule() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(4)))
        let leg = try XCTUnwrap(map.currentLeg)
        let fraction = leg.progress(at: hours(4))
        XCTAssertEqual(fraction, FlightProgress.scheduledFraction(departure: hours(0), arrival: hours(8), at: hours(4)), accuracy: 1e-12)
        let expected = GreatCircle.point(from: leg.origin.coordinate, to: leg.destination.coordinate, fraction: fraction)
        XCTAssertEqual(leg.position(at: hours(4)).latitude, expected.latitude, accuracy: 1e-9)
        let heading = try XCTUnwrap(leg.heading(at: hours(4)))
        XCTAssertLessThan(abs(heading), .pi / 2, "Louisville to Cologne heads east")
    }

    func test_span_withAnEarlyLegLaterInTheList_startsAtTheEarliestLeg() throws {
        let legs = [
            TripMapTestLegs.leg("a", from: "SDF", to: "CGN", start: hours(0), hours: 8),
            TripMapTestLegs.leg("b", from: "CGN", to: "DXB", start: hours(1), hours: 6, delayMinutes: -120),
        ]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(-10)))
        XCTAssertEqual(map.span.start, hours(-1))
    }
}
