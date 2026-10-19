//
//  CloudSummaryTests.swift
//  CrewluvTests
//
//  Crewlu Cloud's summary, as each partner gets it, becomes the status the screens and
//  alerts use (partner links piece 4 spec §5.4).
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
@Suite(.enabled(if: PartnerSummaryFixtures.areReachable, "Reads its fixtures from the Mac's disk: run it on a simulator"))
struct CloudSummaryTests {
    private typealias Fixtures = PartnerSummaryFixtures

    /// When CrewLu wrote the quick-status examples, before any status in them expires.
    private static let written = Date(timeIntervalSince1970: 1_792_605_600)

    // MARK: - Every Field

    /// Status fields that aren't copied by name: the quick status is chosen (below), and the legs
    /// and display names arrive as JSON instead of iCloud's blobs.
    private static let notCopied: Set<String> = [
        "quickStatus", "quickStatusIcon", "quickStatusExpiry", "tripLegsJSON", "displayNameByPartnerJSON",
    ]

    @Test(arguments: PartnerSummaryFixtures.examples, ["A", "B"])
    func test_pilotStatus_copiesEveryFieldOfTheSameName(example: String, letter: String) throws {
        let sent = try Fixtures.json(example, partner: letter)
        let status = try Fixtures.summary(example, partner: letter)
            .pilotStatus(partnerID: Fixtures.partnerID(letter), at: Self.written)

        for field in Mirror(reflecting: status).children {
            let name = try #require(field.label)
            guard !Self.notCopied.contains(name) else { continue }
            let value = try #require(sent[name], "\(name) isn't in \(example).\(letter).json")
            #expect(Self.isSame(field.value, value), "\(name): \(field.value) against \(value)")
        }
    }

    // MARK: - Legs

