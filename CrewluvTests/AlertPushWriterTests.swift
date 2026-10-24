//
//  AlertPushWriterTests.swift
//  CrewluvTests
//
//  The alert pushes' helper writes the kind's words from the status it reads, or the plain line (alert pushes
//  spec §6.1, §9.3)
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
struct AlertPushWriterTests {
    private let door = StandInPartnerDoor()
    private let keys = InMemoryDeviceKeyStore()
    /// A time zone few Macs are in, so the times read in the writer's own, not the Mac's.
    private static let kolkata = TimeZone(identifier: "Asia/Kolkata")!
    /// Shortly after `Make.summary`'s default moment.
    private static let now = Date(timeIntervalSince1970: 1_792_606_000)

    init() {
        keys.key = Make.key
        keys.name = "Dad"
    }

    private var writer: AlertPushWriter {
        AlertPushWriter(door: door, keys: keys, timeZone: Self.kolkata)
    }

    private func words(for kind: AlertKind) async -> AlertPushWords {
        await writer.words(for: kind, at: Self.now)
    }

    /// The door answers with a summary for partner A with `fields`.
    private func answers(_ fields: [String: Any]) throws {
        door.viewAnswers = [Make.answer(updatedAt: "2026-10-21T18:00:00.000Z", try Make.summary(fields))]
    }

    @Test func test_theKind_isReadFromThePush_andOneThisAppDoesntKnow_keepsThePushsOwnWords() {
        #expect(AlertPushWriter.kind(of: ["kind": "quick-status", "aps": [:]]) == .quickStatus)
        #expect(AlertPushWriter.kind(of: ["kind": "trips-cancelled"]) == .tripsCancelled)
        #expect(AlertPushWriter.kind(of: ["kind": "something-later"]) == nil)
        #expect(AlertPushWriter.kind(of: [:]) == nil)
    }

    @Test func test_aStatusThatFits_isWrittenInTheKindsWords_underTheNameThePilotSetForThisPartner() async throws {
        try answers([
            "quickStatus": "Call Me", "quickStatusExpiry": 1_792_609_600, "displayNameByPartner": [Make.partnerA: "Captain"],
        ])

        #expect(await words(for: .quickStatus) == AlertPushWords(title: "Captain", body: "is asking you to call"))
        #expect(door.views.map(\.key) == [Make.key])
        #expect(door.views.map(\.since) == [nil], "the whole status, every time")
    }

    @Test func test_withNoNameForThisPartner_theTitleIsThePilotsFirstName() async throws {
        try answers(["quickStatus": "Free to Talk"])

        #expect(await words(for: .quickStatus) == AlertPushWords(title: "Alex", body: "is free to talk"))
    }

    @Test func test_aDelay_isTitledWithTheFlight_withTheDelayAtTheMoment_asOnALeg() async throws {
        try answers(["flightDelayMinutes": 45])
        #expect(await words(for: .delayed) == AlertPushWords(title: "Alex's Flight", body: "Delayed 45 minutes"))

        try answers(["tripLegs": [Self.leg(from: 1_792_605_000, to: 1_792_612_800, delay: 30)]])
        #expect(await words(for: .delayed) == AlertPushWords(title: "Alex's Flight", body: "Delayed 30 minutes"))
    }

