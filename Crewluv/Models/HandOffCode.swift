//
//  HandOffCode.swift
//  CrewLuve
//
//  A code another of this partner's devices joins with
//

import Foundation

/// A code another of this partner's devices joins with (partner links piece 4 spec §7.5):
/// partner_handoff_create's answer. It works once, until `expiresAt`, 10 minutes after it was made.
nonisolated struct HandOffCode: Equatable, Sendable {
    let code: String
    let expiresAt: Date

    /// The code as Use on Another Device shows it, in two groups of three: "K7M Q2X".
    var grouped: String {
        "\(code.prefix(3)) \(code.dropFirst(3))"
    }

    /// The link the QR code holds. The other device's camera opens Crewluve with it.
    var link: String {
        "https://\(PartnerLink.host)/join#c=\(code)"
    }

    /// "9:41 left · works once": the time left at `now`, rounded up, so 0:00 means it has run out.
    func countdown(at now: Date) -> String {
        let left = max(0, Int(expiresAt.timeIntervalSince(now).rounded(.up)))
        let seconds = left % 60
        return "\(left / 60):\(seconds < 10 ? "0" : "")\(seconds) left · works once"
    }

    func hasExpired(at now: Date) -> Bool {
        now >= expiresAt
    }
}