    @Test func test_pilotStatus_turnsTheLegsIntoTodaysBlob() throws {
        let sent = try #require(try Fixtures.json("in-flight", partner: "A")["tripLegs"] as? [[String: Any]])
        let status = try Fixtures.summary("in-flight", partner: "A")
            .pilotStatus(partnerID: Fixtures.partnerA, at: Self.written)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let legs = try decoder.decode([TripLeg].self, from: try #require(status.tripLegsJSON))

        #expect(legs.map(\.id) == sent.map { $0["id"] as? String })
        #expect(legs.map(\.type.rawValue) == sent.map { $0["type"] as? String })
        #expect(legs.map(\.startTime.timeIntervalSince1970) == sent.map { $0["startTime"] as? Double })
        #expect(legs.map(\.endTime.timeIntervalSince1970) == sent.map { $0["endTime"] as? Double })
        #expect(legs.map(\.flightNumber) == sent.map { $0["flightNumber"] as? String })
        #expect(legs.map(\.arrivalAirport) == sent.map { $0["arrivalAirport"] as? String })
    }

    @Test func test_pilotStatus_givesTheSameLegsTheSameBytes() throws {
        let summary = try Fixtures.summary("in-flight", partner: "A")
        let first = summary.pilotStatus(partnerID: Fixtures.partnerA, at: Self.written).tripLegsJSON
        let later = summary.pilotStatus(partnerID: Fixtures.partnerA, at: Self.written.addingTimeInterval(60)).tripLegsJSON

        #expect(first != nil)
        #expect(first == later)
    }

    @Test func test_pilotStatus_withoutLegs_hasNoBlob() throws {
        var sent = try Fixtures.json("home", partner: "A")
        sent["tripLegs"] = NSNull()

        #expect(try Fixtures.summary(sent).pilotStatus(partnerID: Fixtures.partnerA, at: Self.written).tripLegsJSON == nil)
    }

    // MARK: - Display Name

    @Test func test_displayName_isTheNameThePilotSetForThisPartner() throws {
        let forA = try Fixtures.summary("display-names", partner: "A")

        #expect(forA.displayName(for: Fixtures.partnerA) == "Dad")
        #expect(forA.displayName(for: Fixtures.partnerA.uppercased()) == "Dad")
        #expect(try Fixtures.summary("display-names", partner: "B").displayName(for: Fixtures.partnerB) == nil)
        #expect(try Fixtures.summary("home", partner: "A").displayName(for: Fixtures.partnerA) == nil)
    }

    @Test func test_displayName_empty_isNone() throws {
        var sent = try Fixtures.json("display-names", partner: "A")
        sent["displayNameByPartner"] = [Fixtures.partnerA: ""]

        #expect(try Fixtures.summary(sent).displayName(for: Fixtures.partnerA) == nil)
    }

    // MARK: - Quick Status

    @Test func test_quickStatus_sentToOnePartner_reachesOnlyThem() throws {
        let forA = try Fixtures.summary("quick-status-one-partner", partner: "A")
            .pilotStatus(partnerID: Fixtures.partnerA, at: Self.written)
        let forB = try Fixtures.summary("quick-status-one-partner", partner: "B")
            .pilotStatus(partnerID: Fixtures.partnerB, at: Self.written)

        #expect(forA.quickStatus == "Call Me")
        #expect(forA.quickStatusIcon == "phone.fill")
        #expect(forA.quickStatusExpiry == Date(timeIntervalSince1970: 1_792_612_800))
        #expect(forB.quickStatus == nil)
        #expect(forB.quickStatusIcon == nil)
        #expect(forB.quickStatusExpiry == nil)
    }

    @Test(arguments: ["A", "B"])
    func test_quickStatus_sentToEveryone_reachesEachPartner(letter: String) throws {
        let status = try Fixtures.summary("quick-status-everyone", partner: letter)
            .pilotStatus(partnerID: Fixtures.partnerID(letter), at: Self.written)

        #expect(status.quickStatus == "Sleeping")
        #expect(status.quickStatusIcon == "moon.zzz.fill")
        #expect(status.quickStatusExpiry == nil)
        #expect(status.isSleeping)
    }

    @Test func test_quickStatus_ownComesBeforeEveryones() throws {
        let summary = try ownAndEveryone(ownExpiry: nil, everyoneExpiry: nil)

        #expect(summary.quickStatus(for: Fixtures.partnerA, at: Self.written)?.status == "Call Me")
    }

    @Test func test_quickStatus_ownExpired_givesWayToEveryones() throws {
        let expiry = Self.written.addingTimeInterval(3600)
        let summary = try ownAndEveryone(ownExpiry: expiry, everyoneExpiry: nil)

        #expect(summary.quickStatus(for: Fixtures.partnerA, at: expiry.addingTimeInterval(-1))?.status == "Call Me")
        #expect(summary.quickStatus(for: Fixtures.partnerA, at: expiry)?.status == "Sleeping")
    }

    @Test func test_quickStatus_bothExpired_isNone() throws {
        let later = Self.written.addingTimeInterval(60)
        let summary = try ownAndEveryone(ownExpiry: Self.written, everyoneExpiry: later)
        let status = summary.pilotStatus(partnerID: Fixtures.partnerA, at: later)

        #expect(summary.quickStatus(for: Fixtures.partnerA, at: later) == nil)
        #expect(status.quickStatus == nil)
        #expect(status.quickStatusIcon == nil)
        #expect(status.quickStatusExpiry == nil)
    }

    @Test func test_quickStatus_empty_isNone() throws {
        var sent = try Fixtures.json("quick-status-everyone", partner: "A")
        sent["quickStatusByPartner"] = [Fixtures.partnerA: ["status": "", "icon": "phone.fill"]]

        #expect(try Fixtures.summary(sent).quickStatus(for: Fixtures.partnerA, at: Self.written)?.status == "Sleeping")
        sent["quickStatus"] = ""
        #expect(try Fixtures.summary(sent).quickStatus(for: Fixtures.partnerA, at: Self.written) == nil)
    }

    @Test func test_quickStatus_forEveryone_needsThisPartnerAmongItsTargets() throws {
        var sent = try Fixtures.json("quick-status-everyone", partner: "A")
        sent["quickStatusByPartner"] = NSNull()

        sent["quickStatusTargets"] = [Fixtures.partnerB]
        #expect(try Fixtures.summary(sent).quickStatus(for: Fixtures.partnerA, at: Self.written) == nil)
        sent["quickStatusTargets"] = [Fixtures.partnerA]
        #expect(try Fixtures.summary(sent).quickStatus(for: Fixtures.partnerA, at: Self.written)?.status == "Sleeping")
    }

    @Test func test_quickStatusChange_isWhenTheShownOneExpires() throws {
        let ownExpiry = Self.written.addingTimeInterval(3600)
        let everyoneExpiry = Self.written.addingTimeInterval(7200)
        let summary = try ownAndEveryone(ownExpiry: ownExpiry, everyoneExpiry: everyoneExpiry)

        #expect(summary.quickStatusChange(for: Fixtures.partnerA, after: Self.written) == ownExpiry)
        #expect(summary.quickStatusChange(for: Fixtures.partnerA, after: ownExpiry) == everyoneExpiry)
        #expect(summary.quickStatusChange(for: Fixtures.partnerA, after: everyoneExpiry) == nil)
        #expect(try ownAndEveryone(ownExpiry: nil, everyoneExpiry: nil)
            .quickStatusChange(for: Fixtures.partnerA, after: Self.written) == nil)
    }

