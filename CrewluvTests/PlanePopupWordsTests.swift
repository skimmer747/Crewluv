//
//  PlanePopupWordsTests.swift
//  CrewluvTests
//
//  What a plane's popup on the full-screen map says (which plane design §3), in US English for a family in
//  Louisville, on the shared cases' flights.
//

import XCTest
@testable import Crewluv

final class PlanePopupWordsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    /// iOS writes a narrow no-break space before AM and PM; the tests read it as a plain space.
    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// A shared case's flight at one of its moments, as a leg of the map.
    private func leg(of name: String, moment index: Int = 0) throws -> (leg: MapLeg, at: Date) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let moment = flightCase.moments[index]
        return (try cases.mapLeg(flightCase, at: moment), moment.at)
    }

    private func words(on leg: MapLeg, _ plane: PlaneKind = .realPlane, at date: Date, isReplay: Bool = false,
                       calendar: Calendar? = nil, locale: Locale? = nil) -> PlanePopupWords {
        let words = PlanePopupWords(leg: leg, plane: plane, at: date, isReplay: isReplay, calendar: calendar ?? self.calendar,
                                    locale: locale ?? self.locale)
        return PlanePopupWords(title: plain(words.title), lines: words.lines.map(plain))
    }

    /// The real plane's popup in a shared case's moment, now.
    private func realPlane(_ name: String, moment index: Int = 0) throws -> PlanePopupWords {
        let (leg, at) = try leg(of: name, moment: index)
        return words(on: leg, at: at)
    }

    // MARK: - Each plane

    func test_ghost_isOnSchedule_whereTheFlightWasScheduledToBe() throws {
        let (leg, at) = try leg(of: "ahead, in the air")
        XCTAssertEqual(words(on: leg, .ghost, at: at), PlanePopupWords(title: "On schedule", lines: ["Where UPS207 was scheduled to be"]))
    }

    func test_realPlaneInTheAir_saysTheBarsWords_andWhenItLands() throws {
        XCTAssertEqual(try realPlane("ahead, in the air"),
                       PlanePopupWords(title: "UPS207 · real plane", lines: ["14 min ahead", "Lands about 8:30 AM L"]))
    }

    func test_realPlaneStillAtTheGate_afterItsTakeoffTime_saysSo() throws {
        XCTAssertEqual(try realPlane("still on the ground twenty minutes after"),
                       PlanePopupWords(title: "UPS207 · real plane", lines: ["Still on the ground · 20 min behind", "Lands about 9:05 AM L"]))
    }

    func test_realPlaneWithNoLabel_beforeItsTakeoffTime_landsOnTheSchedulesTime_withNoAbout() throws {
        XCTAssertEqual(try realPlane("on the ground before the plan's takeoff"),
                       PlanePopupWords(title: "UPS207 · real plane", lines: ["Lands 8:45 AM L"]))
    }

    func test_fadedPlane_isABestGuess_saysWhenItWentOutOfTrackingRange_andLandsAbout() throws {
        // Last seen at 12:41:40 UTC, 7:41 AM in Louisville.
        XCTAssertEqual(try realPlane("ahead, in the air", moment: 2),
                       PlanePopupWords(title: "UPS207 · best guess",
                                       lines: ["Out of tracking range since 7:41 AM L, so it's shown where it should be by now",
                                               "About 14 min ahead · lands about 8:30 AM L"]))
    }

    func test_landedPlane_saysWhenItReachesTheGate() throws {
        XCTAssertEqual(try realPlane("landed, seen all the way"),
                       PlanePopupWords(title: "UPS207 · real plane", lines: ["Landed 23 min early", "Reaches the gate at 8:21 AM L"]))
    }

    func test_planeDownSomewhereElse_saysOnlyWhichPlaneItIs() throws {
        XCTAssertEqual(try realPlane("on the ground somewhere else"), PlanePopupWords(title: "UPS207 · real plane", lines: []))
    }

    func test_flightWithNoLiveData_saysOnlyWhichPlaneItIs() throws {
        XCTAssertEqual(try realPlane("no live data"), PlanePopupWords(title: "UPS207 · real plane", lines: []))
        let (leg, at) = try leg(of: "ahead, in the air")
        let scheduleOnly = MapLeg(id: leg.id, kind: .flight, origin: leg.origin, destination: leg.destination,
                                  start: leg.start, end: leg.end, flightNumber: leg.flightNumber)
        XCTAssertEqual(words(on: scheduleOnly, at: at), PlanePopupWords(title: "UPS207 · real plane", lines: []))
    }

    func test_replay_saysWhereTheRealPlaneWasAtTheMoment() throws {
        let (leg, at) = try leg(of: "ahead, in the air")
        XCTAssertEqual(words(on: leg, at: at, isReplay: true),
                       PlanePopupWords(title: "UPS207 · real plane", lines: ["Where it was at 7:41 AM L"]))
    }

    // MARK: - Names and clocks

    func test_flightWithNoNumber_isTheFlight() throws {
        let (leg, at) = try leg(of: "ahead, in the air")
        let unnamed = MapLeg(id: leg.id, kind: .flight, origin: leg.origin, destination: leg.destination,
                             start: leg.start, end: leg.end, flightNumber: nil, flight: leg.flight)
        XCTAssertEqual(words(on: unnamed, .ghost, at: at).lines, ["Where the flight was scheduled to be"])
        XCTAssertEqual(words(on: unnamed, at: at).title, "The flight · real plane")
    }

    func test_timesFollowThisDevicesTimeZoneAndClock() throws {
        let (leg, at) = try leg(of: "ahead, in the air")
        var cologne = Calendar(identifier: .gregorian)
        cologne.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        // 12:41:50 UTC is 1:41 PM in Cologne, on a 24-hour clock there.
        XCTAssertEqual(words(on: leg, at: at, isReplay: true, calendar: cologne, locale: Locale(identifier: "de_DE")).lines,
                       ["Where it was at 13:41 L"])
        XCTAssertEqual(words(on: leg, at: at, calendar: cologne, locale: Locale(identifier: "de_DE")).lines,
                       ["14 min ahead", "Lands about 14:30 L"])
    }

    // MARK: - The shared cases

    func test_everySharedMomentTheRealPlaneShows_saysTheCardsBarsWords() throws {
        let cases = try TripMapFixtures.liveCases()
        var checked = 0
        for flightCase in cases.flights where flightCase.flight != nil {
            for (index, moment) in flightCase.moments.enumerated() {
                guard let label = moment.label, moment.phase != "notLive" else { continue }
                let words = try realPlane(flightCase.name, moment: index)
                XCTAssertTrue(words.lines.joined(separator: " · ").contains(label), "\(flightCase.name), moment \(index): \(words.lines)")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 20)
    }
}
