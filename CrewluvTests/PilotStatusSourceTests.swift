//
//  PilotStatusSourceTests.swift
//  CrewluvTests
//
//  The one place that reads the pilot's status, from iCloud or Crewlu Cloud
//  (partner links piece 4 spec §5.1–§5.3).
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
final class PilotStatusSourceTests {
    private let defaultsName = "PilotStatusSourceTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let door = StandInPartnerDoor()
    private let iCloud = StandInICloud()
    private let keys = InMemoryDeviceKeyStore()
    private let notifier = RecordingNotifier()
    private let iCloudResets = Counter()
    private let connects = Counter()
    private let clock = HandClock()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: defaultsName))
    }

    deinit {
        defaults.removePersistentDomain(forName: defaultsName)
    }

    private func makeSource() -> PilotStatusSource {
        PilotStatusSource(
            iCloud: iCloud,
            door: door,
            keys: keys,
            defaults: defaults,
            notifier: notifier,
            iCloudShareEnded: { [iCloudResets] in iCloudResets.count += 1 },
            periodicCheck: RepeatingRefresh(sleep: clock.sleep),
            didConnect: { [connects] in connects.count += 1 }
        )
    }

    /// A device on Crewlu Cloud as partner A.
    private func connectedSource() -> PilotStatusSource {
        defaults.set(Make.partnerA, forKey: "partnerCloud.partnerID")
        keys.key = Make.key
        return makeSource()
    }

    // MARK: - iCloud

    @Test func test_iCloud_newStatus_becomesTheReading_andAlertsOnce() async throws {
        iCloud.results = [.success(try Make.iCloud(lastUpdated: 1)), .success(try Make.iCloud(lastUpdated: 1))]
        let source = makeSource()

        #expect(await source.refresh() == .newStatus)
        #expect(source.reading?.lastUpdated == Date(timeIntervalSince1970: 1))
        #expect(await source.refresh() == .unchanged)
        #expect(await notifier.evaluations.count == 1)
        #expect(await notifier.evaluations.first?.pilotName == "Alex")
        #expect(!source.isOnCrewluCloud)
    }

    @Test func test_iCloud_changedStatus_alertsAgain() async throws {
        iCloud.results = [.success(try Make.iCloud(lastUpdated: 1)), .success(try Make.iCloud(lastUpdated: 2))]
        let source = makeSource()

        #expect(await source.refresh() == .newStatus)
        #expect(await source.refresh() == .newStatus)
        #expect(await notifier.evaluations.count == 2)
    }

    @Test func test_displayName_titlesTheAlerts_andIsSavedForThem() async throws {
        iCloud.results = [
            .success(try Make.iCloud(lastUpdated: 1, displayName: "Dad")),
            .success(try Make.iCloud(lastUpdated: 2)),
        ]
        let source = makeSource()

        _ = await source.refresh()
        #expect(await notifier.evaluations.last?.pilotName == "Dad")
        #expect(defaults.string(forKey: "ResolvedPilotDisplayName") == "Dad")
        _ = await source.refresh()
        #expect(await notifier.evaluations.last?.pilotName == "Alex")
        #expect(defaults.string(forKey: "ResolvedPilotDisplayName") == nil)
    }

    @Test func test_iCloud_nameNotLookedUp_titlesTheAlertWithTheSavedName_andKeepsIt() async throws {
        defaults.set("Dad", forKey: "ResolvedPilotDisplayName")
        iCloud.results = [.success(try Make.iCloud(lastUpdated: 1, isDisplayNameKnown: false))]
        let source = makeSource()

        #expect(await source.refresh() == .newStatus)
        #expect(await notifier.evaluations.last?.pilotName == "Dad")
        #expect(defaults.string(forKey: "ResolvedPilotDisplayName") == "Dad")
    }

    @Test func test_iCloud_nameLookedUpLater_isShown_withoutAlertingAgain() async throws {
        iCloud.results = [
            .success(try Make.iCloud(lastUpdated: 1, isDisplayNameKnown: false)),
            .success(try Make.iCloud(lastUpdated: 1, displayName: "Dad")),
        ]
        let source = makeSource()
        _ = await source.refresh()

        #expect(await source.refresh() == .unchanged)
        #expect(source.reading?.displayName == "Dad")
        #expect(defaults.string(forKey: "ResolvedPilotDisplayName") == "Dad")
        #expect(await notifier.evaluations.count == 1)
    }

    @Test func test_iCloud_nameLookedUpLater_asNone_forgetsTheSavedName() async throws {
        defaults.set("Dad", forKey: "ResolvedPilotDisplayName")
        iCloud.results = [
            .success(try Make.iCloud(lastUpdated: 1, isDisplayNameKnown: false)),
            .success(try Make.iCloud(lastUpdated: 1)),
        ]
        let source = makeSource()
        _ = await source.refresh()

        #expect(await source.refresh() == .unchanged)
        #expect(source.reading?.isDisplayNameKnown == true)
        #expect(defaults.string(forKey: "ResolvedPilotDisplayName") == nil)
    }

    @Test func test_iCloud_nameNotLookedUpLater_keepsTheNameShown() async throws {
        iCloud.results = [
            .success(try Make.iCloud(lastUpdated: 1, displayName: "Dad")),
            .success(try Make.iCloud(lastUpdated: 1, isDisplayNameKnown: false)),
        ]
        let source = makeSource()
        _ = await source.refresh()

        #expect(await source.refresh() == .unchanged)
        #expect(source.reading?.displayName == "Dad")
        #expect(defaults.string(forKey: "ResolvedPilotDisplayName") == "Dad")
    }

    @Test func test_displayName_forTheScreen_isTheSavedOne_whileICloudCantLookItUp() async throws {
        defaults.set("Dad", forKey: "ResolvedPilotDisplayName")
        iCloud.results = [
            .success(try Make.iCloud(lastUpdated: 1, isDisplayNameKnown: false)),
            .success(try Make.iCloud(lastUpdated: 2, displayName: "Pops")),
        ]
        let source = makeSource()
        #expect(source.displayName == nil)

        _ = await source.refresh()
        #expect(source.displayName == "Dad")
        _ = await source.refresh()
        #expect(source.displayName == "Pops")
    }

    @Test func test_iCloud_noShare_isNotConnected() async {
        iCloud.results = [.failure(ICloudFetchError.notConnected)]
        let source = makeSource()

        #expect(await source.refresh() == .notConnected)
        #expect(source.reading == nil)
        #expect(await notifier.evaluations.isEmpty)
    }

    @Test func test_iCloud_shareGone_endsSharing() async throws {
        iCloud.results = [.success(try Make.iCloud(lastUpdated: 1)), .failure(ICloudFetchError.shareGone)]
        let source = makeSource()

        _ = await source.refresh()
        #expect(await source.refresh() == .sharingEnded)
        #expect(source.reading == nil)
        #expect(iCloudResets.count == 1)
    }

    @Test func test_iCloudReset_forgetsAnICloudReading() async throws {
        iCloud.results = [.success(try Make.iCloud(lastUpdated: 1))]
        let source = makeSource()
        _ = await source.refresh()

        source.forgetICloudReading()
        #expect(source.reading == nil)
    }

    @Test func test_iCloudReset_leavesACrewluCloudReading() async throws {
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Make.summary())]
        let source = connectedSource()
        _ = await source.refresh()

        source.forgetICloudReading()
        #expect(source.reading != nil)
    }

    @Test func test_iCloud_otherFailure_isFailed_withItsMessage() async {
        iCloud.results = [.failure(URLError(.notConnectedToInternet))]

        #expect(await makeSource().refresh() == .failed(URLError(.notConnectedToInternet).localizedDescription))
    }

    // MARK: - Crewlu Cloud

    @Test func test_crewluCloud_summary_becomesTheReading_andItsTimeGoesBackAsSince() async throws {
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Make.summary()), Make.unchanged(updatedAt: "t1")]
        let source = connectedSource()

        #expect(await source.refresh() == .newStatus)
        #expect(await source.refresh() == .unchanged)
        #expect(door.views.map(\.key) == [Make.key, Make.key])
        #expect(door.views.map(\.since) == [nil, "t1"])
        #expect(await notifier.evaluations.count == 1)
        #expect(source.isOnCrewluCloud)
        #expect(iCloud.fetches == 0)
        #expect(connects.count == 0)
    }

    @Test func test_crewluCloud_alertsWithThisPartnersNameAndQuickStatus() async throws {
        let summary = try Make.summary([
            "displayNameByPartner": [Make.partnerA: "Dad"],
            "quickStatusByPartner": [Make.partnerA: ["status": "Call Me", "icon": "phone.fill"]],
        ])
        door.viewAnswers = [Make.answer(updatedAt: "t1", summary)]

        _ = await connectedSource().refresh()
        let evaluation = try #require(await notifier.evaluations.first)
        #expect(evaluation.pilotName == "Dad")
        #expect(evaluation.status.quickStatus == "Call Me")
        #expect(defaults.string(forKey: "ResolvedPilotDisplayName") == "Dad")
    }

    @Test func test_crewluCloud_beforeTheFirstSummary_hasNoStatusYet() async {
        door.viewAnswers = [Make.noSummaryYet]
        let source = connectedSource()

        #expect(await source.refresh() == .noStatusYet)
        #expect(source.reading == nil)
        #expect(source.isOnCrewluCloud)
        #expect(await notifier.evaluations.isEmpty)
    }

    @Test func test_crewluCloud_sharingEnded_forgetsTheKeyAndTheConnection() async throws {
        door.viewAnswers = [
            Make.answer(updatedAt: "t1", try Make.summary(["displayNameByPartner": [Make.partnerA: "Dad"]])),
            .failure(.refused(.sharingEnded)),
        ]
        let source = connectedSource()
        _ = await source.refresh()
        defaults.set(Data([1]), forKey: "LastSeenPilotSnapshot")

        #expect(await source.refresh() == .sharingEnded)
        #expect(keys.key == nil)
        #expect(!source.isOnCrewluCloud)
        #expect(defaults.string(forKey: "partnerCloud.partnerID") == nil)
        #expect(source.reading == nil)
        #expect(defaults.string(forKey: "ResolvedPilotDisplayName") == nil)
        #expect(defaults.data(forKey: "LastSeenPilotSnapshot") == nil)
        #expect(iCloudResets.count == 0)
    }

    @Test func test_crewluCloud_unreachable_isFailed_andTheNextReadAsksForEverything() async throws {
        door.viewAnswers = [
            Make.answer(updatedAt: "t1", try Make.summary()),
            .failure(.unavailable),
            Make.answer(updatedAt: "t1", try Make.summary()),
        ]
        let source = connectedSource()

        _ = await source.refresh()
        #expect(await source.refresh() == .failed("No connection to Crewlu Cloud"))
        #expect(await source.refresh() == .unchanged)
        #expect(door.views.map(\.since) == [nil, "t1", nil])
        #expect(keys.key == Make.key)
        #expect(await notifier.evaluations.count == 1)
    }

    @Test func test_crewluCloud_otherRefusal_isFailed_andKeepsTheKey() async {
        door.viewAnswers = [.failure(.refused(.invalidInput))]
        let source = connectedSource()

        #expect(await source.refresh() == .failed("No connection to Crewlu Cloud"))
        #expect(keys.key == Make.key)
        #expect(source.isOnCrewluCloud)
    }

    @Test func test_crewluCloud_withoutAKey_isNotConnected() async {
        defaults.set(Make.partnerA, forKey: "partnerCloud.partnerID")
        let source = makeSource()

        #expect(await source.refresh() == .notConnected)
        #expect(!source.isOnCrewluCloud)
        #expect(door.views.isEmpty)
    }

    @Test func test_crewluCloud_unreadableKey_isFailed_andKeepsTheConnection() async throws {
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Make.summary())]
        let source = connectedSource()
        _ = await source.refresh()

        keys.readFails = true
        #expect(await source.refresh() == .failed("This device's key couldn't be read"))
        #expect(source.isOnCrewluCloud)
        #expect(source.reading != nil)
        #expect(keys.key == Make.key)
        #expect(door.views.count == 1)
    }

    @Test func test_crewluCloud_keyGone_forgetsTheReading() async throws {
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Make.summary())]
        let source = connectedSource()
        _ = await source.refresh()

        keys.key = nil
        #expect(await source.refresh() == .notConnected)
        #expect(source.reading == nil)
        #expect(!source.isOnCrewluCloud)
    }

    @Test func test_crewluCloud_summaryAnsweredAfterSharingEnded_bringsNothingBack() async throws {
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Make.summary(["displayNameByPartner": [Make.partnerA: "Dad"]]))]
        door.holdsViews = true
        let source = connectedSource()

        let read = Task { await source.refresh() }
        await eventually { door.views.count == 1 }
        source.endSharing()
        door.release()

        #expect(await read.value == .superseded)
        #expect(source.reading == nil)
        #expect(!source.isOnCrewluCloud)
        #expect(defaults.string(forKey: "ResolvedPilotDisplayName") == nil)
        #expect(await notifier.evaluations.isEmpty)
    }

    @Test func test_crewluCloud_failureAfterSharingEnded_bringsNothingBack() async {
        door.holdsViews = true
        let source = connectedSource()

        let read = Task { await source.refresh() }
        await eventually { door.views.count == 1 }
        source.endSharing()
        door.release()

        #expect(await read.value == .superseded)
    }

    @Test func test_crewluCloud_sameTimeForAnotherPartner_isANewStatus() async throws {
        door.viewAnswers = [
            Make.answer(updatedAt: "t1", try Make.summary()),
            Make.answer(updatedAt: "t1", try Make.summary(), partnerID: Make.partnerB),
        ]
        let source = connectedSource()
        _ = await source.refresh()

        #expect(await source.refresh() == .newStatus)
        guard case .crewluCloud(_, let partnerID, _)? = source.reading else {
            Issue.record("no Crewlu Cloud reading")
            return
        }
        #expect(partnerID == Make.partnerB)
    }

    // MARK: - A Key Left by a Reinstall

    @Test func test_leftoverKey_withASummary_connects() async throws {
        keys.key = Make.key
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Make.summary())]
        let source = makeSource()

        #expect(await source.refresh() == .newStatus)
        #expect(source.crewluCloudPartnerID == Make.partnerA)
        #expect(defaults.string(forKey: "partnerCloud.partnerID") == Make.partnerA)
        #expect(door.views.map(\.since) == [nil])
        #expect(iCloud.fetches == 0)
        #expect(connects.count == 1)
    }

    @Test func test_leftoverKey_sharingEnded_isForgotten_andICloudIsRead() async throws {
        keys.key = Make.key
        door.viewAnswers = [.failure(.refused(.sharingEnded))]
        iCloud.results = [.success(try Make.iCloud(lastUpdated: 1))]
        let source = makeSource()

        #expect(await source.refresh() == .newStatus)
        #expect(keys.key == nil)
        #expect(!source.isOnCrewluCloud)
        #expect(iCloud.fetches == 1)
    }

    @Test func test_leftoverKey_unreadable_isLeftForNextTime() async throws {
        keys.key = Make.key
        keys.readFails = true
        iCloud.results = [.success(try Make.iCloud(lastUpdated: 1))]
        let source = makeSource()

        #expect(await source.refresh() == .newStatus)
        #expect(door.views.isEmpty)
        #expect(keys.key == Make.key)
        #expect(!source.isOnCrewluCloud)
    }

    @Test func test_leftoverKey_unreachable_isKept_andTriedAgainNextTime() async {
        keys.key = Make.key
        let source = makeSource()

        #expect(await source.refresh() == .notConnected)
        #expect(keys.key == Make.key)
        #expect(iCloud.fetches == 1)
        _ = await source.refresh()
        #expect(door.views.count == 2)
    }

    @Test(arguments: [("SharedZoneOwner", "_owner"), ("PilotDataSource", "privateDB")])
    func test_leftoverKey_beforeTheFirstSummary_withICloud_staysOnICloud(setting: String, value: String) async throws {
        keys.key = Make.key
        defaults.set(value, forKey: setting)
        door.viewAnswers = [Make.noSummaryYet]
        iCloud.results = [.success(try Make.iCloud(lastUpdated: 1))]
        let source = makeSource()

        #expect(await source.refresh() == .newStatus)
        #expect(!source.isOnCrewluCloud)
        #expect(iCloud.fetches == 1)
        #expect(connects.count == 0)
    }

    @Test func test_leftoverKey_beforeTheFirstSummary_withoutICloud_connects() async {
        keys.key = Make.key
        door.viewAnswers = [Make.noSummaryYet]
        let source = makeSource()

        #expect(await source.refresh() == .noStatusYet)
        #expect(source.isOnCrewluCloud)
        #expect(iCloud.fetches == 0)
        #expect(connects.count == 1)
    }

    // MARK: - Refreshes and the Screen

    @Test func test_refreshesAskedForDuringARead_shareOneMoreReadAfterIt() async throws {
        door.viewAnswers = [
            Make.answer(updatedAt: "t1", try Make.summary(lastUpdated: 1)),
            Make.answer(updatedAt: "t2", try Make.summary(lastUpdated: 2)),
        ]
        door.holdsViews = true
        let source = connectedSource()

        let first = Task { await source.refresh() }
        await eventually { door.views.count == 1 }
        let second = Task { await source.refresh() }
        await eventually { source.isReadQueued }
        let third = Task { await source.refresh() }
        for _ in 0..<10 {
            await Task.yield()
        }
        door.release()
        await eventually { door.views.count == 2 }
        door.holdsViews = false
        door.release()

        #expect(await [first.value, second.value, third.value] == [.newStatus, .newStatus, .newStatus])
        #expect(door.views.map(\.since) == [nil, "t1"])
        #expect(source.reading?.lastUpdated == Date(timeIntervalSince1970: 2))
        #expect(!source.isReadQueued)
    }

    @Test func test_aRefreshDuringTheQueuedRead_waitsForItToEnd() async throws {
        door.viewAnswers = [
            Make.answer(updatedAt: "t1", try Make.summary(lastUpdated: 1)),
            Make.answer(updatedAt: "t2", try Make.summary(lastUpdated: 2)),
            Make.answer(updatedAt: "t3", try Make.summary(lastUpdated: 3)),
        ]
        door.holdsViews = true
        let source = connectedSource()

        let first = Task { await source.refresh() }
        await eventually { door.views.count == 1 }
        let second = Task { await source.refresh() }
        await eventually { source.isReadQueued }
        door.release()
        await eventually { door.views.count == 2 && !source.isReadQueued }
        let third = Task { await source.refresh() }
        await eventually { source.isReadQueued }
        door.holdsViews = false
        door.release()

        #expect(await [first.value, second.value, third.value] == [.newStatus, .newStatus, .newStatus])
        #expect(door.views.map(\.since) == [nil, "t1", "t2"])
    }

    @Test func test_theScreenHearsHowEveryReadWent() async throws {
        door.viewAnswers = [
            Make.answer(updatedAt: "t1", try Make.summary()),
            Make.unchanged(updatedAt: "t1"),
            .failure(.unavailable),
            .failure(.refused(.sharingEnded)),
        ]
        let source = connectedSource()
        let heard = Heard()
        let observer = heard.listen(to: source)
        defer { NotificationCenter.default.removeObserver(observer) }
        let before = Date()

        for _ in 0..<4 {
            _ = await source.refresh()
        }

        #expect(heard.outcomes == [.newStatus, .unchanged, .failed("No connection to Crewlu Cloud"), .sharingEnded])
        let readAt = try #require(source.lastUpdate?.readAt)
        #expect(readAt >= before && readAt <= Date())
    }

    @Test func test_theScreenHearsOfSharingEndingOutsideARead() {
        let source = connectedSource()
        let heard = Heard()
        let observer = heard.listen(to: source)
        defer { NotificationCenter.default.removeObserver(observer) }

        source.endSharing()

        #expect(heard.outcomes == [.sharingEnded])
        #expect(!source.isOnCrewluCloud)
        #expect(keys.key == nil)
    }

    // MARK: - The Pilot Last Seen, and Sharing Ended

    @Test func test_eachNewStatus_savesThePilot_asThisPartnerSeesThem() async throws {
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Make.summary(["displayNameByPartner": [Make.partnerA: "Dad"]]))]
        _ = await connectedSource().refresh()

        #expect(defaults.string(forKey: "partnerCloud.pilotID") == "pilot")
        #expect(defaults.string(forKey: "partnerCloud.pilotName") == "Dad")
    }

    @Test func test_aPilotWithoutANickname_isSavedByFirstName() async throws {
        iCloud.results = [.success(try Make.iCloud(lastUpdated: 1))]
        _ = await makeSource().refresh()

        #expect(defaults.string(forKey: "partnerCloud.pilotName") == "Alex")
    }

    @Test func test_sharingEnded_onCrewluCloud_leavesTheNote_andForgetsThePilot() async throws {
        door.viewAnswers = [
            Make.answer(updatedAt: "t1", try Make.summary(["displayNameByPartner": [Make.partnerA: "Dad"]])),
            .failure(.refused(.sharingEnded)),
        ]
        let source = connectedSource()
        _ = await source.refresh()
        defaults.set(Date(timeIntervalSince1970: 1), forKey: "LastEvaluatedPilotStatusTimestamp")

        #expect(await source.refresh() == .sharingEnded)
        #expect(source.sharingEndedWith == "Dad")
        #expect(defaults.string(forKey: "partnerCloud.sharingEndedWith") == "Dad")
        #expect(defaults.string(forKey: "partnerCloud.pilotID") == nil)
        #expect(defaults.string(forKey: "partnerCloud.pilotName") == nil)
        #expect(defaults.object(forKey: "LastEvaluatedPilotStatusTimestamp") == nil)
    }

    @Test func test_sharingEnded_toldByThePushRegistration_leavesTheNote() async throws {
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Make.summary())]
        let source = connectedSource()
        _ = await source.refresh()

        source.endSharing()

        #expect(source.sharingEndedWith == "Alex")
    }

    @Test func test_sharingEnded_onICloud_leavesTheNote() async throws {
        iCloud.results = [.success(try Make.iCloud(lastUpdated: 1, displayName: "Dad")), .failure(ICloudFetchError.shareGone)]
        let source = makeSource()
        _ = await source.refresh()

        #expect(await source.refresh() == .sharingEnded)
        #expect(source.sharingEndedWith == "Dad")
    }

    @Test func test_sharingEnded_beforeAnyStatus_leavesNoNote() async {
        door.viewAnswers = [.failure(.refused(.sharingEnded))]
        let source = connectedSource()

        #expect(await source.refresh() == .sharingEnded)
        #expect(source.sharingEndedWith == nil)
    }

    @Test func test_theNote_staysAfterARelaunch_untilTheNextStatus() async throws {
        defaults.set("Dad", forKey: "partnerCloud.sharingEndedWith")
        iCloud.results = [.success(try Make.iCloud(lastUpdated: 1))]
        let source = makeSource()
        #expect(source.sharingEndedWith == "Dad")

        _ = await source.refresh()

        #expect(source.sharingEndedWith == nil)
        #expect(defaults.string(forKey: "partnerCloud.sharingEndedWith") == nil)
    }

    // MARK: - The 60-Second Check

    @Test func test_periodicCheck_readsAtEachTick_whileOnCrewluCloud() async throws {
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Make.summary()), Make.unchanged(updatedAt: "t1")]
        let screen = StandInScreen()
        let source = connectedSource()

        source.startPeriodicCheck(for: screen, pausedWhile: { screen.isInDemo })
        await eventually { clock.sleeps.count == 1 }
        #expect(door.views.isEmpty)
        clock.tick()
        await eventually { clock.sleeps.count == 2 }
        clock.tick()
        await eventually { clock.sleeps.count == 3 }
        source.stopPeriodicCheck(for: screen)
        await eventually { clock.waitingCount == 0 }

        #expect(door.views.map(\.since) == [nil, "t1"])
        #expect(clock.sleeps.allSatisfy { $0 == .seconds(60) })
    }

    @Test func test_periodicCheck_stopsReading_onceSharingEnds() async throws {
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Make.summary())]
        let screen = StandInScreen()
        let source = connectedSource()

        source.startPeriodicCheck(for: screen, pausedWhile: { screen.isInDemo })
        await eventually { clock.sleeps.count == 1 }
        clock.tick()
        await eventually { clock.sleeps.count == 2 }
        source.endSharing()
        clock.tick()
        await eventually { clock.sleeps.count == 3 }
        source.stopPeriodicCheck(for: screen)

        #expect(door.views.count == 1)
        #expect(iCloud.fetches == 0)
    }

    @Test func test_periodicCheck_startsReading_onceTheDeviceConnects() async throws {
        let screen = StandInScreen()
        let source = makeSource()

        source.startPeriodicCheck(for: screen, pausedWhile: { screen.isInDemo })
        await eventually { clock.sleeps.count == 1 }
        clock.tick()
        await eventually { clock.sleeps.count == 2 }
        #expect(door.views.isEmpty)
        #expect(iCloud.fetches == 0)

        keys.key = Make.key
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Make.summary()), Make.unchanged(updatedAt: "t1")]
        #expect(await source.refresh() == .newStatus)
        clock.tick()
        await eventually { clock.sleeps.count == 3 }
        source.stopPeriodicCheck(for: screen)

        #expect(door.views.map(\.since) == [nil, "t1"])
    }

    @Test func test_periodicCheck_readsNothing_whileEveryScreenInFrontShowsTheDemo() async throws {
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Make.summary())]
        let demo = StandInScreen(isInDemo: true)
        let status = StandInScreen()
        let source = connectedSource()

        source.startPeriodicCheck(for: demo, pausedWhile: { demo.isInDemo })
        await eventually { clock.sleeps.count == 1 }
        clock.tick()
        await eventually { clock.sleeps.count == 2 }
        #expect(door.views.isEmpty)
        source.startPeriodicCheck(for: status, pausedWhile: { status.isInDemo })
        clock.tick()
        await eventually { clock.sleeps.count == 3 }
        source.stopPeriodicCheck(for: demo)
        source.stopPeriodicCheck(for: status)

        #expect(door.views.count == 1)
    }

    @Test func test_periodicCheck_runsWhileAnyScreenIsInFront() async throws {
        door.viewAnswers = [Make.answer(updatedAt: "t1", try Make.summary())]
        let first = StandInScreen()
        let second = StandInScreen()
        let source = connectedSource()

        source.startPeriodicCheck(for: first, pausedWhile: { first.isInDemo })
        source.startPeriodicCheck(for: second, pausedWhile: { second.isInDemo })
        await eventually { clock.sleeps.count == 1 }
        source.stopPeriodicCheck(for: second)
        clock.tick()
        await eventually { clock.sleeps.count == 2 }
        #expect(door.views.count == 1)
        source.stopPeriodicCheck(for: first)

        await eventually { clock.waitingCount == 0 }
        #expect(clock.sleeps.count == 2)
    }

    // MARK: - The Reading

    @Test func test_reading_fromCrewluCloud_changesWhenItsQuickStatusExpires() throws {
        let expiry = Date(timeIntervalSince1970: 1_792_609_200)
        let summary = try Make.summary([
            "quickStatusByPartner": [Make.partnerA: ["status": "Call Me", "icon": "phone.fill", "expiry": expiry.timeIntervalSince1970]],
        ])
        let reading = PilotReading.crewluCloud(summary, partnerID: Make.partnerA, updatedAt: "t1")

        #expect(reading.change(after: expiry.addingTimeInterval(-60)) == expiry)
        #expect(reading.status(at: expiry.addingTimeInterval(-60)).quickStatus == "Call Me")
        #expect(reading.status(at: expiry).quickStatus == nil)
        #expect(reading.change(after: expiry) == nil)
    }

    @Test func test_reading_fromICloud_neverChangesByItself() throws {
        let reading = PilotReading.iCloud(try Make.iCloud(lastUpdated: 1, displayName: "Dad"))

        #expect(reading.change(after: Date(timeIntervalSince1970: 0)) == nil)
        #expect(reading.displayName == "Dad")
        #expect(reading.lastUpdated == Date(timeIntervalSince1970: 1))
    }
}
