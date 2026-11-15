//
//  ComparisonPicker.swift
//  CrewLuve
//
//  What a distance is like (Stage 2 spec §4.9): "Like driving coast to coast", "Like rafting the Grand Canyon twice".
//  The entries are the app's comparisons.json, which the website shares.
//

import Foundation

nonisolated struct ComparisonPicker: Sendable {

    nonisolated struct Entry: Decodable, Sendable {
        let miles: Double
        /// Used once: "Like driving coast to coast".
        let one: String
        /// Used 2 to 10 times. `{n}` is the number and `{times}` is "twice" or "3 times".
        let many: String
    }

    let entries: [Entry]

    init(entries: [Entry]) {
        self.entries = entries
    }

    init(data: Data) throws {
        entries = try JSONDecoder().decode([Entry].self, from: data)
    }

    /// The app's copy, or nil (logged) if it's missing or unreadable.
    static func loadBundled(from bundle: Bundle = .main) -> ComparisonPicker? {
        guard let url = bundle.url(forResource: "comparisons", withExtension: "json") else {
            debugLog("ComparisonPicker: comparisons.json isn't in the bundle")
            return nil
        }
        do {
            return try ComparisonPicker(data: Data(contentsOf: url))
        } catch {
            debugLog("ComparisonPicker: couldn't read comparisons.json: \(error)")
            return nil
        }
    }

    /// The entry whose multiple is closest to a whole number from 1 to 10. Ties go to the smaller number, then to the
    /// earlier entry. Nil when no entry fits.
    func phrase(forMiles miles: Double) -> String? {
        var best: (entry: Entry, count: Int, error: Double)?
        for entry in entries where entry.miles > 0 {
            let multiple = miles / entry.miles
            // The nearest whole number, with a half going to the smaller one.
            // The nearest whole number, with a half going to the smaller one. Checked as a Double first, so an
            // infinite or enormous distance can't trap in the conversion.
            let rounded = (multiple - 0.5).rounded(.up)
            guard (1...10).contains(rounded) else { continue }
            let count = Int(rounded)
            let error = abs(multiple - Double(count))
            if let current = best, error > current.error || (error == current.error && count >= current.count) { continue }
            best = (entry, count, error)
        }
        guard let best else { return nil }
        guard best.count > 1 else { return best.entry.one }
        return best.entry.many
            .replacingOccurrences(of: "{n}", with: "\(best.count)")
            .replacingOccurrences(of: "{times}", with: Self.times(best.count))
    }

    /// "twice", "3 times".
    static func times(_ count: Int) -> String {
        count == 2 ? "twice" : "\(count) times"
    }
}
