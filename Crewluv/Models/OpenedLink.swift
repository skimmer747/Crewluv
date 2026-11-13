//
//  OpenedLink.swift
//  CrewLuve
//
//  What a link the app was given, or pasted text, is
//

import Foundation

/// What a link the app was given, or text pasted into the paste box, is (partner links piece 4
/// spec §7.1, §7.4): one of Crewluve's own links or a code, which the joiner takes; an iCloud share
/// link, which today's share handling takes, since pilots on an older CrewLu still send them; or
/// neither.
nonisolated enum OpenedLink: Equatable, Sendable {
    case partner(PartnerLink)
    case iCloudShare(URL)
    case neither

    init(url: URL) {
        if let link = PartnerLink(url: url) {
            self = .partner(link)
        } else if ShareURLResolver.isShareURL(url) {
            self = .iCloudShare(url)
        } else {
            self = .neither
        }
    }

    init(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let link = PartnerLink(text: trimmed) {
            self = .partner(link)
        } else if let url = URL(string: trimmed) {
            self = OpenedLink(url: url)
        } else {
            self = .neither
        }
    }
}
