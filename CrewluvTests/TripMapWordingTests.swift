//
//  TripMapWordingTests.swift
//  CrewluvTests
//
//  The trip map's words (moving map spec §5, §6, §14), in US English for a family in Louisville.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class TripMapWordingTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }
    /// Friday 2026-11-13, 3:14 PM in Louisville, 9:14 PM in Cologne.
    private let now = Date(timeIntervalSince1970: 1_794_600_840)

    /// iOS writes a narrow no-break space before AM and PM; the tests read it as a plain space.
    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private func mark(_ code: String, _ city: String, _ zone: String) -> AirportMark {
        AirportMark(code: code, city: city, coordinate: TripMapTestLegs.airports[code]!, timeZone: TimeZone(identifier: zone))
    }

    private func leg(from origin: AirportMark, to destination: AirportMark, start: Date, end: Date, flightNumber: String? = "UPS207") -> MapLeg {
        MapLeg(id: "f", kind: .flight, origin: origin, destination: destination, start: start, end: end, flightNumber: flightNumber)
    }

    private var louisville: AirportMark { mark("SDF", "Louisville", "America/New_York") }
    private var cologne: AirportMark { mark("CGN", "Cologne", "Europe/Berlin") }
    private var dubai: AirportMark { mark("DXB", "Dubai", "Asia/Dubai") }

    func test_placeChip_showsTheTimeThere() {
        XCTAssertEqual(plain(TripMapWording.placeChip(for: cologne, at: now, locale: locale)), "Cologne · 9:14 PM there")
    }

    func test_nextDepartureChip_tomorrowMorning_inYourTime() {
        let next = leg(from: cologne, to: dubai, start: now.addingTimeInterval(14 * 3600 + 56 * 60), end: now.addingTimeInterval(21 * 3600))
        XCTAssertEqual(plain(TripMapWording.nextDepartureChip(for: next, now: now, calendar: calendar, locale: locale)),
                       "Next: Dubai, tomorrow 6:10 AM")
    }

    func test_landingCountdown_hoursAndMinutes() {
        func countdown(minutes: Double) -> String {
            TripMapWording.landingCountdown(for: leg(from: louisville, to: cologne, start: now.addingTimeInterval(-3600),
                                                     end: now.addingTimeInterval(minutes * 60)), now: now)
        }
        XCTAssertEqual(countdown(minutes: 130), "Landing in 2 h 10 min")
        XCTAssertEqual(countdown(minutes: 120), "Landing in 2 h")
        XCTAssertEqual(countdown(minutes: 45), "Landing in 45 min")
        XCTAssertEqual(countdown(minutes: -1), "Landing now")
    }

    func test_landingLine_anotherTimeZone_givesBothTimes() {
        let flight = leg(from: louisville, to: cologne, start: now.addingTimeInterval(-6 * 3600), end: now.addingTimeInterval(16 * 60))
        XCTAssertEqual(plain(TripMapWording.landingLine(for: flight, calendar: calendar, locale: locale)),
                       "Lands Cologne 9:30 PM · 3:30 PM your time")
    }

    func test_landingLine_yourTimeZone_givesOneTime() {
        let homeward = leg(from: cologne, to: louisville, start: now.addingTimeInterval(-6 * 3600), end: now.addingTimeInterval(16 * 60))
        XCTAssertEqual(plain(TripMapWording.landingLine(for: homeward, calendar: calendar, locale: locale)), "Lands Louisville 3:30 PM")
        XCTAssertNil(TripMapWording.arrivalLocalTime(for: homeward, calendar: calendar, locale: locale))
    }

    func test_landsAt_andArrivalLocalTime_forTheBar() {
        let flight = leg(from: louisville, to: cologne, start: now.addingTimeInterval(-6 * 3600), end: now.addingTimeInterval(16 * 60))
        XCTAssertEqual(plain(TripMapWording.landsAt(for: flight, calendar: calendar, locale: locale)), "Lands 3:30 PM")
        XCTAssertEqual(plain(TripMapWording.arrivalLocalTime(for: flight, calendar: calendar, locale: locale) ?? ""), "9:30 PM in Cologne")
    }

    func test_dayPhrase_todayTomorrowWeekdayDate() {
        let day: TimeInterval = 86_400
        XCTAssertEqual(TripMapWording.dayPhrase(for: now, now: now, calendar: calendar, locale: locale), "today")
        XCTAssertEqual(TripMapWording.dayPhrase(for: now.addingTimeInterval(day), now: now, calendar: calendar, locale: locale), "tomorrow")
        XCTAssertEqual(TripMapWording.dayPhrase(for: now.addingTimeInterval(5 * day), now: now, calendar: calendar, locale: locale), "Wednesday")
        XCTAssertEqual(TripMapWording.dayPhrase(for: now.addingTimeInterval(7 * day), now: now, calendar: calendar, locale: locale), "Nov 20")
    }

    func test_nextTripChip_namesTheDay() {
        XCTAssertEqual(TripMapWording.nextTripChip(startingAt: now.addingTimeInterval(5 * 86_400), now: now, calendar: calendar, locale: locale),
                       "Home · next trip Wednesday")
    }

    func test_dateRange_fridayToMonday() {
        XCTAssertEqual(TripMapWording.dateRange(from: now.addingTimeInterval(7 * 86_400), to: now.addingTimeInterval(10 * 86_400),
                                                calendar: calendar, locale: locale), "Fri–Mon")
        XCTAssertEqual(TripMapWording.dateRange(from: now, to: now.addingTimeInterval(3600), calendar: calendar, locale: locale), "Fri")
    }

    func test_statsItems_onTheLayover_dayCitiesAndMilesSoFar() throws {
        let start = TripMapTestLegs.tripStart
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: start.addingTimeInterval(12 * 3600)))
        let miles = Int((map.legs[0].distance / GreatCircle.metersPerMile).rounded())
        let items = TripMapWording.statsItems(for: map, at: start.addingTimeInterval(12 * 3600), dayNumber: 1, totalDays: 4,
                                              calendar: calendar, locale: locale)
        XCTAssertEqual(items, ["Day 1 of 4", "2 cities", "\(miles.formatted(.number.locale(locale))) mi so far"])
    }

    func test_statsItems_nextTrip_datesCitiesAndTotalMiles() throws {
        let start = TripMapTestLegs.tripStart
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), isNextTrip: true, at: start.addingTimeInterval(-86_400)))
        let total = Int((map.legs.map(\.distance).reduce(0, +) / GreatCircle.metersPerMile).rounded())
        let items = TripMapWording.statsItems(for: map, at: start.addingTimeInterval(-86_400), dayNumber: nil, totalDays: nil,
                                              calendar: calendar, locale: locale)
        XCTAssertEqual(items, ["Fri–Mon", "CGN · DXB", "\(total.formatted(.number.locale(locale))) mi"])
    }

    func test_cardChips_eachMode() throws {
        let start = TripMapTestLegs.tripStart
        let flying = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: start.addingTimeInterval(4 * 3600)))
        let flyingChips = TripMapWording.cardChips(for: flying, at: start.addingTimeInterval(4 * 3600), calendar: calendar, locale: locale)
        XCTAssertNil(flyingChips.top)
        XCTAssertEqual(flyingChips.bottom, "Landing in 4 h")

        let resting = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: start.addingTimeInterval(12 * 3600)))
        let restingChips = TripMapWording.cardChips(for: resting, at: start.addingTimeInterval(12 * 3600), calendar: calendar, locale: locale)
        XCTAssertTrue(restingChips.top?.hasPrefix("Cologne · ") ?? false)
        XCTAssertTrue(restingChips.bottom?.hasPrefix("Next: Dubai, ") ?? false)
    }

    func test_cardSummary_inFlight_readsAsOneSentence() throws {
        let start = TripMapTestLegs.tripStart
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: start.addingTimeInterval(4 * 3600)))
        let summary = plain(TripMapWording.cardSummary(for: map, now: start.addingTimeInterval(4 * 3600), pilotName: "Alex",
                                                       calendar: calendar, locale: locale))
        XCTAssertEqual(summary, "UPS207 to Cologne, landing at 3:00 PM your time. Estimated from the schedule.")
    }

    func test_timelineTime_weekdayAndTime() {
        XCTAssertEqual(plain(TripMapWording.timelineTime(now, calendar: calendar, locale: locale)), "Fri 3:14 PM")
    }

    func test_cardSummary_nextTrip_readsCityNames() throws {
        let start = TripMapTestLegs.tripStart
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), isNextTrip: true, at: start.addingTimeInterval(-86_400)))
        XCTAssertEqual(TripMapWording.cardSummary(for: map, now: start.addingTimeInterval(-86_400), pilotName: "Alex", calendar: calendar, locale: locale),
                       "Map of the next trip, tomorrow: Cologne, Dubai.")
    }

    func test_dateRange_aWeekOrMore_givesDates() {
        XCTAssertEqual(TripMapWording.dateRange(from: now, to: now.addingTimeInterval(7 * 86_400), calendar: calendar, locale: locale), "Nov 13–Nov 20")
    }

    func test_statsItems_onTripWithNoFlights_leavesOutTheCityCount() throws {
        let start = TripMapTestLegs.tripStart
        let legs = [TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: start, hours: 2)]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: start.addingTimeInterval(3 * 3600)))
        let items = TripMapWording.statsItems(for: map, at: start.addingTimeInterval(3 * 3600), dayNumber: nil, totalDays: nil, calendar: calendar, locale: locale)
        XCTAssertEqual(items, ["0 mi so far"])
    }
}
