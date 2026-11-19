//
//  PlanePopupWords.swift
//  CrewLuve
//
//  What a plane's popup on the full-screen map says (which plane design §3): which plane it is, then what the card's
//  bar says of it, with when it lands, in this device's time zone and clock, marked "L" (time labels design §3.2).
//  Nothing else writes them.
//

import Foundation

/// Which of a flight's two planes: the real one, or the ghost where an on-schedule plane would be.
nonisolated enum PlaneKind: Equatable, Sendable {
    case realPlane
    case ghost
}

nonisolated struct PlanePopupWords: Equatable, Sendable {
    let title: String
    /// A line or two under the title. None for a real plane down somewhere else, which has no label and no landing
    /// time to give.
    let lines: [String]

    init(title: String, lines: [String]) {
        self.title = title
        self.lines = lines
    }

    /// The popup on one of `leg`'s planes at `date`: now, or a moment of the replay when `isReplay`.
    init(leg: MapLeg, plane: PlaneKind, at date: Date, isReplay: Bool,
         calendar: Calendar = .current, locale: Locale = .current) {
        let name = leg.flightNumber ?? "the flight"
        func time(_ date: Date) -> String { ClockLabel.yours(date, calendar: calendar, locale: locale) }
        guard plane == .realPlane else {
            self.init(title: "On schedule", lines: ["Where \(name) was scheduled to be"])
            return
        }
        let title = "\(Self.capitalized(name)) · real plane"
        if isReplay {
            self.init(title: title, lines: ["Where it was at \(time(date))"])
            return
        }
        guard let flight = leg.flight else {
            self.init(title: title, lines: [])
            return
        }
        let progress = flight.progress(at: date)
        let label = progress.label.map(TripMapWording.liveLabel)
        let about = TripMapWording.about(leg)
        switch progress.phase {
        case .estimated:
            let seen = flight.live?.fix.map { "Out of tracking range since \(time($0.seenAt)), so it's shown where it should be by now" }
            let lands = "lands \(about)\(time(leg.end))"
            self.init(title: "\(Self.capitalized(name)) · best guess",
                      lines: [seen, label.map { "\($0) · \(lands)" } ?? Self.capitalized(lands)].compactMap { $0 })
        case .onGround, .inAir:
            self.init(title: title, lines: [label, TripMapWording.landsAt(for: leg, calendar: calendar, locale: locale)].compactMap { $0 })
        case .returned:
            // Back at its departure airport after an air return, which it names (air return design §3).
            self.init(title: title, lines: [FactsWording.returned(to: leg.origin),
                                            TripMapWording.landsAt(for: leg, calendar: calendar, locale: locale)])
        case .landed:
            // "at" the gate, as the card's sentence says once the plane is down, or "about" while that's still an estimate.
            self.init(title: title, lines: [label, "Reaches the gate \(about.isEmpty ? "at " : about)\(time(leg.end))"].compactMap { $0 })
        case .notLive, .elsewhere:
            // Down somewhere else: it has no label, and no landing time to give.
            self.init(title: title, lines: [])
        }
    }

    /// "the flight" → "The flight".
    private static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}
