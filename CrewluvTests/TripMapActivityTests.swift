//
//  TripMapActivityTests.swift
//  CrewluvTests
//
//  What the pilot is doing at any moment of the trip map (activity markers design §2.2): the waits between moving
//  legs, named by CrewLu's ground legs, and the activity before, during and after the trip. Held to the shared cases in
//  Fixtures/TripMap/activity-cases.json.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class TripMapActivityTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { start.addingTimeInterval(value * 3600) }

    /// Louisville to Cologne, a day there, Dubai, 20 hours there, and home, with CrewLu's two layovers.
    private func europe(isNextTrip: Bool = false) throws -> TripMap {
        try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), isNextTrip: isNextTrip, at: hours(12)))
    }

    // MARK: - CrewLu's ground legs

    func test_make_keepsCrewLusGroundLegs_butDoesntDrawThem() throws {
        let map = try europe()
        XCTAssertEqual(map.groundStops.map(\.kind), [.layover, .layover])
        XCTAssertEqual(map.groundStops.first?.start, hours(8))
        XCTAssertEqual(map.legs.map(\.id), ["f1", "f2", "f3"])
    }

    func test_make_reserveAndEventLegs_arentKept() throws {
        let legs = TripMapTestLegs.europeTrip() + [
            TripMapTestLegs.leg("r1", .reserve, start: hours(80), hours: 12),
            TripMapTestLegs.leg("e1", .event, start: hours(100), hours: 2),
        ]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(12)))
        XCTAssertEqual(map.groundStops.map(\.kind), [.layover, .layover])
    }

    // MARK: - The waits

    func test_waits_europeTrip_areItsTwoLayovers() throws {
        XCTAssertEqual(try europe().waits, [TripWait(start: hours(8), end: hours(32), kind: .layover),
                                            TripWait(start: hours(38), end: hours(58), kind: .layover)])
    }

    func test_waits_noGroundLeg_eightHoursIsALayover_andLessIsATurn() throws {
        let legs = [
            TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(0), hours: 8),
            TripMapTestLegs.leg("f2", from: "CGN", to: "DXB", start: hours(16), hours: 6),
            TripMapTestLegs.leg("f3", from: "DXB", to: "SDF", start: hours(29.9), hours: 14),
        ]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(12)))
        XCTAssertEqual(map.waits.map(\.kind), [.layover, .turn], "8 h in Cologne, 7 h 54 min in Dubai")
    }

    func test_waits_aDelay_namesEachWaitByTheGroundLegItOverlapsMost() throws {
        // f2 leaves 90 minutes late, at 10.5 h. Cologne's wait, 8 h to 10.5 h, overlaps CrewLu's turn for an hour and
        // its layover not at all. Dubai's, 16.5 h to 35 h, overlaps the layover, which began at f2's scheduled arrival.
        let legs = [
            TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(0), hours: 8),
            TripMapTestLegs.leg("t1", .turn, start: hours(8), hours: 1),
            TripMapTestLegs.leg("f2", from: "CGN", to: "DXB", start: hours(9), hours: 6, delayMinutes: 90),
            TripMapTestLegs.leg("l1", .layover, start: hours(15), hours: 20),
            TripMapTestLegs.leg("f3", from: "DXB", to: "SDF", start: hours(35), hours: 14),
        ]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(12)))
        XCTAssertEqual(map.waits, [TripWait(start: hours(8), end: hours(10.5), kind: .turn),
                                   TripWait(start: hours(16.5), end: hours(35), kind: .layover)])
    }

    func test_waits_twoGroundLegsTied_theEarlierNamesIt() throws {
        let legs = [
            TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(0), hours: 8),
            TripMapTestLegs.leg("t1", .turn, start: hours(8), hours: 4),
            TripMapTestLegs.leg("l1", .layover, start: hours(12), hours: 4),
            TripMapTestLegs.leg("f2", from: "CGN", to: "SDF", start: hours(16), hours: 9),
        ]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(12)))
        XCTAssertEqual(map.waits.map(\.kind), [.turn], "4 hours each: the earlier names the whole wait")
    }

    // MARK: - What the pilot is doing

    func test_activity_inFlight_isFlyingToTheDestination() throws {
        let activity = try XCTUnwrap(try europe().activity(at: hours(4)))
        XCTAssertEqual(activity.kind, .flying)
        XCTAssertEqual(activity.words, "Flying to Cologne")
    }

    func test_activity_onTheLayover_isALayoverInCologne() throws {
        let activity = try XCTUnwrap(try europe().activity(at: hours(12)))
        XCTAssertEqual(activity.kind, .layover)
        XCTAssertEqual(activity.place.code, "CGN")
        XCTAssertEqual(activity.words, "Layover in Cologne")
    }

    func test_activity_beforeANextTrip_isHome() throws {
        let activity = try XCTUnwrap(try europe(isNextTrip: true).activity(at: hours(-48)))
        XCTAssertEqual(activity.kind, .home)
        XCTAssertEqual(activity.place.code, "SDF")
    }

    func test_activity_beforeATripFromBase_isAtBase() throws {
        let map = try XCTUnwrap(TripMap.make(tripLegs: TripMapTestLegs.europeTrip(), isNextTrip: false, homeAirportCode: "LEX",
                                             legacyDelayMinutes: nil, at: hours(-2), coordinate: TripMapTestLegs.coordinate))
        XCTAssertEqual(map.activity(at: hours(-2))?.kind, .base)
        XCTAssertEqual(map.activity(at: hours(-2))?.words, "At base in Louisville")
    }

    func test_activity_afterARecap_isHome_whereverTheTripEnded() throws {
        let legs = [TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(0), hours: 8)]
        let map = try XCTUnwrap(TripMap.make(tripLegs: legs, isNextTrip: false, isRecap: true, homeAirportCode: "SDF",
                                             legacyDelayMinutes: nil, at: hours(10), coordinate: TripMapTestLegs.coordinate))
        XCTAssertEqual(map.activity(at: hours(10))?.kind, .home)
        XCTAssertEqual(map.activity(at: hours(10))?.place.code, "SDF")
    }

    func test_activity_aFlightOverlappingADrive_isFlying() throws {
        let legs = [
            TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(0), hours: 1.5),
            TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(1), hours: 8),
        ]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(1.25)))
        XCTAssertEqual(map.activity(at: hours(0.5))?.kind, .driving)
        XCTAssertEqual(map.activity(at: hours(1.25))?.kind, .flying)
    }

    // MARK: - The shared cases

    // MARK: - Waits CrewLu doesn't name (base waits design §2, §3)

    /// A commuter, home at Lexington and based at Louisville, with no ground legs at all: the drive in the night before,
    /// 12 h 30 at base, Cologne and back with 2 hours there, an hour at base, and the drive home.
    private func commuter(baseAirportCode: String? = "SDF") throws -> TripMap {
        let legs = [
            TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(-14), hours: 1.5),
            TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(0), hours: 8),
            TripMapTestLegs.leg("f2", from: "CGN", to: "SDF", start: hours(10), hours: 9),
            TripMapTestLegs.leg("d2", .drive, from: "SDF", to: "LEX", start: hours(20), hours: 1.5),
        ]
        return try XCTUnwrap(TripMap.make(tripLegs: legs, isNextTrip: false, homeAirportCode: "LEX",
                                          baseAirportCode: baseAirportCode, legacyDelayMinutes: nil, at: hours(-20),
                                          coordinate: TripMapTestLegs.coordinate))
    }

    func test_waits_noGroundLegAtBase_isBase_evenFor8HoursOrMore() throws {
        let map = try commuter()
        XCTAssertEqual(map.waits.map(\.kind), [.base, .turn, .base])
        let first = try XCTUnwrap(map.waits.first)
        XCTAssertEqual(first.end.timeIntervalSince(first.start), 12.5 * 3600)
        XCTAssertEqual(map.activity(at: hours(-6))?.kind, .base)
        XCTAssertEqual(map.activity(at: hours(-6))?.place.code, "SDF")
    }

    func test_waits_noGroundLegAtBase_withNoBaseKnown_isByItsLength() throws {
        let map = try commuter(baseAirportCode: nil)
        XCTAssertEqual(map.waits.map(\.kind), [.layover, .turn, .turn])
    }

    func test_waits_noGroundLegAtHome_isHome() throws {
        let legs = [
            TripMapTestLegs.leg("f1", from: "SDF", to: "LEX", start: hours(0), hours: 1),
            TripMapTestLegs.leg("f2", from: "LEX", to: "CGN", start: hours(12), hours: 8),
        ]
        let map = try XCTUnwrap(TripMap.make(tripLegs: legs, isNextTrip: false, homeAirportCode: "LEX",
                                             baseAirportCode: "SDF", legacyDelayMinutes: nil, at: hours(-1),
                                             coordinate: TripMapTestLegs.coordinate))
        XCTAssertEqual(map.waits.map(\.kind), [.home])
    }

    func test_waits_crewLusGroundLegAtBase_stillNamesIt() throws {
        let legs = [
            TripMapTestLegs.leg("f1", from: "CGN", to: "SDF", start: hours(0), hours: 9),
            TripMapTestLegs.leg("t1", .turn, start: hours(9), hours: 1),
            TripMapTestLegs.leg("f2", from: "SDF", to: "DXB", start: hours(10), hours: 13),
        ]
        let map = try XCTUnwrap(TripMap.make(tripLegs: legs, isNextTrip: false, homeAirportCode: "LEX",
                                             baseAirportCode: "SDF", legacyDelayMinutes: nil, at: hours(-1),
                                             coordinate: TripMapTestLegs.coordinate))
        XCTAssertEqual(map.waits.map(\.kind), [.turn])
    }

    func test_activity_beforeATripAheadWhileWaitingAtBase_isAtBase() throws {
        let map = try XCTUnwrap(TripMap.make(tripLegs: TripMapTestLegs.europeTrip(), isNextTrip: true,
                                             homeAirportCode: "LEX", baseAirportCode: "SDF", isWaitingAtBase: true,
                                             legacyDelayMinutes: nil, at: hours(-3), coordinate: TripMapTestLegs.coordinate))
        let activity = try XCTUnwrap(map.activity(at: hours(-3)))
        XCTAssertEqual(activity.kind, .base)
        XCTAssertEqual(activity.place.code, "SDF")
        XCTAssertEqual(activity.words, "At base in Louisville", "base as the trip's legs name it, with its city")
    }

    func test_activity_beforeATripAheadAtHome_isStillHome() throws {
        let map = try XCTUnwrap(TripMap.make(tripLegs: TripMapTestLegs.europeTrip(), isNextTrip: true,
                                             homeAirportCode: "LEX", baseAirportCode: "SDF", legacyDelayMinutes: nil,
                                             at: hours(-3), coordinate: TripMapTestLegs.coordinate))
        XCTAssertEqual(map.activity(at: hours(-3))?.kind, .home)
        XCTAssertEqual(map.pilotLocation(at: hours(-3))?.code, "LEX")
    }

    func test_make_base_isTheLegsOwnMark_andIsWaitedAtOnlyForATripAhead() throws {
        let underWay = try XCTUnwrap(TripMap.make(tripLegs: TripMapTestLegs.europeTrip(), isNextTrip: false,
                                                  homeAirportCode: "LEX", baseAirportCode: "SDF", isWaitingAtBase: true,
                                                  legacyDelayMinutes: nil, at: hours(12), coordinate: TripMapTestLegs.coordinate))
        XCTAssertEqual(underWay.base?.name, "Louisville")
        XCTAssertFalse(underWay.isWaitingAtBase, "only a trip still ahead is waited for")
        let elsewhere = try XCTUnwrap(TripMap.make(tripLegs: TripMapTestLegs.europeTrip(), isNextTrip: true,
                                                   homeAirportCode: "LEX", baseAirportCode: "ORD", legacyDelayMinutes: nil,
                                                   at: hours(-3), coordinate: TripMapTestLegs.coordinate))
        XCTAssertNil(elsewhere.base, "no leg names it")
    }

    func test_activity_everySharedCase_matches() throws {
        let cases = try TripMapFixtures.activityCases()
        XCTAssertEqual(TripWait.shortestLayover, cases.constants.shortestLayoverHours * 3600)
        XCTAssertFalse(cases.trips.isEmpty)
        for trip in cases.trips {
            let map = try XCTUnwrap(Self.map(of: trip, airports: cases.airports), trip.name)
            for moment in trip.moments {
                let activity = map.activity(at: moment.at)
                XCTAssertEqual(activity?.kind.rawValue, moment.kind, "\(trip.name), \(moment.note)")
                XCTAssertEqual(activity?.words, moment.words, "\(trip.name), \(moment.note)")
            }
        }
    }

    /// The trip's legs as CrewLu would send them, each city from the shared airports.
    private static func map(of trip: TripMapFixtures.ActivityCases.Trip,
                            airports: [String: TripMapFixtures.ActivityCases.Airport]) -> TripMap? {
        let legs = trip.legs.map { leg in
            TripLeg(id: leg.id, tripId: "T1", type: leg.type, startTime: leg.start, endTime: leg.end,
                    airportCode: leg.airport, city: leg.airport.flatMap { airports[$0]?.city },
                    timezoneIdentifier: nil, arrivalTimezoneIdentifier: nil, flightNumber: nil,
                    departureAirport: leg.from, arrivalAirport: leg.to,
                    departureCity: leg.from.flatMap { airports[$0]?.city }, arrivalCity: leg.to.flatMap { airports[$0]?.city },
                    tripDayNumber: nil, tripTotalDays: nil, delayMinutes: leg.delayMinutes, airlineCode: nil, label: nil)
        }
        return TripMap.make(tripLegs: legs, isNextTrip: trip.mode == .nextTrip, isRecap: trip.mode == .recap,
                            homeAirportCode: trip.home, baseAirportCode: trip.base,
                            isWaitingAtBase: trip.waitingAt == .base, legacyDelayMinutes: nil, at: .distantPast,
                            coordinate: { code in airports[code].map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) } })
    }
}
