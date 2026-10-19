//
//  SyncLineWordingTests.swift
//  CrewluvTests
//
//  The sync line's words, on iCloud as today and on Crewlu Cloud (partner links piece 4 spec §7.7)
//

import Foundation
import Testing
@testable import Crewluv

struct SyncLineWordingTests {

    @Test func test_theSyncRowsLabel() {
        #expect(SyncLineWording(isOnCrewluCloud: false).syncLabel == "iCloud sync")
        #expect(SyncLineWording(isOnCrewluCloud: true).syncLabel == "Last sync")
    }

    @Test(arguments: [
        ("The network connection was lost.", "Sync failed — check your connection"),
        ("Not Authenticated", "Sync failed — sign into iCloud"),
        ("The request timed out.", "Sync timed out — will retry"),
        ("Server rejected request", "Sync failed — will retry"),
    ])
    func test_onICloud_errorsReadAsToday(error: String, expected: String) {
        #expect(SyncLineWording(isOnCrewluCloud: false).error(error) == expected)
    }

    @Test(arguments: [
        ("No connection to Crewlu Cloud", "Sync failed — check your connection"),
        ("This device's key couldn't be read", "Sync failed — will retry"),
        ("Not Authenticated", "Sync failed — will retry"),
        ("The request timed out.", "Sync failed — will retry"),
    ])
    func test_onCrewluCloud_errorsNeverMentionICloud(error: String, expected: String) {
        #expect(SyncLineWording(isOnCrewluCloud: true).error(error) == expected)
    }
}
