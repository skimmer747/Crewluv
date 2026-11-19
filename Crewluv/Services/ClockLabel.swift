//
//  ClockLabel.swift
//  CrewLuve
//
//  Whose time a time is (time labels design §2, §3.1): the family's own is marked "L", a city's is followed by its
//  name. `TripMapWording.clockTime` formats a time; this labels it. VoiceOver reads the "L" as "your time".
//

import Foundation

nonisolated enum ClockLabel {

    /// The mark after the family's own time: "4:35 PM L".
    static let mark = "L"

    /// "4:35 PM L": `date` in the family's time, `calendar`'s zone.
    static func yours(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "\(TripMapWording.clockTime(date, in: calendar.timeZone, locale: locale)) \(mark)"
    }

    /// "7:02 AM Cologne": `date` in `zone`, the city's.
    static func place(_ date: Date, in zone: TimeZone, city: String, locale: Locale = .current) -> String {
        "\(TripMapWording.clockTime(date, in: zone, locale: locale)) \(city)"
    }

    /// "12:35 PM · 4:35 PM L": `date` in a city the line has just named, then in the family's time. The family's
    /// alone, "4:35 PM L", where the city keeps their clock at `date` or its zone isn't known.
    static func pair(_ date: Date, in zone: TimeZone?, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let yours = yours(date, calendar: calendar, locale: locale)
        guard let zone, !keepsTheSameClock(zone, as: calendar.timeZone, at: date) else { return yours }
        return "\(TripMapWording.clockTime(date, in: zone, locale: locale)) · \(yours)"
    }

    /// The key under the facts and the status: "L = your time (Eastern Standard Time)", by the zone's name at `date`.
    static func key(calendar: Calendar = .current, at date: Date, locale: Locale = .current) -> String {
        "\(mark) = your time (\(zoneName(calendar.timeZone, at: date, locale: locale)))"
    }

    /// "Eastern Standard Time", or "Eastern Daylight Time" while the zone keeps summer time at `date`.
    static func zoneName(_ zone: TimeZone, at date: Date, locale: Locale = .current) -> String {
        let style: NSTimeZone.NameStyle = zone.isDaylightSavingTime(for: date) ? .daylightSaving : .standard
        return zone.localizedName(for: style, locale: locale) ?? zone.identifier
    }

    /// Whether `zone` reads the same clock as `yours` at `date`.
    static func keepsTheSameClock(_ zone: TimeZone, as yours: TimeZone, at date: Date) -> Bool {
        zone.secondsFromGMT(for: date) == yours.secondsFromGMT(for: date)
    }

    // MARK: - VoiceOver and the hover tip

    /// The words as VoiceOver reads them: "Lands Anchorage 12:35 PM · 4:35 PM L" says "… 4:35 PM your time".
    static func spoken(_ text: String) -> String {
        text.replacing(markAfterATime) { match in "\(match.output.1) your time" }
    }

    /// Whether `text` holds a time marked "L", so its row offers the key as a hover tip.
    static func hasMark(_ text: String) -> Bool {
        text.contains(markAfterATime)
    }

    /// " L" straight after a time, its last digit or the AM or PM after its digits, and not the start of a word such
    /// as "Lisbon" or "L'Aquila". Made once: the full-screen map asks up to 60 times a second.
    nonisolated(unsafe) private static let markAfterATime = #/([0-9](?:[ \u{202F}]?[AaPp][Mm])?) L(?![\p{L}'’])/#
}
