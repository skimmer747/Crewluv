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

    /// The pilot's own Crewluve, on their own iCloud, once their partners have moved to Crewlu Cloud.
    @Test func test_onThePilotsOwnICloud_thePilotIsToldHowToSeeTheirStatusHere() {
        #expect(SharingEndedNote(pilot: "Alex", isLeftBehind: false, isPilotsOwn: true).text
            == "Your partners now see your status through Crewlu Cloud. To see it here too, invite yourself from CrewLu's Settings → Partner Sharing.")
    }

    /// Another of the pilot's devices follows them on Crewlu Cloud: its code is the quicker way.
    @Test func test_onThePilotsOwnICloud_aDeviceLeftBehind_isToldHowToFollowTheOther() {
        #expect(SharingEndedNote(pilot: "Alex", isLeftBehind: true, isPilotsOwn: true).text
            == "To keep seeing Alex's status here, type the code from CrewLuve on your other device.")
    }
}
