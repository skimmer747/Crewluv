//
//  PartnerJoinerTests.swift
//  CrewluvTests
//
//  Joining with an invite link or a code: every row of partner links piece 4 spec §7.2's table,
//  and §7.3's messages
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
final class PartnerJoinerTests {
    private let defaultsName = "PartnerJoinerTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let door = StandInPartnerDoor()
    private let iCloud = StandInICloud()
    private let keys = InMemoryDeviceKeyStore()
    private let connects = Counter()
    private let iCloudForgets = Counter()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: defaultsName))
    }

    deinit {
        defaults.removePersistentDomain(forName: defaultsName)
    }

    private func makeJoiner() -> (PartnerJoiner, PilotStatusSource) {
        let source = PilotStatusSource(
            iCloud: iCloud, door: door, keys: keys, defaults: defaults, notifier: RecordingNotifier(),
            iCloudShareEnded: {}, didConnect: { [connects] in connects.count += 1 },
            forgetICloudShare: { [iCloudForgets] in iCloudForgets.count += 1 }
        )
        return (PartnerJoiner(source: source, defaults: defaults, deviceModel: "iPhone"), source)
    }

    /// This device on Crewlu Cloud as partner A, following the pilot "pilot", whom it calls Dad.
    private func onCrewluCloud() {
        defaults.set(Make.partnerA, forKey: "partnerCloud.partnerID")
        keys.key = Make.key
        followsPilot()
    }

    /// This device on iCloud, following the pilot "pilot", whom it calls Dad.
    private func onICloud() {
        defaults.set("_owner", forKey: "SharedZoneOwner")
        followsPilot()
    }

    private func followsPilot() {
        defaults.set("pilot", forKey: "partnerCloud.pilotID")
        defaults.set("Dad", forKey: "partnerCloud.pilotName")
    }

    private static let joinedB = PartnerJoinAnswer(deviceID: "device-b", partnerID: Make.partnerB)

    private static func summaryFromSam() throws -> CloudSummary {
        try Make.summary(["pilotId": "sam", "pilotFirstName": "Sam"])
    }

    // MARK: - §7.2's Table

    @Test func test_notConnected_connects() async throws {
        door.joinAnswers = [.success(Self.joinedB)]
        door.viewAnswers = [
            Make.answer(updatedAt: "t1", try Make.summary(), partnerID: Make.partnerB),
            Make.answer(updatedAt: "t1", try Make.summary(), partnerID: Make.partnerB),
        ]
        let (joiner, source) = makeJoiner()

        #expect(await joiner.join(.invite("invite")))

        let key = try #require(door.joins.first?.key)
        #expect(source.crewluCloudPartnerID == Make.partnerB)
        #expect(keys.key == key)
        #expect(source.reading != nil)
        #expect(connects.count == 1)
        #expect(joiner.message == nil)
        #expect(!joiner.isConnecting)
    }

    @Test func test_onCrewluCloud_theSameDevice_changesNothing() async throws {
        onCrewluCloud()
        door.joinAnswers = [.success(PartnerJoinAnswer(deviceID: "device-a", partnerID: Make.partnerA))]
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Make.summary())]
        let (joiner, source) = makeJoiner()

        #expect(await joiner.join(.invite("invite")))

        #expect(door.joins.map(\.key) == [Make.key])
        #expect(door.views.map(\.key) == [Make.key])
        #expect(source.crewluCloudPartnerID == Make.partnerA)
        #expect(keys.key == Make.key)
        #expect(door.leaves.isEmpty)
        #expect(connects.count == 0)
    }

    @Test func test_onCrewluCloud_theSamePilot_switchesQuietly() async throws {
        onCrewluCloud()
        defaults.set(Data([1]), forKey: "LastSeenPilotSnapshot")
        door.joinAnswers = [.failure(.refused(.keyInUse)), .success(Self.joinedB)]
        door.viewAnswers = [
            Make.answer(updatedAt: "t1", try Make.summary(), partnerID: Make.partnerB),
            Make.answer(updatedAt: "t1", try Make.summary(), partnerID: Make.partnerB),
        ]
        let (joiner, source) = makeJoiner()

        #expect(await joiner.join(.invite("invite")))

        let pending = try #require(door.joins.last?.key)
        #expect(joiner.switchQuestion == nil)
        #expect(source.crewluCloudPartnerID == Make.partnerB)
        #expect(keys.key == pending)
        #expect(door.leaves == [Make.key])
        #expect(defaults.data(forKey: "LastSeenPilotSnapshot") == Data([1]))
    }

    @Test func test_onICloud_theSamePilot_switchesQuietly() async throws {
        onICloud()
        door.joinAnswers = [.success(Self.joinedB)]
        door.viewAnswers = [
            Make.answer(updatedAt: "t1", try Make.summary(), partnerID: Make.partnerB),
            Make.answer(updatedAt: "t1", try Make.summary(), partnerID: Make.partnerB),
        ]
        let (joiner, source) = makeJoiner()

        #expect(await joiner.join(.code("K7MQ2X")))

        #expect(joiner.switchQuestion == nil)
        #expect(source.isOnCrewluCloud)
        #expect(iCloudForgets.count == 1)
        #expect(door.joins.map(\.link) == [.code("K7MQ2X")])
    }

    @Test func test_anotherPilot_asks_andSwitchingSwitches() async throws {
        onCrewluCloud()
        defaults.set(Data([1]), forKey: "LastSeenPilotSnapshot")
        door.joinAnswers = [.failure(.refused(.keyInUse)), .success(Self.joinedB)]
        door.viewAnswers = [
            Make.answer(updatedAt: "t1", try Self.summaryFromSam(), partnerID: Make.partnerB),
            Make.answer(updatedAt: "t1", try Self.summaryFromSam(), partnerID: Make.partnerB),
        ]
        let (joiner, source) = makeJoiner()

        let join = Task { await joiner.join(.invite("invite")) }
        await eventually { joiner.switchQuestion != nil }
        #expect(joiner.switchQuestion == SwitchQuestion(newPilot: "Sam", currentPilot: "Dad", deviceModel: "iPhone"))
        joiner.answerSwitch(true)

        #expect(await join.value)
        #expect(joiner.switchQuestion == nil)
        #expect(source.crewluCloudPartnerID == Make.partnerB)
        #expect(door.leaves == [Make.key])
        #expect(defaults.data(forKey: "LastSeenPilotSnapshot") == nil)
        #expect(defaults.string(forKey: "partnerCloud.pilotID") == "sam")
    }

    @Test func test_anotherPilot_isAskedAbout_byTheNameThisPartnerWillSee() async throws {
        onCrewluCloud()
        door.joinAnswers = [.failure(.refused(.keyInUse)), .success(Self.joinedB)]
        door.viewAnswers = [Make.answer(
            updatedAt: "t1",
            try Make.summary(["pilotId": "sam", "pilotFirstName": "Sam", "displayNameByPartner": [Make.partnerB: "Captain Sam"]]),
            partnerID: Make.partnerB
        )]
        let (joiner, _) = makeJoiner()

        let join = Task { await joiner.join(.invite("invite")) }
        await eventually { joiner.switchQuestion != nil }
        #expect(joiner.switchQuestion?.newPilot == "Captain Sam")
        joiner.answerSwitch(false)
        #expect(await !join.value)
    }

    @Test func test_anotherPilot_cancelled_leavesWithTheNewKey_andForgetsIt() async throws {
        onCrewluCloud()
        door.joinAnswers = [.failure(.refused(.keyInUse)), .success(Self.joinedB)]
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Self.summaryFromSam(), partnerID: Make.partnerB)]
        let (joiner, source) = makeJoiner()

        let join = Task { await joiner.join(.invite("invite")) }
        await eventually { joiner.switchQuestion != nil }
        joiner.answerSwitch(false)

        #expect(await !join.value)
        let pending = try #require(door.joins.last?.key)
        #expect(door.leaves == [pending])
        #expect(keys.pending == nil)
        #expect(keys.key == Make.key)
        #expect(source.crewluCloudPartnerID == Make.partnerA)
        #expect(joiner.message == nil)
    }

    @Test func test_anotherPilot_cancelled_whenThisDevicesKeyJoinedAnew_endsSharingWithTheLastOne() async throws {
        onCrewluCloud()
        door.joinAnswers = [.success(Self.joinedB)]
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Self.summaryFromSam(), partnerID: Make.partnerB)]
        let (joiner, source) = makeJoiner()

        let join = Task { await joiner.join(.invite("invite")) }
        await eventually { joiner.switchQuestion != nil }
        joiner.answerSwitch(false)

        #expect(await !join.value)
        #expect(door.leaves == [Make.key])
        #expect(!source.isOnCrewluCloud)
        #expect(keys.key == nil)
        #expect(source.sharingEndedWith == "Dad")
        #expect(source.lastUpdate?.outcome == .sharingEnded)
    }

    @Test func test_anotherPilot_cancelled_onICloud_whenALeftoverKeyJoinedAnew_endsNothing() async throws {
        onICloud()
        keys.key = Make.key
        door.joinAnswers = [.success(Self.joinedB)]
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Self.summaryFromSam(), partnerID: Make.partnerB)]
        let (joiner, source) = makeJoiner()

        let join = Task { await joiner.join(.invite("invite")) }
        await eventually { joiner.switchQuestion != nil }
        joiner.answerSwitch(false)

        #expect(await !join.value)
        #expect(door.leaves == [Make.key])
        #expect(source.sharingEndedWith == nil)
        #expect(source.lastUpdate == nil)
        #expect(defaults.string(forKey: "partnerCloud.pilotID") == "pilot")
    }

    @Test func test_followingAPilotNotSavedYet_readsThemFirst_thenAsks() async throws {
        defaults.set("_owner", forKey: "SharedZoneOwner")
        iCloud.results = [.success(try Make.iCloud(lastUpdated: 1, displayName: "Dad"))]
        door.joinAnswers = [.success(Self.joinedB)]
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Self.summaryFromSam(), partnerID: Make.partnerB)]
        let (joiner, _) = makeJoiner()

        let join = Task { await joiner.join(.invite("invite")) }
        await eventually { joiner.switchQuestion != nil }

        #expect(joiner.switchQuestion == SwitchQuestion(newPilot: "Sam", currentPilot: "Dad", deviceModel: "iPhone"))
        joiner.answerSwitch(false)
        #expect(await !join.value)
    }

    @Test func test_anotherPilot_onICloud_asksToo() async throws {
        onICloud()
        door.joinAnswers = [.success(Self.joinedB)]
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Self.summaryFromSam(), partnerID: Make.partnerB)]
        let (joiner, _) = makeJoiner()

        let join = Task { await joiner.join(.invite("invite")) }
        await eventually { joiner.switchQuestion != nil }
        joiner.answerSwitch(false)

        #expect(await !join.value)
        #expect(iCloudForgets.count == 0)
    }

    @Test func test_noStatusYet_switchesWithoutAsking() async throws {
        onCrewluCloud()
        door.joinAnswers = [.failure(.refused(.keyInUse)), .success(Self.joinedB)]
        door.viewAnswers = [
            .success(PartnerViewAnswer(partnerID: Make.partnerB, updatedAt: nil, content: .noSummaryYet)),
            .success(PartnerViewAnswer(partnerID: Make.partnerB, updatedAt: nil, content: .noSummaryYet)),
        ]
        let (joiner, source) = makeJoiner()

        #expect(await joiner.join(.invite("invite")))

        #expect(joiner.switchQuestion == nil)
        #expect(source.crewluCloudPartnerID == Make.partnerB)
    }

    // MARK: - §7.3's Messages

    @Test(arguments: [
        (PartnerDoorError.refused(.sharingEnded), PartnerLink.invite("invite"), JoinMessage.inviteNotWorking(stillConnectedTo: nil)),
        (.refused(.sharingEnded), .code("K7MQ2X"), .codeNotWorking),
        (.refused(.tooManyDevices), .invite("invite"), .tooManyDevices),
        (.refused(.tryLater), .code("K7MQ2X"), .tooManyTries),
        (.refused(.invalidInput), .invite("invite"), .notAnInviteLink),
        (.unavailable, .invite("invite"), .couldntConnect),
    ])
    func test_whatDidntConnect_isSaid(error: PartnerDoorError, link: PartnerLink, expected: JoinMessage) async {
        door.joinAnswers = [.failure(error)]
        let (joiner, source) = makeJoiner()

        #expect(await !joiner.join(link))

        #expect(joiner.message == expected)
        #expect(!source.isOnCrewluCloud)
    }

    @Test func test_aDeadInvite_whileFollowingAPilot_saysSo() async {
        onCrewluCloud()
        door.joinAnswers = [.failure(.refused(.sharingEnded))]
        let (joiner, source) = makeJoiner()

        #expect(await !joiner.join(.invite("invite")))

        #expect(joiner.message == .inviteNotWorking(stillConnectedTo: "Dad"))
        #expect(source.crewluCloudPartnerID == Make.partnerA)
        #expect(keys.key == Make.key)
    }

    @Test func test_aJoinThatDidntFinish_keepsTheKey_forTheNextTry() async {
        door.joinAnswers = [.success(Self.joinedB)]
        let (joiner, source) = makeJoiner()

        #expect(await !joiner.join(.invite("invite")))

        #expect(joiner.message == .couldntConnect)
        #expect(!source.isOnCrewluCloud)
        #expect(keys.pending == door.joins.first?.key)
    }

    // MARK: - While a Join Is Under Way

    @Test func test_isConnecting_whileAJoinWaits_andAnotherJoinIsIgnored() async throws {
        door.joinAnswers = [.success(Self.joinedB)]
        door.viewAnswers = [
            Make.answer(updatedAt: "t1", try Make.summary(), partnerID: Make.partnerB),
            Make.answer(updatedAt: "t1", try Make.summary(), partnerID: Make.partnerB),
        ]
        door.holdsViews = true
        let (joiner, _) = makeJoiner()

        let first = Task { await joiner.join(.invite("invite")) }
        await eventually { door.views.count == 1 }
        #expect(joiner.isConnecting)
        #expect(await !joiner.join(.invite("another")))
        door.holdsViews = false
        door.release()

        #expect(await first.value)
        #expect(door.joins.count == 1)
        #expect(!joiner.isConnecting)
    }

    @Test func test_theQuestion_readsAsTheMockupDoes() {
        let question = SwitchQuestion(newPilot: "Sam", currentPilot: "Alex", deviceModel: "iPad")

        #expect(question.title == "Switch to Sam?")
        #expect(question.message == "You'll stop seeing Alex's status on this iPad.")
    }
}
