//
//  DisconnectQuestion.swift
//  CrewLuve
//
//  What Disconnect asks, and says when it can't
//

import Foundation

/// What Disconnect asks before it leaves, and says when it can't (partner links piece 4 spec §7.5).
nonisolated struct DisconnectQuestion: Equatable, Sendable {
    /// The pilot this device follows, as this partner sees them.
    let pilot: String
    /// "iPhone" or "iPad".
    let deviceModel: String

    var title: String { "Disconnect from \(pilot)?" }
    var message: String {
        "You'll stop seeing \(pilot)'s status on this \(deviceModel). To connect again, tap the invite link \(pilot) sent you."
    }

    static let failureTitle = "Couldn't Disconnect"
    static let failureMessage = "Couldn't disconnect. Check your connection and try again."
}
