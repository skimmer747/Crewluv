//
//  HandOffCodeTests.swift
//  CrewluvTests
//
//  The code Use on Another Device shows (partner links piece 4 spec §7.5)
//

import Foundation
import Testing
@testable import Crewluv

struct HandOffCodeTests {
    private let code = HandOffCode(code: "K7MQ2X", expiresAt: Date(timeIntervalSince1970: 1_792_419_308))

    @Test func test_grouped_inTwoGroupsOfThree() {
        #expect(code.grouped == "K7M Q2X")
    }

    @Test func test_link_isTheCodeLink_thatCrewluveReads() throws {
        #expect(code.link == "https://crewluve.crewlu.net/join#c=K7MQ2X")
        #expect(PartnerLink(url: try #require(URL(string: code.link))) == .code("K7MQ2X"))
    }

    @Test(arguments: [
        (600.0, "10:00 left · works once"),
        (581.0, "9:41 left · works once"),
        (59.4, "1:00 left · works once"),
        (0.5, "0:01 left · works once"),
        (0.0, "0:00 left · works once"),
        (-30.0, "0:00 left · works once"),
    ])
    func test_countdown(secondsLeft: Double, expected: String) {
        #expect(code.countdown(at: code.expiresAt.addingTimeInterval(-secondsLeft)) == expected)
    }

    @Test func test_runsOut_atItsExpiry() {
        #expect(!code.hasExpired(at: code.expiresAt.addingTimeInterval(-0.5)))
        #expect(code.hasExpired(at: code.expiresAt))
        #expect(code.hasExpired(at: code.expiresAt.addingTimeInterval(30)))
    }
}
