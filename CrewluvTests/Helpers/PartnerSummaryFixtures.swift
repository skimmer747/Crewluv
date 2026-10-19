//
//  PartnerSummaryFixtures.swift
//  CrewluvTests
//
//  Reads Fixtures/PartnerSummary: CrewLu's example summaries as Crewlu Cloud gives them
//  to partners A and B (see its README).
//

import Foundation
@testable import Crewluv

enum PartnerSummaryFixtures {
    static let partnerA = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
    static let partnerB = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"

    static let examples = [
        "commuting-home", "display-names", "hidden-trip-left-out", "home", "in-flight",
        "layover", "quick-status-everyone", "quick-status-one-partner", "turn",
    ]

    /// Found beside this file on the Mac's disk, which tests on a simulator can read.
    static let folder = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/PartnerSummary")

    static var areReachable: Bool {
        FileManager.default.fileExists(atPath: folder.path(percentEncoded: false))
    }

    /// Partner A's or B's id, by letter.
    static func partnerID(_ letter: String) -> String {
        letter == "A" ? partnerA : partnerB
    }

    /// The `status` partner_view gives that partner, as sent.
    static func data(_ example: String, partner letter: String) throws -> Data {
        try Data(contentsOf: folder.appending(path: "\(example).\(letter).json"))
    }

    /// The same, as a dictionary to change or compare.
    static func json(_ example: String, partner letter: String) throws -> [String: Any] {
        guard let json = try JSONSerialization.jsonObject(with: data(example, partner: letter)) as? [String: Any] else {
            throw CocoaError(.coderReadCorrupt)
        }
        return json
    }

    @MainActor
    static func summary(_ example: String, partner letter: String) throws -> CloudSummary {
        try decode(data(example, partner: letter))
    }

    /// A summary from a dictionary, such as a fixture with a field changed.
    @MainActor
    static func summary(_ json: [String: Any]) throws -> CloudSummary {
        try decode(JSONSerialization.data(withJSONObject: json))
    }

    @MainActor
    private static func decode(_ data: Data) throws -> CloudSummary {
        try CloudSummary.decoder().decode(CloudSummary.self, from: data)
    }
}
