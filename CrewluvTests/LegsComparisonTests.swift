//
//  LegsComparisonTests.swift
//  CrewluvTests
//
//  The alerts compare a status's legs as legs, not as bytes (partner links piece 4 spec §14)
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
struct LegsComparisonTests {
    private static func legs(_ json: String) -> Data {
        Data(json.utf8)
    }

    private static let crewluCloud = legs(#"[{"endTime":1792612800,"flightNumber":"5X123","id":"1","startTime":1792605600,"type":"flight"}]"#)

    @Test func test_theSameLegs_inAnotherKeyOrder_areTheSame() {
        let iCloud = Self.legs(#"[{"id":"1","type":"flight","startTime":1792605600,"endTime":1792612800,"flightNumber":"5X123"}]"#)

        #expect(!StatusChangeNotifier.legsDiffer(iCloud, Self.crewluCloud))
    }

    @Test func test_aFieldThisAppDoesntRead_changesNothing() {
        let iCloud = Self.legs(#"[{"id":"1","type":"flight","startTime":1792605600,"endTime":1792612800,"flightNumber":"5X123","gate":"B7"}]"#)

        #expect(!StatusChangeNotifier.legsDiffer(iCloud, Self.crewluCloud))
    }

    @Test func test_aChangedLeg_differs() {
        let later = Self.legs(#"[{"endTime":1792616400,"flightNumber":"5X123","id":"1","startTime":1792605600,"type":"flight"}]"#)

        #expect(StatusChangeNotifier.legsDiffer(Self.crewluCloud, later))
    }

    @Test func test_legsAndNone_differ() {
        #expect(StatusChangeNotifier.legsDiffer(nil, Self.crewluCloud))
        #expect(StatusChangeNotifier.legsDiffer(Self.crewluCloud, nil))
        #expect(!StatusChangeNotifier.legsDiffer(nil, nil))
    }

    @Test func test_bytesThatDontReadAsLegs_compareAsBytes() {
        #expect(!StatusChangeNotifier.legsDiffer(Self.legs("not legs"), Self.legs("not legs")))
        #expect(StatusChangeNotifier.legsDiffer(Self.legs("not legs"), Self.crewluCloud))
    }

    // MARK: - The Alerts at the Switch

    /// A status on a trip whose next departure is at `departure`, with `legs` as its legs' bytes.
    private static func status(legs: Data, departure: TimeInterval) throws -> SharedPilotStatus {
        let status = try Make.summary(["currentTripId": "trip", "nextDepartureTime": departure])
            .pilotStatus(partnerID: Make.partnerA, at: .now)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(status)) as? [String: Any])
        json["tripLegsJSON"] = legs.base64EncodedString()
        return try JSONDecoder().decode(SharedPilotStatus.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test func test_theSwitch_alertsNoNewDeparture_forTheSameLegsInAnotherKeyOrder() throws {
        let iCloudLegs = Self.legs(#"[{"id":"1","type":"flight","startTime":1792605600,"endTime":1792612800,"flightNumber":"5X123"}]"#)
        let iCloud = try Self.status(legs: iCloudLegs, departure: 1_792_605_600)
        // Crewlu Cloud's writer picked another next departure from the same legs, as it can each time one passes.
        let crewluCloud = try Self.status(legs: Self.crewluCloud, departure: 1_792_612_800)

        #expect(StatusChangeNotifier.evaluateScheduleChanges(old: iCloud, new: crewluCloud, name: "Dad").isEmpty)
    }

    @Test func test_aLegThatChanged_stillAlertsTheNewDeparture_withinItsTrip() throws {
        let legs = Self.legs(#"[{"endTime":1792612800,"flightNumber":"5X123","id":"1","startTime":1792605600,"tripId":"trip","type":"flight"}]"#)
        let later = Self.legs(#"[{"endTime":1792616400,"flightNumber":"5X123","id":"1","startTime":1792609200,"tripId":"trip","type":"flight"}]"#)
        let old = try Self.status(legs: legs, departure: 1_792_605_600)
        let new = try Self.status(legs: later, departure: 1_792_609_200)

        #expect(StatusChangeNotifier.evaluateScheduleChanges(old: old, new: new, name: "Dad").map(\.kind) == [.departure])
    }
}
