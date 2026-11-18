//
//  LiveSkyFactsTests.swift
//  CrewluvTests
//
//  The sky from the cockpit of a real plane (Stage 3 spec §8): its sunrises and sunsets along the path it really
//  flew, at the times it was really there, seen from the height it's really at.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LiveSkyFactsTests: XCTestCase {

    private func flight(departing iso: String, hours: Double = 8) -> MapLeg {
        let start = FactsTestData.date(iso)
        return MapLeg(id: "SDFCGN", kind: .flight,
                      origin: AirportMark(code: "SDF", city: nil, coordinate: TripMapTestLegs.airports["SDF"]!, timeZone: nil),
                      destination: AirportMark(code: "CGN", city: nil, coordinate: TripMapTestLegs.airports["CGN"]!, timeZone: nil),
                      start: start, end: start.addingTimeInterval(hours * 3600), flightNumber: nil)
    }

    /// The flight to Cologne, scheduled out at 18:00 UTC unless the test says, with a real plane that flies as the
    /// schedule has it but `late` seconds behind: seen every 2 minutes for its first five hours in the air.
    private func liveFlight(late: TimeInterval, altitudeFeet: Double = 35_000, state: LiveFlight.State = .airborne,
                            departing iso: String = "2026-11-13T18:00:00Z") throws -> MapLeg {
        let scheduled = flight(departing: iso)
        let asFlown = flight(departing: iso).delayed(by: late)
        let takeoff = try XCTUnwrap(asFlown.airborne).start
        let seenUntil = takeoff.addingTimeInterval(5 * 3600)
        var trail: [LiveFlight.TrailPoint] = []
        var time = takeoff.addingTimeInterval(120)
        while time <= seenUntil {
            let here = asFlown.position(at: time)
            trail.append(LiveFlight.TrailPoint(time: time, latitude: here.latitude, longitude: here.longitude, altitudeFeet: altitudeFeet))
            time = time.addingTimeInterval(120)
        }
        let last = try XCTUnwrap(trail.last)
        let fix = LiveFlight.Fix(latitude: last.latitude, longitude: last.longitude, altitudeFeet: altitudeFeet, groundSpeedKnots: 480,
                                 trackDegrees: 60, isOnGround: false, registration: "N370UP", typeCode: "B763", seenAt: last.time)
        let live = LiveFlight(legID: scheduled.id, callsign: "UPS207", state: state, fix: fix, landedAt: nil, trail: trail)
        let mapFlight = try XCTUnwrap(MapFlight(departure: scheduled.start, arrival: scheduled.end, from: scheduled.origin.coordinate,
                                                to: scheduled.destination.coordinate, live: live))
        let progress = mapFlight.progress(at: last.time)
        return MapLeg(id: scheduled.id, kind: .flight, origin: scheduled.origin, destination: scheduled.destination,
                      start: progress.start, end: progress.end, flightNumber: nil, flight: mapFlight)
    }

    // MARK: - The height it's seen from

    func test_cockpitHorizon_isFromTheRealPlanesHeight_whileItsAtItsCruise() throws {
        let high = try liveFlight(late: 0, altitudeFeet: 38_000)
        XCTAssertEqual(SkyFacts.cockpitHorizon(for: high), SkyFacts.groundHorizon - SkyFacts.horizonDip(feet: 38_000), accuracy: 1e-9)
        XCTAssertLessThan(SkyFacts.cockpitHorizon(for: high), SkyFacts.cockpitHorizon, "higher up, the horizon is lower")
    }

    func test_cockpitHorizon_isFrom35000Feet_whileItClimbsOrComesDown() throws {
        XCTAssertEqual(SkyFacts.cockpitHorizon(for: try liveFlight(late: 0, altitudeFeet: 8_000)), SkyFacts.cockpitHorizon)
        XCTAssertEqual(SkyFacts.cockpitHorizon(for: try liveFlight(late: 0, altitudeFeet: 24_999)), SkyFacts.cockpitHorizon)
        XCTAssertNotEqual(SkyFacts.cockpitHorizon(for: try liveFlight(late: 0, altitudeFeet: 25_000)), SkyFacts.cockpitHorizon)
        XCTAssertNotEqual(SkyFacts.cockpitHorizon(for: try liveFlight(late: 0, altitudeFeet: 60_000)), SkyFacts.cockpitHorizon)
        XCTAssertEqual(SkyFacts.cockpitHorizon(for: try liveFlight(late: 0, altitudeFeet: 60_001)), SkyFacts.cockpitHorizon)
    }

    func test_cockpitHorizon_isFrom35000Feet_withNoPlaneInTheAir_orAHeightThatCantBeRight() throws {
        XCTAssertEqual(SkyFacts.cockpitHorizon(for: flight(departing: "2026-11-13T18:00:00Z")), SkyFacts.cockpitHorizon, "no live data")
        XCTAssertEqual(SkyFacts.cockpitHorizon(for: try liveFlight(late: 0, altitudeFeet: 38_000, state: .landed)), SkyFacts.cockpitHorizon, "it's down")
        XCTAssertEqual(SkyFacts.cockpitHorizon(for: try liveFlight(late: 0, altitudeFeet: 1e12)), SkyFacts.cockpitHorizon)
        XCTAssertEqual(SkyFacts.cockpitHorizon(for: try liveFlight(late: 0, altitudeFeet: .nan)), SkyFacts.cockpitHorizon)
    }

    // MARK: - Sunrise and sunset along the record

    func test_sunEvents_alongARecord_areWhereAndWhenTheRealPlaneWas() throws {
        // The real plane is 40 minutes behind the schedule. Its sunset is the one a flight scheduled 40 minutes
        // later would see, not the schedule's.
        let scheduled = try XCTUnwrap(SkyFacts.sunEvents(on: flight(departing: "2026-11-13T18:00:00Z")).first)
        let delayed = try XCTUnwrap(SkyFacts.sunEvents(on: flight(departing: "2026-11-13T18:40:00Z")).first)
        let events = SkyFacts.sunEvents(on: try liveFlight(late: 40 * 60))
        let real = try XCTUnwrap(events.first)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(real.kind, .sunset)
        XCTAssertEqual(real.time.timeIntervalSince1970, delayed.time.timeIntervalSince1970, accuracy: 60)
        XCTAssertGreaterThan(abs(real.time.timeIntervalSince(scheduled.time)), 5 * 60, "the schedule's sunset is minutes off")
        XCTAssertEqual(try XCTUnwrap(real.peopleBelowGap), try XCTUnwrap(delayed.peopleBelowGap), accuracy: 60)
    }

    func test_airborne_ofAPlaneThatLeftLate_beginsWhenItReallyLeft() throws {
        // The schedule has it off the ground at 18:15. It left 40 minutes after that.
        let airborne = try XCTUnwrap(try liveFlight(late: 40 * 60).airborne)
        XCTAssertEqual(airborne.start.timeIntervalSince1970, FactsTestData.date("2026-11-13T18:55:00Z").timeIntervalSince1970, accuracy: 120)
    }

    func test_sunEvents_ofAPlaneThatLeftAfterDark_haveNoSunset_thoughTheScheduleHadItOffBefore() throws {
        // The schedule has it off at 22:35 UTC, minutes after sunset in Louisville, with the sun still above the
        // cockpit's horizon at cruise: its plane sees a sunset. The real plane left 40 minutes later, in the dark.
        let scheduled = SkyFacts.sunEvents(on: flight(departing: "2026-11-13T22:20:00Z"))
        XCTAssertEqual(scheduled.first?.kind, .sunset)
        let real = SkyFacts.sunEvents(on: try liveFlight(late: 40 * 60, departing: "2026-11-13T22:20:00Z"))
        XCTAssertFalse(real.contains { $0.kind == .sunset }, "\(real)")
    }

    func test_sunEvents_seenFromHigherUp_setLater() throws {
        let lower = try XCTUnwrap(SkyFacts.sunEvents(on: try liveFlight(late: 0, altitudeFeet: 30_000)).first)
        let higher = try XCTUnwrap(SkyFacts.sunEvents(on: try liveFlight(late: 0, altitudeFeet: 41_000)).first)
        XCTAssertGreaterThan(higher.time, lower.time)
        XCTAssertLessThan(higher.time.timeIntervalSince(lower.time), 5 * 60, "by a minute or two")
    }

    func test_sunEvents_withNoLiveData_areTheSchedules_asBefore() throws {
        let scheduled = flight(departing: "2026-11-13T18:00:00Z")
        let withNoAnswer = MapLeg(id: scheduled.id, kind: .flight, origin: scheduled.origin, destination: scheduled.destination,
                                  start: scheduled.start, end: scheduled.end, flightNumber: nil,
                                  flight: MapFlight(departure: scheduled.start, arrival: scheduled.end, from: scheduled.origin.coordinate,
                                                    to: scheduled.destination.coordinate))
        XCTAssertEqual(SkyFacts.sunEvents(on: withNoAnswer), SkyFacts.sunEvents(on: scheduled))
    }

    func test_sunAltitude_isAtTheRecordsPlace() throws {
        let leg = try liveFlight(late: 40 * 60)
        let at = FactsTestData.date("2026-11-13T21:00:00Z")
        let here = try XCTUnwrap(leg.flight?.record).position(at: at)
        XCTAssertEqual(SkyFacts.sunAltitude(on: leg, at: at), SolarPosition.altitude(latitude: here.latitude, longitude: here.longitude, at: at))
    }
}

private extension MapLeg {
    /// The same leg, `seconds` later.
    func delayed(by seconds: TimeInterval) -> MapLeg {
        MapLeg(id: id, kind: kind, origin: origin, destination: destination, start: start.addingTimeInterval(seconds),
               end: end.addingTimeInterval(seconds), flightNumber: flightNumber)
    }
}
