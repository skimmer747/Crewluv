//
//  AlertWordingTests.swift
//  CrewluvTests
//
//  The alerts' kinds and words, for the app's own alerts and the helper's (alert pushes spec §5.3, §6.4, §15.4)
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
struct AlertWordingTests {

    private static let newYork = TimeZone(identifier: "America/New_York")!

    /// A status for partner A with `fields`, and its words for `kind`.
    private static func words(
        _ kind: AlertKind, _ fields: [String: Any] = [:], effectiveDelay: Int = 0, homeArrival: Date? = nil
    ) throws -> (title: String, body: String)? {
        let status = try Make.summary(fields).pilotStatus(partnerID: Make.partnerA, at: Date(timeIntervalSince1970: 1_792_605_600))
        return AlertWording.words(
            for: kind, name: "Dad", status: status, effectiveDelay: effectiveDelay, homeArrival: homeArrival, timeZone: newYork
        )
    }

    @Test func test_theKinds_areCrewluCloudsNames() {
        #expect(AlertKind.allCases.map(\.rawValue) == [
            "new-trip", "new-trips", "trip-cancelled", "trips-cancelled", "home-later", "home-earlier", "departure",
            "trip-extended", "trip-shortened", "quick-status", "delayed", "early", "delay-cleared", "early-cleared",
            "home", "took-off",
        ])
        #expect(AlertKind(rawValue: "a-kind-from-later") == nil)
        #expect(AlertWording.unknownKind == "New update")
    }

    @Test(arguments: [
        ("Call Me", "is asking you to call"),
        ("Free to Talk", "is free to talk"),
        ("Out for Dinner", "went out for dinner"),
        ("Sleeping", "is sleeping"),
        ("At the gym", "At the gym"),
    ])
    func test_aQuickStatus_inItsWords(status: String, body: String) throws {
        let quick = ["quickStatus": status, "quickStatusTargets": NSNull()] as [String: Any]
        #expect(try Self.words(.quickStatus, quick)?.title == "Dad")
        #expect(try Self.words(.quickStatus, quick)?.body == body)
    }

    @Test func test_theFlight_withItsDelay() throws {
        #expect(try Self.words(.delayed, effectiveDelay: 45).map { [$0.title, $0.body] } == ["Dad's Flight", "Delayed 45 minutes"])
        #expect(try Self.words(.early, effectiveDelay: -10)?.body == "Departing 10 minutes early")
        #expect(try Self.words(.delayCleared)?.body == "Delay cleared")
        #expect(try Self.words(.earlyCleared)?.body == "Early departure cleared")
        #expect(try Self.words(.earlyCleared)?.title == "Dad's Flight")
    }

    @Test func test_theTrips_withoutNumbers() throws {
        #expect(try Self.words(.newTrip, ["tripTotalDays": 4])?.body == "Has a new trip")
        #expect(try Self.words(.newTrips)?.body == "Has new trips")
        #expect(try Self.words(.tripCancelled)?.body == "Trip was cancelled")
        #expect(try Self.words(.tripsCancelled)?.body == "Trips were cancelled")
        #expect(try Self.words(.tripsCancelled)?.title == "Dad")
        #expect(try Self.words(.tripExtended, ["tripTotalDays": 5])?.body == "Trip extended to 5 days")
        #expect(try Self.words(.tripShortened, ["tripTotalDays": 3])?.body == "Trip shortened to 3 days")
    }

    @Test func test_theStatus_andTheTimes_inThePhonesTimeZone() throws {
        #expect(try Self.words(.home)?.body == "is home!")
        #expect(try Self.words(.tookOff)?.body == "just took off")
        let arrival = Date(timeIntervalSince1970: 1_792_676_700)
        #expect(try Self.words(.homeLater, homeArrival: arrival)?.body == "Getting home later — now 9:45 AM")
        #expect(try Self.words(.homeEarlier, homeArrival: arrival)?.body == "Getting home earlier — now 9:45 AM")
        #expect(try Self.words(.departure, ["nextDepartureTime": 1_792_639_200])?.body == "Departure changed — now 11:20 PM")
    }

    @Test func test_aStatusThatNoLongerFitsItsKind_hasNoWords() throws {
        #expect(try Self.words(.quickStatus) == nil, "the quick status was cleared")
        #expect(try Self.words(.delayed) == nil, "the delay is gone")
        #expect(try Self.words(.early, effectiveDelay: 30) == nil)
        #expect(try Self.words(.delayCleared, effectiveDelay: 30) == nil, "the delay came back")
        #expect(try Self.words(.homeLater) == nil, "no home arrival")
        #expect(try Self.words(.departure) == nil, "no next departure")
        #expect(try Self.words(.tripExtended) == nil, "no trip length")
    }

    @Test func test_eachKind_hasItsPlainLine() {
        #expect(AlertKind.allCases.map(AlertWording.plainLine(for:)) == [
            "Has a new trip", "Has new trips", "Trip was cancelled", "Trips were cancelled", "Getting home later",
            "Getting home earlier", "Departure changed", "Trip extended", "Trip shortened", "sent a quick status",
            "Flight delayed", "Departing early", "Delay cleared", "Early departure cleared", "is home!", "just took off",
        ])
    }

    @Test func test_everyAlertPlaysASound_butASleepingQuickStatus() {
        #expect(!AlertWording.playsSound(.quickStatus, quickStatus: "Sleeping"))
        #expect(AlertWording.playsSound(.quickStatus, quickStatus: "Call Me"))
        #expect(AlertWording.playsSound(.home, quickStatus: "Sleeping"))
    }
}
