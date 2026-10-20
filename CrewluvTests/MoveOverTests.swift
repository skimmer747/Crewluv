//
//  MoveOverTests.swift
//  CrewluvTests
//
//  Moving this device from iCloud to Crewlu Cloud by itself (partner links piece 4 spec §8)
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
final class MoveOverTests {
    private let defaultsName = "MoveOverTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let door = StandInPartnerDoor()
    private let keys = InMemoryDeviceKeyStore()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: defaultsName))
    }

    deinit {
        defaults.removePersistentDomain(forName: defaultsName)
    }

    private func device() -> CrewluCloudDevice {
        CrewluCloudDevice(door: door, keys: keys, connection: PartnerConnection(defaults: defaults))
    }

    /// A device on Crewlu Cloud as partner A.
    private func connectedDevice() -> CrewluCloudDevice {
        defaults.set(Make.partnerA, forKey: "partnerCloud.partnerID")
        keys.key = Make.key
        return device()
    }

    private func moveOver(_ device: CrewluCloudDevice? = nil) -> MoveOver {
        MoveOver(door: door, keys: keys, connection: PartnerConnection(defaults: defaults), device: device ?? self.device(), label: "iPhone")
    }

    private static let joinedB = PartnerJoinAnswer(deviceID: "device-b", partnerID: Make.partnerB)

    // MARK: - This Device's Key, Unconnected

    @Test func test_unconnectedKey_none() async {
        guard case .noKey = await moveOver().readUnconnectedKey() else {
            Issue.record("expected no key")
            return
        }
        #expect(door.views.isEmpty)
    }

    @Test func test_unconnectedKey_answered_asksForEverything() async throws {
        keys.key = Make.key
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Make.summary(), partnerID: Make.partnerB)]

        guard case .answer(let key, let answer) = await moveOver().readUnconnectedKey() else {
            Issue.record("expected an answer")
            return
        }
        #expect(key == Make.key)
        #expect(answer.partnerID == Make.partnerB)
        #expect(door.views.map(\.since) == [nil])
    }

    @Test func test_unconnectedKey_gone_forgetsTheKey_theMove_andACopyOfIt() async {
        keys.key = Make.key
        keys.copy = Make.key
        defaults.set(Make.partnerB, forKey: "partnerCloud.moveToPartnerID")
        door.viewAnswers = [.failure(.refused(.sharingEnded))]

        guard case .gone = await moveOver().readUnconnectedKey() else {
            Issue.record("expected the key's device to be gone")
            return
        }
        #expect(keys.key == nil)
        #expect(keys.copy == nil)
        #expect(defaults.string(forKey: "partnerCloud.moveToPartnerID") == nil)
    }

    @Test func test_unconnectedKey_gone_keepsACopyOfAnotherDevicesKey() async {
        keys.key = Make.key
        keys.copy = "other"
        door.viewAnswers = [.failure(.refused(.sharingEnded))]

        _ = await moveOver().readUnconnectedKey()

        #expect(keys.key == nil)
        #expect(keys.copy == "other")
    }

    @Test func test_unconnectedKey_unreachable_keepsTheKey() async {
        keys.key = Make.key

        guard case .unavailable = await moveOver().readUnconnectedKey() else {
            Issue.record("expected unavailable")
            return
        }
        #expect(keys.key == Make.key)
    }

    @Test func test_unconnectedKey_thatASwitchOvertook_forgetsNothing() async {
        keys.key = Make.key
        door.viewAnswers = [.failure(.refused(.sharingEnded))]
        door.holdsViews = true
        let device = device()
        let moveOver = moveOver(device)

        let reading = Task { await moveOver.readUnconnectedKey() }
        await eventually { door.views.count == 1 }
        _ = device.switchTo(CrewluCloudDevice.Joined(partnerID: Make.partnerB, key: Make.key, isDeviceKey: true))
        door.release()

        guard case .unavailable = await reading.value else {
            Issue.record("expected the read to bring nothing back")
            return
        }
        #expect(keys.key == Make.key)
    }

    @Test func test_unconnectedKey_answeredAfterASwitch_bringsNothingBack() async throws {
        keys.key = Make.key
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Make.summary(), partnerID: Make.partnerB)]
        door.holdsViews = true
        let device = device()
        let moveOver = moveOver(device)

        let reading = Task { await moveOver.readUnconnectedKey() }
        await eventually { door.views.count == 1 }
        _ = device.switchTo(CrewluCloudDevice.Joined(partnerID: Make.partnerA, key: "joined", isDeviceKey: false))
        door.release()

        guard case .unavailable = await reading.value else {
            Issue.record("expected the read to bring nothing back")
            return
        }
    }

    @Test func test_redeemForMove_withThisDevicesKey() async throws {
        keys.key = Make.key
        door.joinAnswers = [.success(Self.joinedB)]

        let joined = try await moveOver().redeemForMove("ticket")

        #expect(joined == CrewluCloudDevice.Joined(partnerID: Make.partnerB, key: Make.key, isDeviceKey: true))
        #expect(door.joins.map(\.link) == [.code("ticket")])
        #expect(door.joins.map(\.label) == ["iPhone"])
        #expect(keys.pending == nil)
    }

    @Test func test_redeemForMove_withoutAKey_savesANewOneFirst() async throws {
        door.joinAnswers = [.success(Self.joinedB)]

        let joined = try await moveOver().redeemForMove("ticket")

        let key = try #require(keys.key)
        #expect(key.count == 64)
        #expect(door.joins.map(\.key) == [key])
        #expect(joined.key == key)
    }

    @Test func test_redeemForMove_aKeyAnotherPersonsDeviceHas_getsANewOne_andOneMoreTry() async throws {
        keys.key = Make.key
        door.joinAnswers = [.failure(.refused(.keyInUse)), .success(Self.joinedB)]

        let joined = try await moveOver().redeemForMove("ticket")

        let key = try #require(keys.key)
        #expect(key != Make.key)
        #expect(door.joins.map(\.key) == [Make.key, key])
        #expect(joined.key == key)
    }

    @Test func test_redeemForMove_whileConnected_makesNoNewKey() async {
        let moveOver = moveOver(connectedDevice())
        door.joinAnswers = [.failure(.refused(.keyInUse))]

        await #expect(throws: PartnerDoorError.unavailable) { try await moveOver.redeemForMove("ticket") }

        #expect(keys.key == Make.key)
    }

    @Test func test_redeemForMove_passesOnTheDoorsRefusal_andKeepsTheKey() async {
        keys.key = Make.key
        door.joinAnswers = [.failure(.refused(.sharingEnded))]

        await #expect(throws: PartnerDoorError.refused(.sharingEnded)) { try await self.moveOver().redeemForMove("ticket") }

        #expect(keys.key == Make.key)
    }
}
