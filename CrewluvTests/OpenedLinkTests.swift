//
//  OpenedLinkTests.swift
//  CrewluvTests
//
//  Where a link or pasted text goes: the joiner, today's iCloud share handling, or nowhere
//  (partner links piece 4 spec §7.1, §7.4)
//

import Foundation
import Testing
@testable import Crewluv

struct OpenedLinkTests {
    private static let share = "https://www.icloud.com/share/0abcDEF#Pilot_Status"

    @Test func test_crewluvesOwnLink_goesToTheJoiner() throws {
        let url = try #require(URL(string: "https://crewluve.crewlu.net/join#c=K7MQ2X"))

        #expect(OpenedLink(url: url) == .partner(.code("K7MQ2X")))
    }

    @Test(arguments: [Self.share, "crewluv://accept-share?url=https%3A%2F%2Fwww.icloud.com%2Fshare%2F0abc"])
    func test_anICloudShareLink_goesToTodaysHandling(text: String) throws {
        let url = try #require(URL(string: text))

        #expect(OpenedLink(url: url) == .iCloudShare(url))
    }

    @Test func test_anyOtherLink_goesNowhere() throws {
        #expect(OpenedLink(url: try #require(URL(string: "https://example.com/join#t=abc"))) == .neither)
    }

    @Test func test_pastedText_aLinkOrACode() throws {
        #expect(OpenedLink(text: " https://crewluve.crewlu.net/join#t=abc ") == .partner(.invite("abc")))
        #expect(OpenedLink(text: "k7m-q2x") == .partner(.code("K7MQ2X")))
        #expect(OpenedLink(text: "\n\(Self.share)\n") == .iCloudShare(try #require(URL(string: Self.share))))
        #expect(OpenedLink(text: "hello") == .neither)
        #expect(OpenedLink(text: "") == .neither)
    }
}
