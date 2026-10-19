//
//  PartnerLink.swift
//  CrewLuve
//
//  An invite link, a code link, or a typed code
//

import Foundation

/// What a link, pasted text or a typed code asks Crewluve to join (partner links piece 4 spec §7.1).
/// Crewluve's own links are `https://crewluve.crewlu.net/join#t=<invite>` and `…/join#c=<code>`.
/// Their secret is only after the `#`, so it never reaches a server log.
nonisolated enum PartnerLink: Equatable, Sendable {
    /// The pilot's invite, joined with partner_join.
    case invite(String)
    /// A code from another of this partner's devices, joined with partner_handoff_redeem.
    case code(String)

    static let host = "crewluve.crewlu.net"

    /// Reads one of Crewluve's own links. Nil for any other link, such as an iCloud share link,
    /// which today's share handling takes. A trailing slash is tolerated, though no link has one.
    init?(url: URL) {
        guard url.scheme?.lowercased() == "https",
              url.host()?.lowercased() == Self.host,
              url.path() == "/join" || url.path() == "/join/",
              let fragment = url.fragment(percentEncoded: true)
        else { return nil }

        for pair in fragment.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2, let value = String(parts[1]).removingPercentEncoding else { continue }
            switch parts[0] {
            case "t":
                self = .invite(value)
                return
            case "c":
                if let code = Self.code(from: value) {
                    self = .code(code)
                    return
                }
            default:
                continue
            }
        }
        return nil
    }

    /// Reads pasted or typed text: one of Crewluve's links, perhaps with spaces or line breaks around
    /// it, or a code.
    init?(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), let link = PartnerLink(url: url) {
            self = link
        } else if let code = Self.code(from: trimmed) {
            self = .code(code)
        } else {
            return nil
        }
    }

    /// A code as the door takes it: 6 letters or digits in capitals, from text in any case that may
    /// hold spaces or dashes. Nil for anything else.
    static func code(from text: String) -> String? {
        let code = text.filter { $0 != " " && $0 != "-" }.uppercased()
        guard code.count == 6, code.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        return code
    }

    /// What the code boxes keep of their text (spec §7.4): letters and digits in capitals, at most six.
    static func codeBoxes(_ text: String) -> String {
        String(text.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.uppercased().prefix(6))
    }

    /// How logs show a link: one of Crewluve's own only by its host and path, since what follows the
    /// `#` is a secret (spec §9). Any other link as it is.
    static func logDescription(of url: URL) -> String {
        guard let host = url.host(), host.lowercased() == Self.host else { return url.absoluteString }
        return host + url.path()
    }
}
