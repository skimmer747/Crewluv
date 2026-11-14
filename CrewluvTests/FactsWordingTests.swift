//
//  FactsWordingTests.swift
//  CrewluvTests
//
//  The facts' sentences (Stage 2 spec §4, §5, §6.5), in US English for a family in Louisville.
//

import XCTest
@testable import Crewluv

final class FactsWordingTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }
    /// Friday 2026-11-13, 3:14 PM in Louisville.
    private let now = Date(timeIntervalSince1970: 1_794_600_840)

    /// iOS writes a narrow no-break space before AM and PM; the tests read it as a plain space.
    private func plain(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private func zone(_ identifier: String) -> TimeZone { TimeZone(identifier: identifier)! }

    // MARK: - Milestones

    func test_headline_eachMilestone() {
        XCTAssertEqual(FactsWording.headline(for: .crossedInto("Kansas")), "Just crossed into Kansas")
        XCTAssertEqual(FactsWording.headline(for: .outOver("the Atlantic")), "Out over the Atlantic")
        XCTAssertEqual(FactsWording.headline(for: .halfway), "Halfway!")
        XCTAssertEqual(FactsWording.headline(for: .closestToHome(miles: 40)), "Closest to home: 40 mi, wave!")
    }

    func test_listLine_addsTheTimeInYourZone() {
        let milestone = Milestone(kind: .crossedInto("Canada"), time: now)
        XCTAssertEqual(plain(FactsWording.listLine(for: milestone, calendar: calendar, locale: locale)), "Crossed into Canada · 3:14 PM")
        let closest = Milestone(kind: .closestToHome(miles: 40), time: now)
        XCTAssertEqual(plain(FactsWording.listLine(for: closest, calendar: calendar, locale: locale)), "Closest to home, 40 mi · 3:14 PM")
    }

    func test_below_withAndWithoutACity() {
        let place = Geography.Place(name: "Québec", kind: .province, country: "Canada")
        XCTAssertEqual(FactsWording.below(place, near: nil), "Over Québec")
        XCTAssertEqual(FactsWording.below(place, near: Geography.City(name: "Montréal", lat: 45.5, lon: -73.57)), "Over Québec, near Montréal")
    }

    func test_closestToHome_beforeAndAfter() {
        let later = now.addingTimeInterval(3600)
        XCTAssertEqual(plain(FactsWording.closestToHome(miles: 40, at: later, now: now, calendar: calendar, locale: locale)),
                       "Passes 40 mi from home at 4:14 PM")
        XCTAssertEqual(plain(FactsWording.closestToHome(miles: 40, at: now, now: later, calendar: calendar, locale: locale)),
                       "Closest to home was 40 mi at 3:14 PM")
    }

    // MARK: - The sky

    func test_cockpitCountdown_roundsUp() {
        let sunset = SkyFacts.SunEvent(kind: .sunset, time: now.addingTimeInterval(24.5 * 60), peopleBelowGap: nil)
        XCTAssertEqual(FactsWording.cockpitCountdown(sunset, now: now), "Sunset from the cockpit in 25 min")
    }

    func test_cockpitEvent_soonWithThePeopleBelow() {
        let sunset = SkyFacts.SunEvent(kind: .sunset, time: now.addingTimeInterval(24.5 * 60), peopleBelowGap: 12.2 * 60)
        XCTAssertEqual(FactsWording.cockpitEvent(sunset, now: now, calendar: calendar, locale: locale),
                       "Sunset in 25 min, about 12 min after the people below")
    }

    func test_cockpitEvent_anHourOrMoreAway_givesTheTime() {
        let sunrise = SkyFacts.SunEvent(kind: .sunrise, time: now.addingTimeInterval(2 * 3600), peopleBelowGap: 22 * 60)
        XCTAssertEqual(plain(FactsWording.cockpitEvent(sunrise, now: now, calendar: calendar, locale: locale)),
                       "Sunrise at 5:14 PM, about 22 min before the people below")
    }

    func test_skyLines() {
        XCTAssertEqual(FactsWording.flyingInto(.sunset), "Flying into the night")
        XCTAssertEqual(FactsWording.flyingInto(.sunrise), "Flying into the morning")
        XCTAssertEqual(FactsWording.chase(.afternoon), "Chasing the sun: their afternoon is stretching")
        XCTAssertEqual(FactsWording.moon(SkyFacts.Moon(phase: .waxingGibbous, isUp: true)), "Waxing gibbous moon, up")
        XCTAssertEqual(FactsWording.moon(SkyFacts.Moon(phase: .full, isUp: false)), "Full moon, below the horizon")
        XCTAssertEqual(plain(FactsWording.groundSun(.sunrise, at: now, in: zone("Europe/Berlin"), locale: locale)), "sunrise at 9:14 PM there")
    }

    // MARK: - Distance and landing

    func test_distance_andSpeed() {
        XCTAssertEqual(FactsWording.distance(flownMiles: 2_140, toGoMiles: 1_960, locale: locale), "2,140 mi flown · 1,960 to go")
        XCTAssertEqual(FactsWording.averageSpeed(milesPerHour: 504), "Averaging about 500 mph")
        XCTAssertEqual(FactsWording.averageSpeed(milesPerHour: 506), "Averaging about 510 mph")
        XCTAssertEqual(FactsWording.midLine("Like driving coast to coast"), "like driving coast to coast")
    }

    func test_weather() {
        XCTAssertEqual(FactsWording.weather(LandingForecast(temperature: "48°F", condition: "rain")), "48°F and rain on landing")
    }

    func test_timeDifference() {
        let yours = zone("America/New_York")
        XCTAssertEqual(FactsWording.timeDifference(from: zone("Europe/Berlin"), to: yours, at: now), "6 hours ahead of you")
        XCTAssertEqual(FactsWording.timeDifference(from: zone("America/Los_Angeles"), to: yours, at: now), "3 hours behind you")
        XCTAssertEqual(FactsWording.timeDifference(from: zone("Asia/Kolkata"), to: yours, at: now), "10½ hours ahead of you")
        XCTAssertEqual(FactsWording.timeDifference(from: zone("America/St_Johns"), to: zone("America/Halifax"), at: now), "½ hour ahead of you")
        XCTAssertEqual(FactsWording.timeDifference(from: zone("America/Chicago"), to: yours, at: now), "1 hour behind you")
        XCTAssertNil(FactsWording.timeDifference(from: zone("America/Detroit"), to: yours, at: now))
    }

    func test_lands_thereOrYourTime() {
        let cologne = MapLeg(id: "f", kind: .flight,
                             origin: FactsTestData.mark("SDF", latitude: 38.17, longitude: -85.74, city: "Louisville", zone: "America/New_York"),
                             destination: FactsTestData.mark("CGN", latitude: 50.87, longitude: 7.14, city: "Cologne", zone: "Europe/Berlin"),
                             start: now.addingTimeInterval(-3600), end: now, flightNumber: "UPS207")
        XCTAssertEqual(plain(FactsWording.lands(cologne, calendar: calendar, locale: locale)), "lands 9:14 PM there")
        XCTAssertEqual(FactsWording.flightTitle(cologne), "UPS207 · Louisville → Cologne")
        let home = MapLeg(id: "f", kind: .flight, origin: cologne.destination, destination: cologne.origin,
                          start: now.addingTimeInterval(-3600), end: now, flightNumber: nil)
        XCTAssertEqual(plain(FactsWording.lands(home, calendar: calendar, locale: locale)), "lands 3:14 PM")
        XCTAssertEqual(FactsWording.flightTitle(home), "Cologne → Louisville")
    }

    // MARK: - Totals and the recap

    func test_soFar_leavesOutZeros() {
        let totals = TripTotals(cities: 1, miles: 4_351, timeZones: 6, cockpitSunsets: 0)
        XCTAssertEqual(FactsWording.soFar(totals, dayNumber: 2, totalDays: 4, locale: locale), "Day 2 of 4 · 1 city · 4,351 mi · 6 time zones")
        XCTAssertNil(FactsWording.soFar(TripTotals(cities: 0, miles: 0, timeZones: 0, cockpitSunsets: 0), dayNumber: nil, totalDays: nil, locale: locale))
    }

    func test_onTheWay_aForecastSaysAbout() {
        let totals = TripTotals(cities: 2, miles: 9_800, timeZones: 8, cockpitSunsets: 2)
        XCTAssertEqual(FactsWording.onTheWay(totals, isForecast: true, locale: locale), "8 time zones · about 2 sunsets from the cockpit")
        XCTAssertEqual(FactsWording.onTheWay(totals, isForecast: false, locale: locale), "8 time zones · 2 sunsets from the cockpit")
        XCTAssertNil(FactsWording.onTheWay(TripTotals(cities: 1, miles: 100, timeZones: 0, cockpitSunsets: 0), isForecast: true, locale: locale))
    }

    func test_recapChip_oneDayOrMore() {
        XCTAssertEqual(FactsWording.recapChip(days: 1), "Home from a day away")
        XCTAssertEqual(FactsWording.recapChip(days: 4), "Home from 4 days away")
    }

    func test_recapTiles_leaveOutZeros_andSayOneSunset() {
        let tiles = FactsWording.recapTiles(TripTotals(cities: 2, miles: 14_819, timeZones: 0, cockpitSunsets: 1), locale: locale)
        XCTAssertEqual(tiles, [RecapTile(value: "2", label: "cities"), RecapTile(value: "14,819", label: "miles"),
                               RecapTile(value: "1", label: "sunset aloft")])
    }

    func test_recapSummary_isOneParagraph() {
        let longest = MapLeg(id: "f3", kind: .flight,
                             origin: FactsTestData.mark("DXB", latitude: 25.2532, longitude: 55.3657, city: "Dubai"),
                             destination: FactsTestData.mark("SDF", latitude: 38.1744, longitude: -85.7360, city: "Louisville"),
                             start: now, end: now.addingTimeInterval(14 * 3600), flightNumber: "UPS209")
        let totals = TripTotals(cities: 2, miles: 14_819, timeZones: 18, cockpitSunsets: 1)
        XCTAssertEqual(FactsWording.recapSummary(days: 4, totals: totals, longest: longest, locale: locale),
                       "Trip recap: home from 4 days away. 2 cities, 14,819 miles, 18 time zones, 1 sunset from the cockpit. Longest flight, Dubai to Louisville, 7,382 miles.")
    }
}
