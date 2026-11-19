//
//  ClockLabelTests.swift
//  CrewluvTests
//
//  Whose time a time is (time labels design §3.1): the shared cases, which the website runs too, and what VoiceOver
//  and the hover tip make of a label.
//

import XCTest
@testable import Crewluv

final class ClockLabelTests: XCTestCase {

    private struct Cases: Decodable {
        struct Case: Decodable {
            let name: String
            let kind: String
            let at: Date
            let yourZone: String
            let zone: String?
            let city: String?
            let locale: String
            let expected: String
        }

        let cases: [Case]
    }

    private func cases() throws -> [Cases.Case] {
        let data = try Data(contentsOf: TripMapFixtures.folder.appending(path: "clock-label-cases.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Cases.self, from: data).cases
    }

    /// Formatters may put a narrow space before AM or PM: the cases are written with a plain one.
    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private func zone(_ identifier: String) throws -> TimeZone {
        try XCTUnwrap(TimeZone(identifier: identifier), identifier)
    }

    // MARK: - The shared cases

    func test_everySharedCase_readsAsTheWebsiteReadsIt() throws {
        let all = try cases()
        XCTAssertEqual(all.count, 15)
        for shared in all {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try zone(shared.yourZone)
            let locale = Locale(identifier: shared.locale)
            let words: String
            switch shared.kind {
            case "yours":
                words = ClockLabel.yours(shared.at, calendar: calendar, locale: locale)
            case "place":
                words = ClockLabel.place(shared.at, in: try zone(XCTUnwrap(shared.zone)), city: try XCTUnwrap(shared.city), locale: locale)
            case "pair":
                words = ClockLabel.pair(shared.at, in: try shared.zone.map(zone), calendar: calendar, locale: locale)
            case "key":
                words = ClockLabel.key(calendar: calendar, at: shared.at, locale: locale)
            default:
                XCTFail("\(shared.name): no kind \(shared.kind)")
                continue
            }
            XCTAssertEqual(plain(words), shared.expected, shared.name)
        }
    }

    // MARK: - VoiceOver

    func test_spoken_aTwelveHourTime_saysYourTime() {
        XCTAssertEqual(plain(ClockLabel.spoken("Lands Anchorage 12:35\u{202F}PM · 4:35\u{202F}PM L")),
                       "Lands Anchorage 12:35 PM · 4:35 PM your time")
    }

    func test_spoken_aTwentyFourHourTime_saysYourTime() {
        XCTAssertEqual(ClockLabel.spoken("Halfway at about 16:35 L"), "Halfway at about 16:35 your time")
    }

    func test_spoken_aTimeMidLine_saysYourTime_andKeepsWhatFollows() {
        XCTAssertEqual(plain(ClockLabel.spoken("Sat 1:40\u{202F}PM L · Layover in Denver")),
                       "Sat 1:40 PM your time · Layover in Denver")
    }

    func test_spoken_anLThatStartsAWord_isLeftAlone() {
        XCTAssertEqual(ClockLabel.spoken("Out over the Pacific at 9 Lisbon"), "Out over the Pacific at 9 Lisbon")
        XCTAssertEqual(plain(ClockLabel.spoken("4:35\u{202F}PM Lands")), "4:35 PM Lands")
    }

    func test_spoken_aCityStartingWithLAndAnApostrophe_isLeftAlone() {
        XCTAssertEqual(plain(ClockLabel.spoken("sunrise at 7:02\u{202F}AM L'Aquila")), "sunrise at 7:02 AM L'Aquila")
    }

    func test_spoken_aWordEndingInAm_isLeftAlone() {
        XCTAssertEqual(ClockLabel.spoken("Over Birmingham L"), "Over Birmingham L")
    }

    func test_spoken_aCitysTime_isLeftAlone() {
        XCTAssertEqual(plain(ClockLabel.spoken("sunrise at 7:02\u{202F}AM Cologne")), "sunrise at 7:02 AM Cologne")
    }

    // MARK: - The hover tip

    func test_hasMark_aMarkedTime_isTrue_andACitysIsNot() {
        XCTAssertTrue(ClockLabel.hasMark("Halfway at about 12:05\u{202F}PM L"))
        XCTAssertTrue(ClockLabel.hasMark("Halfway at 16:35 L"))
        XCTAssertFalse(ClockLabel.hasMark("sunrise at 7:02\u{202F}AM Cologne"))
        XCTAssertFalse(ClockLabel.hasMark("2,140 mi flown · 1,960 to go"))
    }

    // MARK: - The zone's name

    func test_zoneName_followsSummerTime() throws {
        let newYork = try zone("America/New_York")
        let winter = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z"))
        let summer = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-15T12:00:00Z"))
        let english = Locale(identifier: "en_US")
        XCTAssertEqual(ClockLabel.zoneName(newYork, at: winter, locale: english), "Eastern Standard Time")
        XCTAssertEqual(ClockLabel.zoneName(newYork, at: summer, locale: english), "Eastern Daylight Time")
    }

    func test_zoneName_aZoneWithNoSummerTime_isItsStandardName() throws {
        let summer = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-15T12:00:00Z"))
        XCTAssertEqual(ClockLabel.zoneName(try zone("America/Phoenix"), at: summer, locale: Locale(identifier: "en_US")),
                       "Mountain Standard Time")
    }
}
