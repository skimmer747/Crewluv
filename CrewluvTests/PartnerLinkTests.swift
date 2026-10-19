//
//  PartnerLinkTests.swift
//  CrewluvTests
//
//  Invite links, code links and typed codes (partner links piece 4 spec §7.1)
//

import Foundation
import Testing
@testable import Crewluv

struct PartnerLinkTests {
    private let invite = "0f1e2d3c4b5a69788796a5b4c3d2e1f0"

    // MARK: - Links

    @Test func test_inviteLink() throws {
        let url = try #require(URL(string: "https://crewluve.crewlu.net/join#t=\(invite)"))

        #expect(PartnerLink(url: url) == .invite(invite))
    }

    @Test func test_codeLink_isReadInCapitals() throws {
        let url = try #require(URL(string: "https://crewluve.crewlu.net/join#c=k7mq2x"))

        #expect(PartnerLink(url: url) == .code("K7MQ2X"))
    }

    @Test func test_aTrailingSlash_isTolerated() throws {
        let url = try #require(URL(string: "https://crewluve.crewlu.net/join/#t=\(invite)"))

        #expect(PartnerLink(url: url) == .invite(invite))
    }

    @Test func test_theHost_inAnyCase() throws {
        let url = try #require(URL(string: "https://CrewLuve.CrewLu.net/join#t=\(invite)"))

        #expect(PartnerLink(url: url) == .invite(invite))
    }

    @Test(arguments: [
        "http://crewluve.crewlu.net/join#t=abc",
        "https://crewlu.net/join#t=abc",
        "https://crewluve.crewlu.net.example.com/join#t=abc",
        "https://crewluve.crewlu.net/join2#t=abc",
        "https://crewluve.crewlu.net/join/more#t=abc",
        "https://crewluve.crewlu.net/#t=abc",
        "https://crewluve.crewlu.net/join",
        "https://crewluve.crewlu.net/join#t=",
        "https://crewluve.crewlu.net/join#x=abc",
        "https://crewluve.crewlu.net/join?t=abc",
        "https://crewluve.crewlu.net/join#c=K7MQ2",
        "https://www.icloud.com/share/0abcDEF#Pilot_Status",
        "crewluv://accept-share?url=https%3A%2F%2Fwww.icloud.com%2Fshare%2F0abc",
    ])
    func test_otherLinks_arentPartnerLinks(text: String) throws {
        let url = try #require(URL(string: text))

        #expect(PartnerLink(url: url) == nil)
    }

    @Test func test_theFirstUsableValue_inTheFragment_counts() throws {
        let url = try #require(URL(string: "https://crewluve.crewlu.net/join#x=1&t=\(invite)&c=K7MQ2X"))

        #expect(PartnerLink(url: url) == .invite(invite))
    }

    // MARK: - Pasted or Typed Text

    @Test func test_pastedLink_withSpacesAndLineBreaks() {
        #expect(PartnerLink(text: "  https://crewluve.crewlu.net/join#t=\(invite)\n") == .invite(invite))
    }

    @Test(arguments: ["K7MQ2X", "k7mq2x", "K7M Q2X", "k7m-q2x", " K7M-Q2X ", "K 7 M Q 2 X"])
    func test_typedCode_inAnyCase_withSpacesOrDashes(text: String) {
        #expect(PartnerLink(text: text) == .code("K7MQ2X"))
    }

    @Test(arguments: ["K7MQ2", "K7MQ2XY", "K7MQ2!", "K7MQ2É", "", "   ", "hello there", "https://example.com/join#t=abc"])
    func test_otherText_isntAPartnerLink(text: String) {
        #expect(PartnerLink(text: text) == nil)
    }

    // MARK: - The Code Boxes

    @Test(arguments: [
        ("k7m", "K7M"),
        ("k7m-q2x", "K7MQ2X"),
        ("K7M Q2X", "K7MQ2X"),
        ("K7MQ2X9", "K7MQ2X"),
        ("K7Mé!Q2", "K7MQ2"),
        ("", ""),
    ])
    func test_theCodeBoxes_keepLettersAndDigits_inCapitals_atMostSix(text: String, expected: String) {
        #expect(PartnerLink.codeBoxes(text) == expected)
    }

    // MARK: - Logs

    @Test func test_logs_showOnlyTheHostAndPath_ofAPartnerLink() throws {
        let url = try #require(URL(string: "https://crewluve.crewlu.net/join#t=\(invite)"))

        #expect(PartnerLink.logDescription(of: url) == "crewluve.crewlu.net/join")
    }

    @Test func test_logs_showOtherLinks_asTheyAre() throws {
        let url = try #require(URL(string: "https://www.icloud.com/share/0abcDEF#Pilot_Status"))

        #expect(PartnerLink.logDescription(of: url) == "https://www.icloud.com/share/0abcDEF#Pilot_Status")
    }
}
