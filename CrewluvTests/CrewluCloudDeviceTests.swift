//
//  CrewluCloudDeviceTests.swift
//  CrewluvTests
//
//  This device on Crewlu Cloud: its key, its partner, and its reads (partner links piece 4 spec §5.1–§5.3)
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
final class CrewluCloudDeviceTests {
    private let defaultsName = "CrewluCloudDeviceTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let door = StandInPartnerDoor()
    private let keys = InMemoryDeviceKeyStore()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: defaultsName))
    }

    deinit {
        defaults.removePersistentDomain(forName: defaultsName)
    }

    /// A device on Crewlu Cloud as partner A.
    private func connectedDevice() -> CrewluCloudDevice {
        defaults.set(Make.partnerA, forKey: "partnerCloud.partnerID")
        keys.key = Make.key
        return CrewluCloudDevice(door: door, keys: keys, connection: PartnerConnection(defaults: defaults))
    }

    private func device() -> CrewluCloudDevice {
        CrewluCloudDevice(door: door, keys: keys, connection: PartnerConnection(defaults: defaults))
    }

    private static let joinedB = PartnerJoinAnswer(deviceID: "device-b", partnerID: Make.partnerB)

    // MARK: - Joining

    @Test func test_join_withoutAKey_usesAPendingKey_savedFirst() async throws {
        door.joinAnswers = [.success(Self.joinedB)]

        let joined = try await device().join(.invite("invite"), label: "iPhone")

        let pending = try #require(keys.pending)
        #expect(door.joins.map(\.key) == [pending])
        #expect(door.joins.map(\.link) == [.invite("invite")])
        #expect(door.joins.map(\.label) == ["iPhone"])
        #expect(pending.count == 64)
        #expect(keys.key == nil)
        #expect(joined == CrewluCloudDevice.Joined(partnerID: Make.partnerB, key: pending, isDeviceKey: false))
    }

    @Test func test_join_withThisDevicesKey() async throws {
        keys.key = Make.key
        door.joinAnswers = [.success(Self.joinedB)]

        let joined = try await device().join(.code("K7MQ2X"), label: "iPad")

        #expect(door.joins.map(\.key) == [Make.key])
        #expect(door.joins.map(\.link) == [.code("K7MQ2X")])
        #expect(joined == CrewluCloudDevice.Joined(partnerID: Make.partnerB, key: Make.key, isDeviceKey: true))
        #expect(keys.pending == nil)
    }

    @Test func test_join_keyAnotherPersonsDeviceHas_triesAgainWithAPendingKey() async throws {
        keys.key = Make.key
        door.joinAnswers = [.failure(.refused(.keyInUse)), .success(Self.joinedB)]

        let joined = try await device().join(.invite("invite"), label: "iPhone")

        let pending = try #require(keys.pending)
        #expect(door.joins.map(\.key) == [Make.key, pending])
        #expect(joined == CrewluCloudDevice.Joined(partnerID: Make.partnerB, key: pending, isDeviceKey: false))
        #expect(keys.key == Make.key)
    }

    @Test func test_join_reusesThePendingKeyAJoinThatDidntFinishKept() async throws {
        keys.key = Make.key
        keys.pending = "kept"
        door.joinAnswers = [.failure(.refused(.keyInUse)), .success(Self.joinedB)]

        _ = try await device().join(.invite("invite"), label: "iPhone")

        #expect(door.joins.map(\.key) == [Make.key, "kept"])
    }

    @Test func test_join_aPendingKeyAnotherPersonsDeviceHas_isReplaced() async throws {
        keys.pending = "kept"
        door.joinAnswers = [.failure(.refused(.keyInUse)), .success(Self.joinedB)]

        let joined = try await device().join(.invite("invite"), label: "iPhone")

        let pending = try #require(keys.pending)
        #expect(pending != "kept")
        #expect(door.joins.map(\.key) == ["kept", pending])
        #expect(joined.key == pending)
    }

    @Test func test_join_withThisDevicesKey_aKeptPendingKeyAnotherPersonsDeviceHas_isReplaced() async throws {
        keys.key = Make.key
        keys.pending = "kept"
        door.joinAnswers = [.failure(.refused(.keyInUse)), .failure(.refused(.keyInUse)), .success(Self.joinedB)]

        let joined = try await device().join(.invite("invite"), label: "iPhone")

        let pending = try #require(keys.pending)
        #expect(pending != "kept")
        #expect(door.joins.map(\.key) == [Make.key, "kept", pending])
        #expect(joined.key == pending)
        #expect(keys.key == Make.key)
    }

    @Test func test_join_thatDoesntFinish_keepsThePendingKey() async {
        await #expect(throws: PartnerDoorError.unavailable) { try await self.device().join(.invite("invite"), label: "iPhone") }

        #expect(keys.pending != nil)
        #expect(door.joins.count == 1)
    }

    @Test func test_join_keyThatCantBeSaved_sendsNothing() async {
        keys.savesFail = true

        await #expect(throws: PartnerDoorError.unavailable) { try await self.device().join(.invite("invite"), label: "iPhone") }

        #expect(door.joins.isEmpty)
    }

    @Test func test_join_keychainThatCantBeRead_sendsNothing() async {
        keys.readFails = true

        await #expect(throws: PartnerDoorError.unavailable) { try await self.device().join(.invite("invite"), label: "iPhone") }

        #expect(door.joins.isEmpty)
    }

    @Test func test_join_passesOnTheDoorsRefusal_andKeepsTheKeys() async {
        keys.key = Make.key
        door.joinAnswers = [.failure(.refused(.sharingEnded))]

        await #expect(throws: PartnerDoorError.refused(.sharingEnded)) { try await self.device().join(.invite("invite"), label: "iPhone") }

        #expect(keys.key == Make.key)
    }

    @Test func test_view_readsWithTheKeyThatJoined_askingForEverything() async throws {
        door.viewAnswers = [Make.noSummaryYet]
        let device = connectedDevice()
        device.since = "t1"
        let joined = CrewluCloudDevice.Joined(partnerID: Make.partnerA, key: "pending", isDeviceKey: false)

        _ = try await device.view(joined)

        #expect(door.views.map(\.key) == ["pending"])
        #expect(door.views.map(\.since) == [nil])
    }

    // MARK: - Switching and Cancelling

    @Test func test_switch_makesThePendingKeyThisDevicesKey_andTheOldDeviceLeaves() async {
        let device = connectedDevice()
        device.since = "t1"
        keys.pending = "pending"

        let switched = await device.switchTo(CrewluCloudDevice.Joined(partnerID: Make.partnerB, key: "pending", isDeviceKey: false))

        #expect(switched)
        #expect(keys.key == "pending")
        #expect(keys.pending == nil)
        #expect(device.partnerID == Make.partnerB)
        #expect(defaults.string(forKey: "partnerCloud.partnerID") == Make.partnerB)
        #expect(device.since == nil)
        #expect(door.leaves == [Make.key])
    }

    @Test func test_switch_withThisDevicesOwnKey_leavesNothing() async {
        keys.key = Make.key
        let device = device()

        _ = await device.switchTo(CrewluCloudDevice.Joined(partnerID: Make.partnerA, key: Make.key, isDeviceKey: true))

        #expect(device.partnerID == Make.partnerA)
        #expect(keys.key == Make.key)
        #expect(door.leaves.isEmpty)
    }

    @Test func test_switch_keyThatCantBeSaved_changesNothing() async {
        let device = connectedDevice()
        keys.pending = "pending"
        keys.savesFail = true

        let switched = await device.switchTo(CrewluCloudDevice.Joined(partnerID: Make.partnerB, key: "pending", isDeviceKey: false))

        #expect(!switched)
        #expect(keys.key == Make.key)
        #expect(device.partnerID == Make.partnerA)
        #expect(door.leaves.isEmpty)
    }

    @Test func test_aReadThatASwitchOvertook_bringsNothingBack() async throws {
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Make.summary())]
        door.holdsViews = true
        let device = connectedDevice()

        let read = Task { await device.read() }
        await eventually { door.views.count == 1 }
        _ = await device.switchTo(CrewluCloudDevice.Joined(partnerID: Make.partnerB, key: "pending", isDeviceKey: false))
        door.release()

        guard case .superseded = await read.value else {
            Issue.record("expected the read to bring nothing back")
            return
        }
    }

    @Test func test_cancel_leavesWithTheKeyThatJoined_andForgetsIt() async {
        let device = connectedDevice()
        keys.pending = "pending"

        await device.cancel(CrewluCloudDevice.Joined(partnerID: Make.partnerB, key: "pending", isDeviceKey: false))

        #expect(door.leaves == ["pending"])
        #expect(keys.pending == nil)
        #expect(keys.key == Make.key)
        #expect(device.partnerID == Make.partnerA)
    }

    // MARK: - Reads the Connection Changed Under

    @Test func test_sharingEnded_forAKeyReplacedMeanwhile_forgetsNothing() async {
        door.viewAnswers = [.failure(.refused(.sharingEnded))]
        door.holdsViews = true
        let device = connectedDevice()

        let read = Task { await device.read() }
        await eventually { door.views.count == 1 }
        device.forget()
        keys.key = "new"
        door.release()

        guard case .superseded = await read.value else {
            Issue.record("expected the read to bring nothing back")
            return
        }
        #expect(keys.key == "new")
    }
}
