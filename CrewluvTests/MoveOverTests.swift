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

    // MARK: - After an iCloud Read (§8.1)

    private static let code = HandOffCode(code: "K7MQ2X", expiresAt: Date(timeIntervalSince1970: 1_792_419_308))

    private static func summary(for partnerID: String = Make.partnerB, pilot: String = "pilot") throws -> Result<PartnerViewAnswer, PartnerDoorError> {
        Make.answer(updatedAt: "t1", try Make.summary(["pilotId": pilot]), partnerID: partnerID)
    }

    private static let noSummaryForB: Result<PartnerViewAnswer, PartnerDoorError> =
        .success(PartnerViewAnswer(partnerID: Make.partnerB, updatedAt: nil, content: .noSummaryYet))

    /// This device follows the pilot "pilot" through iCloud.
    private func followsPilot() {
        defaults.set("pilot", forKey: "partnerCloud.pilotID")
    }

    private func switched(_ next: MoveOver.Next) -> (joined: CrewluCloudDevice.Joined, answer: PartnerViewAnswer?)? {
        guard case .switchTo(let joined, let answer) = next else { return nil }
        return (joined, answer)
    }

    private func stays(_ next: MoveOver.Next) -> Bool {
        if case .stay = next { return true }
        return false
    }

    @Test func test_nothingToDo_staysOnICloud() async {
        followsPilot()

        #expect(stays(await moveOver().afterRead(ticket: nil)))

        #expect(door.views.isEmpty)
        #expect(door.joins.isEmpty)
    }

    @Test func test_aTicket_isRedeemed_andAStatusMeansTheSwitch() async throws {
        followsPilot()
        door.joinAnswers = [.success(Self.joinedB)]
        door.viewAnswers = [try Self.summary()]

        let next = await moveOver().afterRead(ticket: "ticket")

        let key = try #require(keys.key)
        let (joined, answer) = try #require(switched(next))
        #expect(joined == CrewluCloudDevice.Joined(partnerID: Make.partnerB, key: key, isDeviceKey: true))
        #expect(answer?.partnerID == Make.partnerB)
        #expect(door.joins.map(\.link) == [.code("ticket")])
        #expect(door.views.map(\.key) == [key])
        #expect(defaults.string(forKey: "partnerCloud.moveToPartnerID") == Make.partnerB)
    }

    @Test func test_aTicket_beforeTheFirstSummary_leavesTheMoveUnderWay() async throws {
        followsPilot()
        door.joinAnswers = [.success(Self.joinedB)]
        door.viewAnswers = [Self.noSummaryForB]

        #expect(stays(await moveOver().afterRead(ticket: "ticket")))

        #expect(keys.key != nil)
        #expect(defaults.string(forKey: "partnerCloud.moveToPartnerID") == Make.partnerB)
    }

    @Test func test_aMoveUnderWay_withAStatus_switches_withoutRedeemingAgain() async throws {
        followsPilot()
        keys.key = Make.key
        defaults.set(Make.partnerB, forKey: "partnerCloud.moveToPartnerID")
        door.viewAnswers = [try Self.summary()]

        let (joined, _) = try #require(switched(await moveOver().afterRead(ticket: "ticket")))

        #expect(joined == CrewluCloudDevice.Joined(partnerID: Make.partnerB, key: Make.key, isDeviceKey: true))
        #expect(door.joins.isEmpty)
    }

    @Test func test_aMoveUnderWay_switches_withNoPilotSavedFromICloud() async throws {
        keys.key = Make.key
        defaults.set(Make.partnerB, forKey: "partnerCloud.moveToPartnerID")
        door.viewAnswers = [try Self.summary()]

        let (joined, _) = try #require(switched(await moveOver().afterRead(ticket: nil)))

        #expect(joined.partnerID == Make.partnerB)
    }

    @Test func test_aMoveUnderWay_beforeTheFirstSummary_waits() async {
        followsPilot()
        keys.key = Make.key
        defaults.set(Make.partnerB, forKey: "partnerCloud.moveToPartnerID")
        door.viewAnswers = [Self.noSummaryForB]

        #expect(stays(await moveOver().afterRead(ticket: "ticket")))

        #expect(door.joins.isEmpty)
        #expect(keys.key == Make.key)
    }

    @Test func test_aMoveUnderWay_thatCantReachCrewluCloud_staysWithoutRedeemingAgain() async {
        followsPilot()
        keys.key = Make.key
        defaults.set(Make.partnerB, forKey: "partnerCloud.moveToPartnerID")
        door.viewAnswers = [.failure(.unavailable)]

        #expect(stays(await moveOver().afterRead(ticket: "ticket")))

        #expect(door.joins.isEmpty)
        #expect(keys.key == Make.key)
    }

    @Test func test_aMoveUnderWay_whoseDeviceIsGone_redeemsTheTicketWithANewKey() async throws {
        followsPilot()
        keys.key = Make.key
        defaults.set(Make.partnerB, forKey: "partnerCloud.moveToPartnerID")
        door.viewAnswers = [.failure(.refused(.sharingEnded)), try Self.summary()]
        door.joinAnswers = [.success(Self.joinedB)]

        let (joined, _) = try #require(switched(await moveOver().afterRead(ticket: "ticket")))

        #expect(joined.key != Make.key)
        #expect(keys.key == joined.key)
        #expect(door.joins.map(\.key) == [joined.key])
    }

    @Test func test_aKeyAReinstallLeft_forThisPilot_switches() async throws {
        followsPilot()
        keys.key = Make.key
        door.viewAnswers = [try Self.summary()]

        let (joined, _) = try #require(switched(await moveOver().afterRead(ticket: nil)))

        #expect(joined.key == Make.key)
    }

    @Test func test_aKeyAReinstallLeft_forAnotherPilot_givesWayToTheTicket() async throws {
        followsPilot()
        keys.key = Make.key
        door.viewAnswers = [try Self.summary(for: Make.partnerA, pilot: "sam"), try Self.summary()]
        door.joinAnswers = [.failure(.refused(.keyInUse)), .success(Self.joinedB)]

        let (joined, _) = try #require(switched(await moveOver().afterRead(ticket: "ticket")))

        #expect(joined.key != Make.key)
        #expect(door.joins.map(\.key) == [Make.key, joined.key])
    }

    @Test(arguments: [PartnerDoorError.refused(.tooManyDevices), .refused(.tryLater), .refused(.invalidInput), .unavailable])
    func test_aTicketThatCantBeRedeemedNow_staysOnICloud(error: PartnerDoorError) async {
        followsPilot()
        keys.copy = "copy"
        door.joinAnswers = [.failure(error)]

        #expect(stays(await moveOver().afterRead(ticket: "ticket")))

        #expect(door.views.isEmpty)
        #expect(door.handOffs.isEmpty)
        #expect(defaults.string(forKey: "partnerCloud.moveToPartnerID") == nil)
    }

    @Test func test_aMoveOvertakenByASwitch_changesNothing() async throws {
        followsPilot()
        door.joinAnswers = [.success(Self.joinedB)]
        door.viewAnswers = [try Self.summary()]
        door.holdsViews = true
        let device = device()
        let moveOver = moveOver(device)

        let moving = Task { await moveOver.afterRead(ticket: "ticket") }
        await eventually { door.views.count == 1 }
        _ = device.switchTo(CrewluCloudDevice.Joined(partnerID: Make.partnerA, key: "joined", isDeviceKey: true))
        door.release()

        #expect(stays(await moving.value))
    }

    @Test func test_aRedeemOvertakenByASwitch_startsNoMove() async {
        followsPilot()
        door.joinAnswers = [.success(Self.joinedB)]
        let device = device()
        door.whileJoining = { _ = device.switchTo(CrewluCloudDevice.Joined(partnerID: Make.partnerA, key: "joined", isDeviceKey: true)) }

        #expect(stays(await moveOver(device).afterRead(ticket: "ticket")))

        #expect(defaults.string(forKey: "partnerCloud.moveToPartnerID") == nil)
        #expect(door.views.isEmpty)
    }

    // MARK: - Following Another of This Partner's Devices (§8.3)

    @Test func test_aUsedTicket_followsAnotherDevice() async throws {
        followsPilot()
        keys.copy = "copy"
        door.joinAnswers = [.failure(.refused(.sharingEnded)), .success(Self.joinedB)]
        door.viewAnswers = [try Self.summary(), try Self.summary()]
        door.handOffAnswers = [.success(Self.code)]

        let (joined, _) = try #require(switched(await moveOver().afterRead(ticket: "ticket")))

        #expect(door.joins.map(\.link) == [.code("ticket"), .code("K7MQ2X")])
        #expect(door.handOffs == ["copy"])
        #expect(door.views.map(\.key) == ["copy", joined.key])
        #expect(joined.key != "copy")
        #expect(keys.copy == "copy")
    }

    @Test func test_noTicket_followsAnotherDevice() async throws {
        followsPilot()
        keys.copy = "copy"
        door.joinAnswers = [.success(Self.joinedB)]
        door.viewAnswers = [try Self.summary(), try Self.summary()]
        door.handOffAnswers = [.success(Self.code)]

        let (joined, _) = try #require(switched(await moveOver().afterRead(ticket: nil)))

        #expect(joined.partnerID == Make.partnerB)
        #expect(defaults.string(forKey: "partnerCloud.moveToPartnerID") == Make.partnerB)
    }

    @Test func test_anotherDevicesCode_beforeTheFirstSummary_leavesTheMoveUnderWay() async throws {
        followsPilot()
        keys.copy = "copy"
        door.joinAnswers = [.success(Self.joinedB)]
        door.viewAnswers = [try Self.summary(), Self.noSummaryForB]
        door.handOffAnswers = [.success(Self.code)]

        #expect(stays(await moveOver().afterRead(ticket: nil)))

        #expect(defaults.string(forKey: "partnerCloud.moveToPartnerID") == Make.partnerB)
    }

    @Test func test_aCopyForAnotherPilot_isntFollowed() async throws {
        followsPilot()
        keys.copy = "copy"
        door.viewAnswers = [try Self.summary(pilot: "sam")]

        #expect(stays(await moveOver().afterRead(ticket: nil)))

        #expect(door.handOffs.isEmpty)
        #expect(keys.copy == "copy")
    }

    @Test func test_aCopyWhoseDeviceIsGone_isForgotten() async {
        followsPilot()
        keys.copy = "copy"
        door.viewAnswers = [.failure(.refused(.sharingEnded))]

        #expect(stays(await moveOver().afterRead(ticket: nil)))

        #expect(keys.copy == nil)
    }

    @Test func test_aCopyThatCantMakeACode_isForgotten_whenItsDeviceIsGone() async throws {
        followsPilot()
        keys.copy = "copy"
        door.viewAnswers = [try Self.summary()]
        door.handOffAnswers = [.failure(.refused(.sharingEnded))]

        #expect(stays(await moveOver().afterRead(ticket: nil)))

        #expect(keys.copy == nil)
        #expect(door.joins.isEmpty)
    }

    @Test func test_aCopyOfThisDevicesOwnKey_isntFollowed() async {
        followsPilot()
        keys.key = Make.key
        keys.copy = Make.key
        door.viewAnswers = [Self.noSummaryForB]

        #expect(stays(await moveOver().afterRead(ticket: nil)))

        #expect(door.views.map(\.key) == [Make.key])
        #expect(door.handOffs.isEmpty)
    }

    @Test func test_aCodeOvertakenByASwitch_isntRedeemed() async throws {
        followsPilot()
        keys.copy = "copy"
        door.viewAnswers = [try Self.summary()]
        door.handOffAnswers = [.success(Self.code)]
        door.holdsHandOffs = true
        let device = device()
        let moveOver = moveOver(device)

        let moving = Task { await moveOver.afterRead(ticket: nil) }
        await eventually { door.handOffs.count == 1 }
        _ = device.switchTo(CrewluCloudDevice.Joined(partnerID: Make.partnerA, key: "joined", isDeviceKey: true))
        door.release()

        #expect(stays(await moving.value))
        #expect(door.joins.isEmpty)
    }

    @Test func test_aCodesRedeemOvertakenByASwitch_startsNoMove() async throws {
        followsPilot()
        keys.copy = "copy"
        door.viewAnswers = [try Self.summary()]
        door.handOffAnswers = [.success(Self.code)]
        door.joinAnswers = [.success(Self.joinedB)]
        let device = device()
        door.whileJoining = { _ = device.switchTo(CrewluCloudDevice.Joined(partnerID: Make.partnerA, key: "joined", isDeviceKey: true)) }

        #expect(stays(await moveOver(device).afterRead(ticket: nil)))

        #expect(defaults.string(forKey: "partnerCloud.moveToPartnerID") == nil)
        #expect(door.views.map(\.key) == ["copy"])
    }

    // MARK: - When the Share Is Gone (§8.4)

    private func ended(_ next: MoveOver.Next) -> Bool? {
        guard case .ended(let leftBehind) = next else { return nil }
        return leftBehind
    }

    @Test func test_shareGone_duringAMove_switchesAtOnce() async throws {
        keys.key = Make.key
        defaults.set(Make.partnerB, forKey: "partnerCloud.moveToPartnerID")
        door.viewAnswers = [Self.noSummaryForB]

        let (joined, answer) = try #require(switched(await moveOver().afterShareGone()))

        #expect(joined == CrewluCloudDevice.Joined(partnerID: Make.partnerB, key: Make.key, isDeviceKey: true))
        #expect(answer != nil)
    }

    @Test func test_shareGone_duringAMove_switchesEvenWhenCrewluCloudCantBeReached() async throws {
        keys.key = Make.key
        defaults.set(Make.partnerB, forKey: "partnerCloud.moveToPartnerID")

        let (joined, answer) = try #require(switched(await moveOver().afterShareGone()))

        #expect(joined == CrewluCloudDevice.Joined(partnerID: Make.partnerB, key: Make.key, isDeviceKey: true))
        #expect(answer == nil)
    }

    @Test func test_shareGone_duringAMoveCrewluCloudEndedToo_ends() async {
        keys.key = Make.key
        defaults.set(Make.partnerB, forKey: "partnerCloud.moveToPartnerID")
        door.viewAnswers = [.failure(.refused(.sharingEnded))]

        #expect(ended(await moveOver().afterShareGone()) == false)
        #expect(keys.key == nil)
    }

    @Test func test_shareGone_withAKeyAReinstallLeft_doesntSwitchToIt() async {
        followsPilot()
        keys.key = Make.key

        #expect(ended(await moveOver().afterShareGone()) == false)
        #expect(door.views.isEmpty)
    }

    @Test func test_shareGone_followsAnotherDevice_beforeTheWelcomeScreen() async throws {
        followsPilot()
        keys.copy = "copy"
        door.viewAnswers = [try Self.summary(), Self.noSummaryForB]
        door.handOffAnswers = [.success(Self.code)]
        door.joinAnswers = [.success(Self.joinedB)]

        let (joined, answer) = try #require(switched(await moveOver().afterShareGone()))

        #expect(joined.partnerID == Make.partnerB)
        #expect(answer != nil)
    }

    @Test func test_shareGone_withAnotherDeviceThatCantBeFollowedNow_leavesThisOneBehind() async throws {
        followsPilot()
        keys.copy = "copy"
        door.viewAnswers = [try Self.summary()]

        #expect(ended(await moveOver().afterShareGone()) == true)
    }

    @Test func test_shareGone_withoutAnotherDevice_ends() async {
        followsPilot()

        #expect(ended(await moveOver().afterShareGone()) == false)
    }

    @Test func test_shareGone_withAnotherDeviceOfAnotherPilot_ends() async throws {
        followsPilot()
        keys.copy = "copy"
        door.viewAnswers = [try Self.summary(pilot: "sam")]

        #expect(ended(await moveOver().afterShareGone()) == false)
    }

    @Test func test_shareGone_whenTheCopysPilotCantBeChecked_ends() async {
        followsPilot()
        keys.copy = "copy"

        #expect(ended(await moveOver().afterShareGone()) == false)
    }
}
