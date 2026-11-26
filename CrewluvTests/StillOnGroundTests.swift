//
//  StillOnGroundTests.swift
//  CrewluvTests
//
//  A real plane still on the ground at its departure airport after the plan's takeoff time (which plane design §4):
//  when it is, and the words that say so under the timeline and in the facts, in US English for a family in
//  Louisville.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class StillOnGroundTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// A shared case's flight at its moment `time`, as a leg of the map.
    private func leg(of name: String, at time: String) throws -> (leg: MapLeg, at: Date) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let moment = try cases.moment(time, of: flightCase)
        return (try cases.mapLeg(flightCase, at: moment), moment.at)
    }

    private func map(of leg: MapLeg) -> TripMap {
        TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: leg.origin,
                span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
    }

    private let rockford = AirportMark(code: "RFD", city: "Rockford", coordinate: CLLocationCoordinate2D(latitude: 42.2, longitude: -89.1),
                                       timeZone: TimeZone(identifier: "America/Chicago"))
    private let anchorage = AirportMark(code: "ANC", city: "Anchorage", coordinate: CLLocationCoordinate2D(latitude: 61.2, longitude: -150.0),
                                        timeZone: TimeZone(identifier: "America/Anchorage"))

    // MARK: - When it is

    func test_atDeparture_isStillAtGate_onlyAfterThePlansTakeoffTime_whileItsRealPlaneIsAtItsDepartureAirport() throws {
        for (name, time) in [("still on the ground just after the plan's takeoff", "13T12:18:00"),
                             ("still on the ground twenty minutes after", "13T12:35:00")] {
            let (leg, at) = try leg(of: name, at: time)
            XCTAssertEqual(leg.atDeparture(at: at), .stillAtGate, name)
        }
        for (name, time) in [("on the ground before the plan's takeoff", "13T12:10:00"), ("ahead, in the air", "13T12:41:50"),
                             ("landed, seen all the way", "13T13:30:00"), ("on the ground somewhere else", "13T13:21:00"),
                             ("no live data", "13T12:30:00")] {
            let (leg, at) = try leg(of: name, at: time)
            XCTAssertNotEqual(leg.atDeparture(at: at), .stillAtGate, name)
        }
    }

    func test_atDeparture_atEverySharedMoment_isStillAtGateOrReturned_asTheBarsStillOnTheGround() throws {
        let cases = try TripMapFixtures.liveCases()
        // At the gate before the plan's takeoff, or due by the schedule, isn't what the bar calls still on the ground.
        func late(_ atDeparture: AtDeparture?) -> AtDeparture? {
            atDeparture == .stillAtGate || atDeparture == .returned ? atDeparture : nil
        }
        var atTheGate = 0
        for flightCase in cases.flights {
            for moment in flightCase.moments {
                let leg = try cases.mapLeg(flightCase, at: moment)
                // A plane back at the gate after an air return is at its departure airport too (air return design §3).
                let expected: AtDeparture? = if moment.phase == "returned" {
                    .returned
                } else if moment.phase == "onGround", moment.label?.hasPrefix("Still on the ground") ?? false {
                    .stillAtGate
                } else {
                    nil
                }
                XCTAssertEqual(late(leg.atDeparture(at: moment.at)), expected, "\(flightCase.name) at \(moment.at)")
                XCTAssertEqual(late(try cases.mapFlight(flightCase).seenAtDeparture(at: moment.at)), expected,
                               "\(flightCase.name) at \(moment.at)")
                if expected != nil { atTheGate += 1 }
            }
        }
        XCTAssertGreaterThanOrEqual(atTheGate, 2)
    }

    func test_seenAtDeparture_goesByCrewluCloudsClock() throws {
        // Crewlu Cloud's clock is 6 minutes ahead of this device's: at 12:12 here it's 12:18 there, after the plan's
        // takeoff time at 12:15.
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "still on the ground just after the plan's takeoff")
        let moment = try cases.moment("13T12:18:00", of: flightCase)
        XCTAssertEqual(try cases.mapFlight(flightCase, clockOffset: 360).seenAtDeparture(at: moment.at.addingTimeInterval(-360)),
                       .stillAtGate)
        XCTAssertNotEqual(try cases.mapFlight(flightCase).seenAtDeparture(at: moment.at.addingTimeInterval(-360)), .stillAtGate)
    }

    func test_flightInMotion_isTheFlightBetweenItsGates_neverADrive() throws {
        let (flight, _) = try leg(of: "ahead, in the air", at: "13T12:41:50")
        let drive = MapLeg(id: "d1", kind: .drive, origin: flight.destination, destination: flight.origin,
                           start: flight.end, end: flight.end.addingTimeInterval(3600), flightNumber: nil)
        let map = TripMap(mode: .onTrip, legs: [flight, drive], home: flight.origin,
                          span: DateInterval(start: flight.start, end: drive.end), tripDays: nil)
        XCTAssertEqual(map.flightInMotion(at: flight.start.addingTimeInterval(600))?.id, flight.id)
        XCTAssertNil(map.flightInMotion(at: drive.start.addingTimeInterval(600)))
        XCTAssertNil(map.flightInMotion(at: flight.start.addingTimeInterval(-60)))
    }

    func test_atDeparture_isNeverADrive_norAFlightOutsideItsGates() throws {
        let (leg, at) = try leg(of: "still on the ground twenty minutes after", at: "13T12:35:00")
        let drive = MapLeg(id: "d1", kind: .drive, origin: leg.origin, destination: leg.destination, start: leg.start, end: leg.end,
                           flightNumber: nil)
        XCTAssertNil(drive.atDeparture(at: at))
        let over = MapLeg(id: leg.id, kind: .flight, origin: leg.origin, destination: leg.destination, start: leg.start,
                          end: at, flightNumber: leg.flightNumber, flight: leg.flight)
        XCTAssertNil(over.atDeparture(at: at))
    }

    func test_flightNow_isStillInTheFlightsDepartureAirport_whileItsRealPlaneWaitsThere() throws {
        let (atTheGate, gateTime) = try leg(of: "still on the ground twenty minutes after", at: "13T12:35:00")
        guard case .stillIn(let airport)? = map(of: atTheGate).flightNow(at: gateTime) else { return XCTFail("still in") }
        XCTAssertEqual(airport.code, "SDF")
        let (flying, flyingTime) = try leg(of: "ahead, in the air", at: "13T12:41:50")
        XCTAssertNil(map(of: flying).flightNow(at: flyingTime))
    }

    func test_narrativeFlight_isStillAtTheGate_onlyWhileTheFlightsRealPlaneHasntLeftAfterThePlansTakeoff() throws {
        let cases = try TripMapFixtures.liveCases()
        func narrative(_ name: String, at time: String) throws -> NarrativeFlight? {
            let flightCase = try cases.flight(named: name)
            let now = try cases.moment(time, of: flightCase).at
            let flights = ["f1": try cases.mapFlight(flightCase)]
            let legs = LiveLegs.replacingTimes(in: [cases.tripLeg(flightCase)], with: flights, at: now)
            return LiveLegs.narrativeFlight(in: legs, flights: flights, at: now, isAwaitingLive: false)
        }
        XCTAssertEqual(try narrative("still on the ground twenty minutes after", at: "13T12:35:00"), .stillAtGate)
        XCTAssertEqual(try narrative("still on the ground just after the plan's takeoff", at: "13T12:18:00"), .stillAtGate)
        XCTAssertEqual(try narrative("on the ground before the plan's takeoff", at: "13T12:10:00"), .atGate)
        XCTAssertEqual(try narrative("ahead, in the air", at: "13T12:41:50"), .flying)
        XCTAssertEqual(try narrative("no live data", at: "13T12:30:00"), .shouldBeFlying(saysNotTracked: true))
        let atTheGate = try cases.flight(named: "still on the ground twenty minutes after")
        XCTAssertEqual(LiveLegs.narrativeFlight(in: [cases.tripLeg(atTheGate)], flights: [:],
                                                at: try cases.moment("13T12:35:00", of: atTheGate).at, isAwaitingLive: false),
                       .shouldBeFlying(saysNotTracked: true), "by the schedule alone")
    }

    // MARK: - The words

    func test_timeline_saysWhereTheRealPlaneIsStillOnTheGround_inPlaceOfFlying() {
        // 5:21 PM UTC is 12:21 PM in Louisville.
        let date = FactsTestData.date("2026-11-13T17:21:00Z")
        let flying = TripActivity(kind: .flying, place: anchorage)
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: flying, flight: .stillIn(rockford), calendar: calendar, locale: locale)),
                       "Fri 12:21 PM L · On the ground in Rockford")
        XCTAssertEqual(plain(TripMapWording.timelineSpokenValue(date, activity: flying, flight: .stillIn(rockford), calendar: calendar, locale: locale)),
                       "Friday 12:21 PM, on the ground in Rockford")
        // Without it, flying, as before.
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: flying, calendar: calendar, locale: locale)),
                       "Fri 12:21 PM L · Flying to Anchorage")
        XCTAssertEqual(plain(TripMapWording.timelineSpokenValue(date, activity: flying, calendar: calendar, locale: locale)),
                       "Friday 12:21 PM, flying to Anchorage")
    }

    func test_factsWords_sayItsStillOnTheGround_andHowFarItHasToGo() {
        XCTAssertEqual(FactsWording.stillOnGround(in: rockford), "Still on the ground in Rockford")
        XCTAssertEqual(FactsWording.toGo(miles: 2_788, locale: locale), "2,788 mi to go")
    }
}
