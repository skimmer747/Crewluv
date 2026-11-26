//
//  TripMapWording+Source.swift
//  CrewLuve
//
//  How the words say where a flight comes from, live or by the schedule (live or scheduled design §4, §6, §7): the
//  pill and the card's bar, and the card's VoiceOver sentence.
//

import Foundation

nonisolated extension TripMapWording {

    // MARK: - How it's known

    /// A flight known by the schedule alone: the pill, the card's bar and the facts' first row.
    static let notTrackedLive = "Not tracked live"
    /// The facts' first row for a flight Crewlu Cloud sees now.
    static let trackedLive = "Tracked live"
    /// A flight in the air with a real path in a replay, and a best guess with no label.
    static let inFlight = "In flight"
    /// The list's tag for a flight known by the schedule alone, and a replay's pill for one with no real path (§6).
    static let byTheSchedule = "By the schedule"
    /// Why the schedule's plane may not be where it's drawn, in the facts' first row and the schedule plane's popup
    /// (which plane design §3).
    static let mayBeAtGate = "If it's running late, it may still be at the gate"
    /// "Not tracked live, so it's shown where the schedule has it": why the schedule's own plane is where it is, in
    /// its popup (which plane design §3) and the card's VoiceOver sentence.
    static let notTrackedSoBySchedule = "\(notTrackedLive), so it's shown where the schedule has it"
    /// The card's VoiceOver sentence for a flight by the schedule alone (§7).
    static let spokenNotTracked = "\(notTrackedSoBySchedule)."

    /// What the card's VoiceOver sentence says of where the flight comes from (§7): "Tracked live." while Crewlu Cloud
    /// sees it, "Not tracked live, so …" by the schedule alone, and nothing for a best guess, whose sentence says
    /// where it was last tracked, or while the first answer is on its way.
    static func spokenSource(for leg: MapLeg, at now: Date) -> String? {
        switch leg.tracking(at: now) {
        case .live: "\(trackedLive)."
        case .notTracked: spokenNotTracked
        case .bestGuess, .waiting: nil
        }
    }

    /// ", scheduled to take off about 3:14 PM your time": a flight by the schedule alone, before its takeoff (§7).
    /// Empty otherwise.
    static func spokenDueClause(for leg: MapLeg, at now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard leg.atDeparture(at: now) == .due else { return "" }
        return ", scheduled to take off about \(clockTime(leg.scheduledTakeoff, in: calendar.timeZone, locale: locale)) your time"
    }

    /// `sentence` and then where the flight comes from, `spokenSource`, if it says anything (§7).
    static func withSource(_ sentence: String, for leg: MapLeg, at now: Date) -> String {
        [sentence, spokenSource(for: leg, at: now)].compactMap { $0 }.joined(separator: " ")
    }

    // MARK: - The pill and the bar

    /// What the card's bar and the full-screen pill say of a flight between its gates (Stage 3 spec §9, live or
    /// scheduled design §4.1): how it's known, then the real plane's label.
    /// - Seen now, "Live · 12 min ahead", or "Live" alone with no label; back at its departure airport after an air
    ///   return, "Live · Returned to Rockford" (air return design §3).
    /// - A best guess, its label alone, "About 12 min ahead", or "In flight" with no label.
    /// - By the schedule alone, "Not tracked live", and nothing while Crewlu Cloud's first answer is on its way.
    /// - A moment of the replay is "In flight" for a flight with a real path, and "By the schedule" for one without (§6).
    /// - Parameter now: the moment, by this device's clock.
    static func flightStatus(for leg: MapLeg, at now: Date, isReplay: Bool = false) -> String {
        if isReplay { return leg.flight?.path.isReal == true ? inFlight : byTheSchedule }
        let words = leg.flight?.progress(at: now).label.map { $0 == .returned ? FactsWording.returned(to: leg.origin) : liveLabel($0) }
        switch leg.tracking(at: now) {
        case .live: return words.map { "Live · \($0)" } ?? "Live"
        case .bestGuess: return words ?? inFlight
        case .notTracked: return notTrackedLive
        case .waiting: return ""
        }
    }
}
