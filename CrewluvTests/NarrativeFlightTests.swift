//
//  NarrativeFlightTests.swift
//  CrewluvTests
//
//  How the status sentence tells the flight under way (live or scheduled design §4; which plane design §4; landed
//  before the gate design §3; air return design §3), held to the shared live cases.
//

import XCTest
@testable import Crewluv

final class NarrativeFlightTests: XCTestCase {

    /// The sentence's flight for a case at `time`, with its live data as the screen's model hands it on, if it has any.
    private func narrative(_ name: String, at time: String, isAwaitingLive: Bool = false) throws -> NarrativeFlight? {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let now = try cases.moment(time, of: flightCase).at
        return try narrative(flightCase, cases: cases, at: now, isAwaitingLive: isAwaitingLive)
    }

    private func narrative(
        _ flightCase: TripMapFixtures.LiveCases.Flight, cases: TripMapFixtures.LiveCases, at now: Date,
        isAwaitingLive: Bool = false
    ) throws -> NarrativeFlight? {
        let flights: [String: MapFlight] = try cases.live(flightCase) == nil ? [:] : ["f1": cases.mapFlight(flightCase)]
        let legs = LiveLegs.replacingTimes(in: [cases.tripLeg(flightCase)], with: flights, at: now)
        return LiveLegs.narrativeFlight(in: legs, flights: flights, at: now, isAwaitingLive: isAwaitingLive)
    }

    func test_narrativeFlight_seenInTheAir_orABestGuess_isFlying() throws {
        XCTAssertEqual(try narrative("ahead, in the air", at: "13T12:41:50"), .flying)
        XCTAssertEqual(try narrative("ahead, in the air", at: "13T12:45:00"), .flying)
    }

    func test_narrativeFlight_theRealPlaneOnTheGround_saysWhere() throws {
        XCTAssertEqual(try narrative("on the ground before the plan's takeoff", at: "13T12:10:00"), .atGate)
        XCTAssertEqual(try narrative("still on the ground twenty minutes after", at: "13T12:35:00"), .stillAtGate)
        XCTAssertEqual(try narrative("an air return, back on the ground", at: "13T12:41:00"), .returned)
        // Down at 13:14:51 and at the gate at 13:21:51: a minute before the gate it's still between its gates.
        let cases = try TripMapFixtures.liveCases()
        let landed = try cases.flight(named: "landed, seen all the way")
        let gate = try cases.moment("13T13:30:00", of: landed).end
        XCTAssertEqual(try narrative(landed, cases: cases, at: gate.addingTimeInterval(-60)), .landed)
    }

    func test_narrativeFlight_aRealPlaneDownSomewhereElse_isFlying() throws {
        XCTAssertEqual(try narrative("on the ground somewhere else", at: "13T13:21:00"), .flying)
    }

    func test_narrativeFlight_byTheScheduleAlone_isDueToTakeOff_thenShouldBeFlying() throws {
        let cases = try TripMapFixtures.liveCases()
        let noLive = try cases.flight(named: "no live data")
        XCTAssertEqual(try narrative(noLive, cases: cases, at: noLive.departure.addingTimeInterval(5 * 60)), .dueToTakeOff)
        XCTAssertEqual(try narrative("no live data", at: "13T12:30:00"), .shouldBeFlying(saysNotTracked: true))
        XCTAssertEqual(try narrative("on the ground before the plan's takeoff", at: "13T12:13:00"), .dueToTakeOff)
        XCTAssertEqual(try narrative("an air return, back on the ground", at: "13T12:43:01"), .shouldBeFlying(saysNotTracked: true))
    }

    func test_narrativeFlight_whileWaitingForTheFirstAnswer_shouldBeFlying_withoutSayingNotTracked() throws {
        XCTAssertEqual(try narrative("no live data", at: "13T12:30:00", isAwaitingLive: true), .shouldBeFlying(saysNotTracked: false))
    }

    func test_narrativeFlight_withNoFlightBetweenItsGates_isNil() throws {
        let cases = try TripMapFixtures.liveCases()
        let noLive = try cases.flight(named: "no live data")
        XCTAssertNil(LiveLegs.narrativeFlight(in: [cases.tripLeg(noLive)], flights: [:], at: noLive.departure.addingTimeInterval(-60),
                                              isAwaitingLive: false))
        XCTAssertNil(LiveLegs.narrativeFlight(in: [cases.tripLeg(noLive)], flights: [:], at: noLive.arrival, isAwaitingLive: false))
    }

    func test_narrativeFlight_withASummaryWideDelay_goesByTheDelayedGateTimes_asTheMapDoes() throws {
        // A CrewLu that doesn't tag legs: 60 minutes late, the flight leaves its gate at 13:00 and takes off at 13:15.
        let cases = try TripMapFixtures.liveCases()
        let legs = [cases.tripLeg(try cases.flight(named: "no live data"))]
        let departure = try cases.flight(named: "no live data").departure
        func narrative(minutesAfterTheSchedule minutes: Double) -> NarrativeFlight? {
            LiveLegs.narrativeFlight(in: legs, legacyDelayMinutes: 60, flights: [:],
                                     at: departure.addingTimeInterval(minutes * 60), isAwaitingLive: false)
        }
        XCTAssertNil(narrative(minutesAfterTheSchedule: 30), "still at the gate, by the delayed times")
        XCTAssertEqual(narrative(minutesAfterTheSchedule: 65), .dueToTakeOff)
        XCTAssertEqual(narrative(minutesAfterTheSchedule: 80), .shouldBeFlying(saysNotTracked: true))
    }
}
