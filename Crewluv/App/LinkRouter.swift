//
//  LinkRouter.swift
//  CrewLuve
//
//  Sends a link the app was given, or pasted text, where it goes
//

import CloudKit
import Foundation

/// Sends a link the app was given, or text pasted into the paste box, where it goes (partner links
/// piece 4 spec §7.1): Crewluve's own links and codes to the joiner, and iCloud share links to
/// today's share handling, unless this device is on Crewlu Cloud (§16).
enum LinkRouter {
    /// A link the app was given: a tap, a universal link or a cold launch. False when it's neither
    /// kind, and then nothing happens.
    @discardableResult
    static func open(_ url: URL) -> Bool {
        go(OpenedLink(url: url))
    }

    /// Text pasted into the paste box. Anything else gets "Not an Invite Link".
    static func paste(_ text: String) {
        if !go(OpenedLink(text: text)) {
            PartnerJoiner.shared.message = .notAnInviteLink
        }
    }

    /// An iCloud share iOS hands the app when its link is tapped: accepted as today, unless this
    /// device is on Crewlu Cloud (spec §16).
    static func accept(_ metadata: CKShare.Metadata) {
        guard PartnerJoiner.shared.mayAcceptICloudShare() else { return }
        Task { await CloudKitShareManager.shared.acceptShare(with: metadata) }
    }

    private static func go(_ link: OpenedLink) -> Bool {
        switch link {
        case .partner(let link):
            Task { await PartnerJoiner.shared.join(link) }
            return true
        case .iCloudShare(let url):
            if PartnerJoiner.shared.mayAcceptICloudShare() {
                Task { try? await CloudKitShareManager.shared.acceptShare(from: url) }
            }
            return true
        case .neither:
            return false
        }
    }
}
