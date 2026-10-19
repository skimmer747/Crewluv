//
//  PushRouteTests.swift
//  CrewluvTests
//
//  What a silent push means, and what iOS is told afterwards
//  (partner links piece 4 spec §6.2).
//

import Foundation
import Testing
@testable import Crewluv

struct PushRouteTests {

    /// What Crewlu Cloud's push service sends.
    private static func crewluCloudPush() -> [AnyHashable: Any] {
        ["aps": ["content-available": 1]]
    }

    /// What a CloudKit subscription sends.
    private static func iCloudPush() -> [AnyHashable: Any] {
        ["aps": ["content-available": 1], "ck": ["ce": 2, "cid": "iCloud.com.toddanderson.duty", "nid": "1"]]
    }

    @Test func test_onCrewluCloud_itsPushRefreshes() {
        #expect(PushRoute(userInfo: Self.crewluCloudPush(), isOnCrewluCloud: true) == .refresh)
    }

    @Test func test_onCrewluCloud_iCloudsPushIsIgnored() {
        #expect(PushRoute(userInfo: Self.iCloudPush(), isOnCrewluCloud: true) == .ignore)
    }

    @Test func test_onCrewluCloud_aPushThatIsntSilentIsIgnored() {
        #expect(PushRoute(userInfo: ["aps": ["alert": "Hello"]], isOnCrewluCloud: true) == .ignore)
    }

    @Test func test_onICloud_iCloudsPushRefreshes() {
        #expect(PushRoute(userInfo: Self.iCloudPush(), isOnCrewluCloud: false) == .refresh)
    }

    @Test func test_onICloud_otherPushesAreIgnored() {
        #expect(PushRoute(userInfo: Self.crewluCloudPush(), isOnCrewluCloud: false) == .ignore)
    }

    @Test(arguments: [
        (RefreshOutcome.newStatus, BackgroundFetchOutcome.newData),
        (.sharingEnded, .newData),
        (.unchanged, .noData),
        (.noStatusYet, .noData),
        (.notConnected, .noData),
        (.superseded, .noData),
        (.failed("No connection to Crewlu Cloud"), .failed),
    ])
    func test_whatIOSIsTold(outcome: RefreshOutcome, expected: BackgroundFetchOutcome) {
        #expect(outcome.backgroundFetchOutcome == expected)
    }
}
