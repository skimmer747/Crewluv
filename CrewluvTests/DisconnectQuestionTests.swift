//
//  DisconnectQuestionTests.swift
//  CrewluvTests
//
//  What Disconnect asks, and says when it can't (partner links piece 4 spec §7.5)
//

import Foundation
import Testing
@testable import Crewluv

struct DisconnectQuestionTests {

    @Test func test_theQuestion_readsAsTheMockupDoes() {
        let question = DisconnectQuestion(pilot: "Alex", deviceModel: "iPhone")

        #expect(question.title == "Disconnect from Alex?")
        #expect(question.message == "You'll stop seeing Alex's status on this iPhone. To connect again, tap the invite link Alex sent you.")
    }

    @Test func test_whenItCantDisconnect() {
        #expect(DisconnectQuestion.failureTitle == "Couldn't Disconnect")
        #expect(DisconnectQuestion.failureMessage == "Couldn't disconnect. Check your connection and try again.")
    }
}