    // MARK: - Decoding

    @Test func test_decoding_fillsWhatsMissing_andIgnoresWhatsNew() throws {
        let sent: [String: Any] = [
            "pilotId": "pilot", "pilotFirstName": "Alex", "lastUpdated": 1_792_605_600, "appVersion": "3.1",
            "fieldFromANewerCrewLu": true,
        ]
        let status = try Fixtures.summary(sent).pilotStatus(partnerID: Fixtures.partnerA, at: Self.written)

        #expect(status.pilotFirstName == "Alex")
        #expect(status.displayStatus == .home)
        #expect(!status.isSleeping && !status.isHome && !status.isInFlight && !status.isOnDuty)
        #expect(status.upcomingCities.isEmpty)
        #expect(status.tripLegsJSON == nil)
        #expect(status.homeArrivalTime == nil)
        #expect(status.quickStatus == nil)
    }

    @Test(arguments: ["pilotId", "pilotFirstName", "lastUpdated", "appVersion"])
    func test_decoding_needsTheFieldsTheRecordNeeds(missing: String) throws {
        var sent = try Fixtures.json("home", partner: "A")
        sent[missing] = nil

        #expect(throws: DecodingError.self) { try Fixtures.summary(sent) }
    }

    // MARK: - Helpers

    /// Partner A's own Call Me over Sleeping for everyone, each until its expiry (nil for none).
    private func ownAndEveryone(ownExpiry: Date?, everyoneExpiry: Date?) throws -> CloudSummary {
        var sent = try Fixtures.json("quick-status-everyone", partner: "A")
        sent["quickStatusByPartner"] = [
            Fixtures.partnerA: [
                "status": "Call Me", "icon": "phone.fill",
                "expiry": ownExpiry.map { $0.timeIntervalSince1970 } ?? NSNull(),
            ] as [String: Any],
        ]
        sent["quickStatusExpiry"] = everyoneExpiry.map { $0.timeIntervalSince1970 } ?? NSNull()
        return try Fixtures.summary(sent)
    }

    /// Whether a status field holds what the summary sent: dates as seconds since 1970, and the
    /// display status as the words CrewLu sends.
    private static func isSame(_ value: Any, _ sent: Any) -> Bool {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let wrapped = mirror.children.first?.value else { return sent is NSNull }
            return isSame(wrapped, sent)
        }
        switch value {
        case let text as String: return sent as? String == text
        case let flag as Bool: return sent as? Bool == flag
        case let number as Int: return sent as? Int == number
        case let number as Double: return sent as? Double == number
        case let date as Date: return sent as? Double == date.timeIntervalSince1970
        case let list as [String]: return sent as? [String] == list
        case let status as PilotDisplayStatus: return sent as? String == status.rawDisplayString
        default: return false
        }
    }
}
