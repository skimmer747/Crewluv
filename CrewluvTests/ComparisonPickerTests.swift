//
//  ComparisonPickerTests.swift
//  CrewluvTests
//
//  Picking a comparison for a distance (Stage 2 spec §4.9), from the app's comparisons.json.
//

import XCTest
@testable import Crewluv

final class ComparisonPickerTests: XCTestCase {

    private func picker() throws -> ComparisonPicker {
        let url = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Crewluv/Resources/TripMap/comparisons.json")
        return try ComparisonPicker(data: Data(contentsOf: url))
    }

    func test_init_theAppsFile_hasElevenEntries() throws {
        XCTAssertEqual(try picker().entries.count, 11)
    }

    func test_phrase_aboutOnce_usesTheOnePhrase() throws {
        XCTAssertEqual(try picker().phrase(forMiles: 4_100), "Like sailing the length of the Nile")
        XCTAssertEqual(try picker().phrase(forMiles: 2_980), "Like driving coast to coast")
    }

    func test_phrase_twice_saysTwice() throws {
        XCTAssertEqual(try picker().phrase(forMiles: 600), "Like rafting the Grand Canyon twice")
    }

    func test_phrase_severalTimes_saysTheCount() throws {
        XCTAssertEqual(try picker().phrase(forMiles: 9_800), "Like driving the Alaska Highway 7 times")
        XCTAssertEqual(try picker().phrase(forMiles: 200), "Like sailing the Panama Canal 4 times")
    }

    func test_phrase_marathons_putsTheNumberInTheMiddle() {
        let picker = ComparisonPicker(entries: [.init(miles: 26.2, one: "Like running a marathon", many: "Like running {n} marathons")])
        XCTAssertEqual(picker.phrase(forMiles: 26.2 * 7), "Like running 7 marathons")
    }

    func test_phrase_noEntryOneToTenTimes_isNil() throws {
        XCTAssertNil(try picker().phrase(forMiles: 10))
        XCTAssertNil(try picker().phrase(forMiles: 300_000))
    }

    func test_phrase_aHalf_goesToTheSmallerNumber() {
        let picker = ComparisonPicker(entries: [.init(miles: 100, one: "Once", many: "{n} times")])
        XCTAssertEqual(picker.phrase(forMiles: 150), "Once")
        XCTAssertEqual(picker.phrase(forMiles: 151), "2 times")
    }

    func test_phrase_aTie_goesToTheSmallerNumberThenTheEarlierEntry() {
        let picker = ComparisonPicker(entries: [
            .init(miles: 100, one: "A once", many: "A {n}"),
            .init(miles: 50, one: "B once", many: "B {n}"),
            .init(miles: 100, one: "C once", many: "C {n}"),
        ])
        // 200 mi is exactly 2 × A, 4 × B and 2 × C: the smaller number wins, then the earlier entry.
        XCTAssertEqual(picker.phrase(forMiles: 200), "A 2")
    }

    func test_times_twoIsTwice() {
        XCTAssertEqual(ComparisonPicker.times(2), "twice")
        XCTAssertEqual(ComparisonPicker.times(3), "3 times")
    }
}
