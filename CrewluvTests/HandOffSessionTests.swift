//
//  HandOffSessionTests.swift
//  CrewluvTests
//
//  Use on Another Device: making a code, and what happens when it can't be made
//  (partner links piece 4 spec §7.5, §7.6)
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
final class HandOffSessionTests {
    private let defaultsName = "HandOffSessionTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let door = StandInPartnerDoor()
    private let keys = InMemoryDeviceKeyStore()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: defaultsName))
    }

    deinit {
        defaults.removePersistentDomain(forName: defaultsName)
    }

    /// A device on Crewlu Cloud as partner A, which saw the pilot as Dad.
    private func connectedSource() -> PilotStatusSource {
        defaults.set(Make.partnerA, forKey: "partnerCloud.partnerID")
        defaults.set("Dad", forKey: "partnerCloud.pilotName")
        keys.key = Make.key
        return PilotStatusSource(
            iCloud: StandInICloud(), door: door, keys: keys, defaults: defaults,
            notifier: RecordingNotifier(), iCloudShareEnded: {}
        )
    }

    private static let code = HandOffCode(code: "K7MQ2X", expiresAt: Date(timeIntervalSince1970: 1_792_419_308))

    @Test func test_makesACode_withThisDevicesKey() async {
        door.handOffAnswers = [.success(Self.code)]
        let session = HandOffSession(source: connectedSource())
        #expect(session.state == .making)

        await session.makeCode()

        #expect(session.state == .ready(Self.code))
        #expect(door.handOffs == [Make.key])
    }

    @Test func test_aNewCode_replacesTheLastOne() async {
        let newCode = HandOffCode(code: "ABC234", expiresAt: Date(timeIntervalSince1970: 1_792_419_908))
        door.handOffAnswers = [.success(Self.code), .success(newCode)]
        let session = HandOffSession(source: connectedSource())

        await session.makeCode()
        await session.makeCode()

        #expect(session.state == .ready(newCode))
        #expect(door.handOffs.count == 2)
    }

    @Test func test_withoutAConnection_saysSo_andStaysConnected() async {
        door.handOffAnswers = [.failure(.unavailable)]
        let source = connectedSource()
        let session = HandOffSession(source: source)

        await session.makeCode()

        #expect(session.state == .couldntMake)
        #expect(source.isOnCrewluCloud)
        #expect(keys.key == Make.key)
    }

    @Test func test_sharingEnded_endsSharing_andClosesTheSheet() async {
        door.handOffAnswers = [.failure(.refused(.sharingEnded))]
        let source = connectedSource()
        let session = HandOffSession(source: source)

        await session.makeCode()

        #expect(session.state == .sharingEnded)
        #expect(!source.isOnCrewluCloud)
        #expect(keys.key == nil)
        #expect(source.sharingEndedWith == "Dad")
        #expect(source.lastUpdate?.outcome == .sharingEnded)
    }

    @Test func test_sharingEnded_forAKeyReplacedMeanwhile_endsNothing() async {
        door.handOffAnswers = [.failure(.refused(.sharingEnded))]
        door.holdsHandOffs = true
        let source = connectedSource()
        keys.pending = "pending"
        let session = HandOffSession(source: source)

        let making = Task { await session.makeCode() }
        await eventually { door.handOffs.count == 1 }
        _ = source.device.switchTo(CrewluCloudDevice.Joined(partnerID: Make.partnerB, key: "pending", isDeviceKey: false))
        door.release()
        await making.value

        #expect(session.state == .couldntMake)
        #expect(source.crewluCloudPartnerID == Make.partnerB)
        #expect(keys.key == "pending")
        #expect(source.sharingEndedWith == nil)
    }

    @Test func test_aNewCode_showsMaking_whileItWaits() async {
        door.handOffAnswers = [.success(Self.code), .success(Self.code)]
        let session = HandOffSession(source: connectedSource())
        await session.makeCode()
        door.holdsHandOffs = true

        let making = Task { await session.makeCode() }
        await eventually { door.handOffs.count == 2 }
        #expect(session.state == .making)
        door.release()
        await making.value

        #expect(session.state == .ready(Self.code))
    }

    @Test func test_withoutAKey_saysItCouldntMakeOne() async {
        let source = connectedSource()
        keys.key = nil
        let session = HandOffSession(source: source)

        await session.makeCode()

        #expect(session.state == .couldntMake)
        #expect(door.handOffs.isEmpty)
    }
}
