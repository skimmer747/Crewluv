//
//  AlertCasesTests.swift
//  CrewluvTests
//
//  The alert pushes' shared cases: this app's alerts for each change, which Crewlu Cloud's partner-push must
//  match kind for kind (alert pushes spec §9.1, §15)
//

import Foundation
import Testing
@testable import Crewluv

/// The alerts a test's notifier posts, kept in order.
final class PostedAlerts: @unchecked Sendable {
    private let lock = NSLock()
    private var specs: [StatusChangeNotifier.NotificationSpec] = []

    func add(_ spec: StatusChangeNotifier.NotificationSpec) {
        lock.withLock { specs.append(spec) }
    }

    var all: [StatusChangeNotifier.NotificationSpec] {
        lock.withLock { specs }
    }
}

@MainActor
@Suite(.enabled(if: PartnerSummaryFixtures.areReachable, "reads its cases from the Mac's disk"))
struct AlertCasesTests {

    /// The cases file, a copy of CrewLu's `supabase/partner-status/alert-cases.json`.
    private static func file() throws -> [String: Any] {
        let data = try Data(contentsOf: PartnerSummaryFixtures.folder.appending(path: "alert-cases.json"))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// The case's summary: the file's base with the case's fields over it, as Crewlu Cloud gives it to the partner.
    private static func summary(_ fields: [String: Any], base: [String: Any]) throws -> CloudSummary {
        let json = base.merging(fields) { $1 }
        return try CloudSummary.decoder().decode(CloudSummary.self, from: JSONSerialization.data(withJSONObject: json))
    }

    /// What the app does with one reading of `summary` at `moment`: the reading the source makes, titled with the
    /// name the pilot set for this partner, as the source titles it.
    private static func read(_ summary: CloudSummary, partner: String, at moment: TimeInterval, by notifier: StatusChangeNotifier) async {
        let reading = PilotReading.crewluCloud(summary, partnerID: partner, updatedAt: nil)
        await notifier.evaluate(reading, titledWith: summary.displayName(for: partner), at: Date(timeIntervalSince1970: moment))
    }

    @Test func test_everySharedCase_givesItsAlerts_inTheirWords() async throws {
        let file = try Self.file()
        let base = try #require(file["base"] as? [String: Any])
        let zone = try #require(file["timeZone"] as? String)
        let timeZone = try #require(TimeZone(identifier: zone))
        let cases = try #require(file["cases"] as? [[String: Any]])
        #expect(cases.count == 57)

        for item in cases {
            let name = try #require(item["name"] as? String)
            let partner = try #require(item["partner"] as? String)
            let suite = "AlertCasesTests.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let posted = PostedAlerts()
            let notifier = StatusChangeNotifier(defaults: defaults, timeZone: timeZone, post: { posted.add($0) })

            if let before = item["before"] as? [String: Any] {
                let beforeAt = try #require(item["beforeAt"] as? TimeInterval)
                await Self.read(try Self.summary(before, base: base), partner: partner, at: beforeAt, by: notifier)
            }
            let after = try #require(item["after"] as? [String: Any])
            let afterAt = try #require(item["afterAt"] as? TimeInterval)
            await Self.read(try Self.summary(after, base: base), partner: partner, at: afterAt, by: notifier)

            let expected = try #require(item["alerts"] as? [[String: Any]]).map { alert in
                "\(alert["kind"] ?? "") \(alert["sound"] as? Bool == true ? "sound" : "silent") \(alert["title"] ?? "") | \(alert["body"] ?? "")"
            }
            let got = posted.all.map { "\($0.kind.rawValue) \($0.playsSound ? "sound" : "silent") \($0.title) | \($0.body)" }
            #expect(got == expected, "\(name)")
        }
    }

    @Test func test_everyKind_hasACase() throws {
        let cases = try #require(try Self.file()["cases"] as? [[String: Any]])
        let kinds = Set(cases.flatMap { ($0["alerts"] as? [[String: Any]] ?? []).compactMap { $0["kind"] as? String } })
        #expect(kinds == Set(AlertKind.allCases.map(\.rawValue)))
    }
}