    @Test func test_theWayHome_isTheArrivalTheLegsGiveAtTheMoment_readInThePhonesTimeZone() async throws {
        try answers([
            "homeAirportCode": "ATL",
            "homeArrivalTime": 1_792_627_200,
            "tripLegs": [Self.leg(from: 1_792_630_800, to: 1_792_634_400, arriving: "ATL")],
        ])
        #expect(await words(for: .homeLater) == AlertPushWords(title: "Alex", body: "Getting home later — now 7:30 AM"))

        try answers(["homeArrivalTime": 1_792_627_200])
        #expect(await words(for: .homeEarlier) == AlertPushWords(title: "Alex", body: "Getting home earlier — now 5:30 AM"),
                "with no legs, the summary's own")
    }

    /// A flight leg of trip T1, as a summary has it.
    private static func leg(
        from start: TimeInterval, to end: TimeInterval, arriving airport: String = "SDF", delay: Int? = nil
    ) -> [String: Any] {
        var leg: [String: Any] = [
            "id": "leg-\(Int(start))", "tripId": "T1", "type": "flight", "startTime": start, "endTime": end,
            "arrivalAirport": airport,
        ]
        leg["delayMinutes"] = delay
        return leg
    }

    @Test func test_aStatusThatNoLongerFits_givesThePlainLine() async throws {
        try answers([:])

        #expect(await words(for: .quickStatus) == AlertPushWords(title: "Dad", body: "sent a quick status"))
    }

    @Test func test_eachAnswerThatIsntAStatus_givesThePlainLine_andTheKeyIsKept() async {
        door.viewAnswers = [
            .failure(.refused(.sharingEnded)),
            .failure(.unavailable),
            Make.noSummaryYet,
            Make.unchanged(updatedAt: "2026-10-21T18:00:00.000Z"),
        ]

        for _ in 0..<4 {
            #expect(await words(for: .tripCancelled) == AlertPushWords(title: "Dad", body: "Trip was cancelled"))
        }
        #expect(door.views.count == 4)
        #expect(keys.key == Make.key, "a sharing_ended is left for the app")
    }

    @Test func test_aTimeout_givesThePlainLine() async {
        // The door's 20-second limit ends a call as unavailable, and with no answers left the stand-in door is that.
        #expect(await words(for: .newTrip) == AlertPushWords(title: "Dad", body: "Has a new trip"))
    }

    @Test func test_withNoKey_thePlainLine_withoutAsking() async {
        keys.key = nil

        #expect(await words(for: .home) == AlertPushWords(title: "Dad", body: "is home!"))
        #expect(door.views.isEmpty)
    }

    @Test func test_beforeTheFirstUnlock_thePlainLine_withNoTitle() async {
        keys.readFails = true

        #expect(await words(for: .delayed) == AlertPushWords(title: "", body: "Flight delayed"))
        #expect(door.views.isEmpty)
    }

    @Test func test_thePlainLine_isTitledWithTheSavedName_orHasNoTitle() {
        #expect(writer.plainLine(for: .newTrips) == AlertPushWords(title: "Dad", body: "Has new trips"))
        keys.name = nil
        #expect(writer.plainLine(for: .newTrips) == AlertPushWords(title: "", body: "Has new trips"))
    }

    @Test func test_thePendingAlert_isDeliveredOnce_withItsWords() {
        var delivered: [AlertPushWords?] = []
        let pending = PendingAlertPush()
        pending.start { delivered.append($0) }
        pending.hold(AlertPushWords(title: "Dad", body: "sent a quick status"))

        pending.finish(with: AlertPushWords(title: "Dad", body: "is asking you to call"))
        pending.expire()

        #expect(delivered == [AlertPushWords(title: "Dad", body: "is asking you to call")])
    }

    @Test func test_whenTimeRunsOutFirst_thePlainLine_andTheWordsAfterAreDropped() {
        var delivered: [AlertPushWords?] = []
        let pending = PendingAlertPush()
        pending.start { delivered.append($0) }
        pending.hold(AlertPushWords(title: "Dad", body: "sent a quick status"))

        pending.expire()
        pending.finish(with: AlertPushWords(title: "Dad", body: "is asking you to call"))

        #expect(delivered == [AlertPushWords(title: "Dad", body: "sent a quick status")])
    }

    @Test func test_whenTimeRunsOutBeforeThePlainLine_thePushAsItCame() {
        var delivered: [AlertPushWords?] = []
        let pending = PendingAlertPush()
        pending.start { delivered.append($0) }

        pending.expire()

        #expect(delivered == [nil])
    }
}
