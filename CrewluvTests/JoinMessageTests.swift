//
//  JoinMessageTests.swift
//  CrewluvTests
//
//  What a partner is told when a link or code didn't connect (partner links piece 4 spec §7.3)
//

import Foundation
import Testing
@testable import Crewluv

struct JoinMessageTests {

    @Test(arguments: [
        (JoinMessage.inviteNotWorking(stillConnectedTo: nil), "Invite Link Not Working",
         "This invite link doesn't work anymore. Ask your pilot to send it again."),
        (.inviteNotWorking(stillConnectedTo: "Dad"), "Invite Link Not Working",
         "This invite link doesn't work anymore. You're still connected to Dad."),
        (.codeNotWorking, "Code Not Working",
         "That code didn't work. Codes last 10 minutes and work once. Make a new one on your other device."),
        (.tooManyDevices, "Too Many Devices",
         "This invite already has 10 devices. Ask your pilot to remove one in CrewLu, then try again."),
        (.tooManyTries, "Too Many Tries", "Too many tries. Wait a minute, then try again."),
        (.couldntConnect, "Couldn't Connect", "Couldn't connect. Check your connection and try again."),
        (.notAnInviteLink, "Not an Invite Link", "That doesn't look like an invite link."),
    ])
    func test_titleAndText(message: JoinMessage, title: String, text: String) {
        #expect(message.title == title)
        #expect(message.text == text)
    }

    @Test(arguments: [
        (PartnerDoorError.refused(.sharingEnded), PartnerLink.invite("a"), JoinMessage.inviteNotWorking(stillConnectedTo: nil)),
        (.refused(.sharingEnded), .code("K7MQ2X"), .codeNotWorking),
        (.refused(.tooManyDevices), .invite("a"), .tooManyDevices),
        (.refused(.tooManyDevices), .code("K7MQ2X"), .tooManyDevices),
        (.refused(.tryLater), .code("K7MQ2X"), .tooManyTries),
        (.refused(.invalidInput), .invite("a"), .notAnInviteLink),
        (.refused(.keyInUse), .invite("a"), .couldntConnect),
        (.unavailable, .invite("a"), .couldntConnect),
        (.unavailable, .code("K7MQ2X"), .couldntConnect),
    ])
    func test_fromTheDoorsAnswer(error: PartnerDoorError, link: PartnerLink, expected: JoinMessage) {
        #expect(JoinMessage(error, joining: link, stillConnectedTo: nil) == expected)
    }

    @Test func test_aDeadInvite_saysWhoThisDeviceStillFollows() {
        #expect(JoinMessage(.refused(.sharingEnded), joining: .invite("a"), stillConnectedTo: "Dad")
                == .inviteNotWorking(stillConnectedTo: "Dad"))
    }
}
