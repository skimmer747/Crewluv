//
//  JoinMessage.swift
//  CrewLuve
//
//  What a partner is told when a link or code didn't connect
//

import Foundation

/// What a partner is told when a link or code didn't connect (partner links piece 4 spec §7.3), or
/// when an iCloud share link was opened on a device already on Crewlu Cloud (§16). Each is an alert
/// with an OK button.
nonisolated enum JoinMessage: Equatable, Sendable {
    /// The invite link is dead. With the name of the pilot this device still follows, if any.
    case inviteNotWorking(stillConnectedTo: String?)
    case codeNotWorking
    case tooManyDevices
    case tooManyTries
    case couldntConnect
    case notAnInviteLink
    /// An iCloud share link, on a device on Crewlu Cloud. With the name of the pilot it follows.
    case alreadyConnected(to: String?)

    /// The message for the door's answer to joining `link`. `name` is the pilot this device still
    /// follows, as this partner sees them, if it follows one.
    init(_ error: PartnerDoorError, joining link: PartnerLink, stillConnectedTo name: String?) {
        switch (error, link) {
        case (.refused(.sharingEnded), .invite):
            self = .inviteNotWorking(stillConnectedTo: name)
        case (.refused(.sharingEnded), .code):
            self = .codeNotWorking
        case (.refused(.tooManyDevices), _):
            self = .tooManyDevices
        case (.refused(.tryLater), _):
            self = .tooManyTries
        case (.refused(.invalidInput), _):
            self = .notAnInviteLink
        case (.refused(.keyInUse), _), (.unavailable, _):
            self = .couldntConnect
        }
    }

    var title: String {
        switch self {
        case .inviteNotWorking: "Invite Link Not Working"
        case .codeNotWorking: "Code Not Working"
        case .tooManyDevices: "Too Many Devices"
        case .tooManyTries: "Too Many Tries"
        case .couldntConnect: "Couldn't Connect"
        case .notAnInviteLink: "Not an Invite Link"
        case .alreadyConnected: "Already Connected"
        }
    }

    var text: String {
        switch self {
        case .inviteNotWorking(let name?):
            "This invite link doesn't work anymore. You're still connected to \(name)."
        case .inviteNotWorking(nil):
            "This invite link doesn't work anymore. Ask your pilot to send it again."
        case .codeNotWorking:
            "That code didn't work. Codes last 10 minutes and work once. Make a new one on your other device."
        case .tooManyDevices:
            "This invite already has 10 devices. Ask your pilot to remove one in CrewLu, then try again."
        case .tooManyTries:
            "Too many tries. Wait a minute, then try again."
        case .couldntConnect:
            "Couldn't connect. Check your connection and try again."
        case .notAnInviteLink:
            "That doesn't look like an invite link."
        case .alreadyConnected(let name):
            "You're already connected to \(name ?? "your pilot"). To follow another pilot, ask them for an invite link from CrewLu."
        }
    }
}
