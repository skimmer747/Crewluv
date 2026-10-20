//
//  SharingEndedNoteTests.swift
//  CrewluvTests
//
//  The welcome screen's note when sharing ended (partner links piece 4 spec §7.6, §7.7)
//

import Testing
@testable import Crewluv

struct SharingEndedNoteTests {
    @Test func test_sharingEnded() {
        #expect(SharingEndedNote(pilot: "Alex", isLeftBehind: false).text == "Sharing with Alex has ended.")
    }

    @Test func test_aDeviceLeftBehind_isToldHowToFollowTheOther() {
        #expect(SharingEndedNote(pilot: "Alex", isLeftBehind: true).text
            == "To keep seeing Alex's status here, type the code from CrewLuve on your other device.")
    }
}
