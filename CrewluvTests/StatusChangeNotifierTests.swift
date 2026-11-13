//
//  StatusChangeNotifierTests.swift
//  CrewluvTests
//
//  A reading whose alerts the alert pushes bring is compared and remembered, but posts nothing (alert pushes
//  spec §6.3); trips are matched by span (§15.3), as in Crewlu Cloud's partner-push tests
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
final class StatusChangeNotifierTests {
    private let defaultsName = "StatusChangeNotifierTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let posted = PostedAlerts()
    private let notifier: StatusChangeNotifier

    init() throws {
        defaults = try #require(UserDefaults(suiteName: defaultsName))
        notifier = StatusChangeNotifier(defaults: defaults, post: { [posted] in posted.add($0) })
    }

    deinit {
        defaults.removePersistentDomain(forName: defaultsName)
    }

    /// Hands the notifier a reading of a summary made at `lastUpdated` with `fields`.
    private func read(_ lastUpdated: TimeInterval, _ fields: [String: Any] = [:], posting: Bool = true) async throws {
        let reading = PilotReading.crewluCloud(try Make.summary(lastUpdated: lastUpdated, fields), partnerID: Make.partnerA, updatedAt: nil)
        await notifier.evaluate(reading, titledWith: nil, posting: posting)
    }

    private let callMe = ["quickStatus": "Call Me", "quickStatusTargets": NSNull()] as [String: Any]

    @Test func test_aReadingTheAlertPushesBring_postsNothing_butIsWhatTheNextIsComparedWith() async throws {
        try await read(1)
        try await read(2, callMe, posting: false)
        #expect(posted.all.isEmpty)

        try await read(3, callMe)
        #expect(posted.all.isEmpty, "Call Me was already seen")
        try await read(4, ["quickStatus": "Free to Talk", "quickStatusTargets": NSNull()])
        #expect(posted.all.map(\.kind) == [.quickStatus])
    }

    @Test func test_aReadingTheAppAlertsItself_postsItsAlerts() async throws {
        try await read(1)
        try await read(2, callMe)

        #expect(posted.all.map(\.body) == ["is asking you to call"])
    }

    @Test func test_aSnapshotCrewluve1_2Saved_comparesItsHomeArrivalWithNoOther_once() async throws {
        let home = { (minutesLater: Double) -> [String: Any] in
            ["currentTripId": "T1", "homeArrivalTime": 1_792_674_300 + minutesLater * 60]
        }
        try await read(1, home(0))
        // As Crewluve 1.2 saved it: without the trips its home arrival belongs to.
        let key = "LastSeenPilotSnapshot"
        let data = try #require(defaults.data(forKey: key))
        var saved = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(saved.removeValue(forKey: "homeArrivalTrips") != nil)
        defaults.set(try JSONSerialization.data(withJSONObject: saved), forKey: key)

        try await read(2, home(30).merging(callMe) { $1 })
        #expect(posted.all.map(\.kind) == [.quickStatus], "its home arrival belongs to no trip, so isn't compared")
        try await read(3, home(60).merging(callMe) { $1 })
        #expect(posted.all.map(\.kind) == [.quickStatus, .homeLater], "the next one is")
    }

    /// A leg of `tripId` from `start` to `end`, in seconds since 1970.
    private static func leg(_ tripId: String?, _ start: TimeInterval, _ end: TimeInterval) -> TripLeg {
        TripLeg(
            id: "\(tripId ?? "none")-\(Int(start))",
            tripId: tripId,
            type: .flight,
            startTime: Date(timeIntervalSince1970: start),
            endTime: Date(timeIntervalSince1970: end),
            airportCode: nil,
            city: nil,
            timezoneIdentifier: nil,
            arrivalTimezoneIdentifier: nil,
            flightNumber: nil,
            departureAirport: nil,
            arrivalAirport: nil,
            departureCity: nil,
            arrivalCity: nil,
            tripDayNumber: nil,
            tripTotalDays: nil,
            delayMinutes: nil,
            airlineCode: nil,
            label: nil
        )
    }

    private static func missing(_ from: [TripLeg], _ to: [TripLeg], at moment: TimeInterval = 0) -> Int {
        StatusChangeNotifier.tripsMissing(from: from, to: to, at: Date(timeIntervalSince1970: moment))
    }

    private static let t1 = [leg("T1", 100, 200), leg("T1", 300, 400)]

    @Test func test_tripsAddedOrTakenOff_matchBySpan_onlyThoseNotOver_andNeverAgainstAStatusWithNoTrips() {
        let backwards = [Self.leg("T1", 300, 400), Self.leg("T1", 100, 200)]
        let elsewhere = Self.leg("T2", 500, 600)

        #expect(Self.missing(Self.t1, [elsewhere]) == 1, "T1 has no part in the other")
        #expect(Self.missing(Self.t1, [Self.leg("T9", 150, 160)]) == 0, "a leg of any trip in its span keeps it")
        #expect(Self.missing(Self.t1, [Self.leg("T9", 400, 500)]) == 1, "spans that only touch do not overlap")
        #expect(Self.missing(Self.t1, [Self.leg("T9", 50, 100)]) == 1, "at either end")
        #expect(Self.missing(Self.t1, [Self.leg("T9", 0, 1000), Self.leg("T8", 50, 60)]) == 0,
                "a long leg that starts first keeps it")
        #expect(Self.missing(Self.t1, [Self.leg("T9", 500, 600), Self.leg("T8", 50, 60)]) == 1,
                "the other's legs in any order")
        #expect(Self.missing(Self.t1, [Self.leg(nil, 150, 160), elsewhere]) == 1, "a leg of no trip keeps nothing")
        #expect(Self.missing(Self.t1, [elsewhere], at: 400) == 0, "a trip over by then is not missing")
        #expect(Self.missing(Self.t1 + [Self.leg("T3", 700, 800)], [elsewhere]) == 2)
        #expect(Self.missing(backwards, [Self.leg("T9", 150, 160)]) == 0, "legs in any order")
        #expect(Self.missing(backwards, [Self.leg("T9", 350, 360)]) == 0)
        // A status with no trips, so no trip legs, has none to miss and is missing none.
        #expect(Self.missing(Self.t1, []) == 0, "against no legs: nothing is taken off, or added")
        #expect(Self.missing(Self.t1, [Self.leg(nil, 500, 600)]) == 0, "against legs of no trip: nothing is taken off, or added")
        #expect(Self.missing([], Self.t1) == 0, "no trips of its own: none missing")
    }

    @Test func test_aDeparturesTrips_areThoseWhoseSpansHoldIt() {
        let at = { (time: TimeInterval) in StatusChangeNotifier.trips(at: Date(timeIntervalSince1970: time), in: Self.t1) }
        let touching = [Self.leg("T2", 100, 200), Self.leg("T1", 200, 300)]

        #expect(at(100) == ["T1"])
        #expect(at(250) == ["T1"], "between its legs, within its span")
        #expect(at(400) == ["T1"])
        #expect(at(401).isEmpty)
        #expect(StatusChangeNotifier.trips(at: Date(timeIntervalSince1970: 150), in: [Self.leg(nil, 100, 200)]).isEmpty)
        #expect(StatusChangeNotifier.trips(at: Date(timeIntervalSince1970: 200), in: touching) == ["T1", "T2"],
                "where two spans touch, both")
    }
}
