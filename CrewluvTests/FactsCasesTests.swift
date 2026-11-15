//
//  FactsCasesTests.swift
//  CrewluvTests
//
//  The shared facts cases (Stage 2 spec §12.1), which the website runs too.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class FactsCasesTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func coordinate(_ pair: [Double]) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
    }

    private func flight(_ id: String, from: [Double], to: [Double], departure: Date, arrival: Date) -> MapLeg {
        MapLeg(id: id, kind: .flight,
               origin: AirportMark(code: "\(id)-from", city: nil, coordinate: coordinate(from), timeZone: nil),
               destination: AirportMark(code: "\(id)-to", city: nil, coordinate: coordinate(to), timeZone: nil),
               start: departure, end: arrival, flightNumber: nil)
    }

    private func facts(for story: TripMapFixtures.FactsCases.Story, in geography: Geography) -> TripFacts {
        let leg = flight(story.name, from: story.from, to: story.to, departure: story.departure, arrival: story.arrival)
        let home = story.home.map { AirportMark(code: "HOME", city: nil, coordinate: coordinate($0), timeZone: nil) }
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: home,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        return TripFacts(tripMap: map, geography: geography, comparisons: nil,
                         stories: [leg.id: LegStory(leg: leg, geography: geography, home: home)],
                         sunEvents: [leg.id: SkyFacts.sunEvents(on: leg)], calendar: calendar, locale: locale)
    }

    private func describe(_ kind: Milestone.Kind) -> (kind: String, name: String?, miles: Int?) {
        switch kind {
        case .crossedInto(let name): ("crossedInto", name, nil)
        case .outOver(let name): ("outOver", name, nil)
        case .halfway: ("halfway", nil, nil)
        case .closestToHome(let miles): ("closestToHome", nil, miles)
        }
    }

    private func kindName(_ kind: SkyFacts.SunEvent.Kind) -> String {
        kind == .sunrise ? "sunrise" : "sunset"
    }

    func test_constants_matchTheApp() throws {
        let constants = try TripMapFixtures.factsCases().constants
        let mile = GreatCircle.metersPerMile
        XCTAssertEqual(SkyFacts.cockpitHorizon, constants.cockpitHorizonDegrees, accuracy: 0.0001)
        XCTAssertEqual(Milestone.headlineDuration, constants.milestoneMinutes * 60)
        XCTAssertEqual(TripFacts.sunHeadlineWindow, constants.sunHeadlineMinutes * 60)
        XCTAssertEqual(LegStory.sampleSpacing, constants.sampleMiles * mile)
        XCTAssertEqual(LegStory.holdDistance, constants.holdMiles * mile)
        XCTAssertEqual(LegStory.homeRadius, constants.homeRadiusMiles * mile)
        XCTAssertEqual(Geography.cityRadius, constants.cityRadiusMiles * mile)
        XCTAssertEqual(Geography.coastSnap, constants.coastSnapMiles * mile)
        XCTAssertEqual(TripFacts.weatherHorizon, constants.weatherHours * 3600)
    }

    func test_comparisons() throws {
        let picker = try FactsTestData.appComparisons()
        for comparison in try TripMapFixtures.factsCases().comparisons {
            XCTAssertEqual(picker.phrase(forMiles: comparison.miles), comparison.phrase, "\(comparison.miles) mi")
        }
    }

    func test_places_inTheAppsGeography() throws {
        let geography = try FactsTestData.appGeography()
        for expected in try TripMapFixtures.factsCases().places {
            let place = geography.place(at: CLLocationCoordinate2D(latitude: expected.lat, longitude: expected.lon))
            XCTAssertEqual(place?.name, expected.place)
            XCTAssertEqual(place?.kind.rawValue, expected.kind, expected.place)
            XCTAssertEqual(place?.country, expected.country, expected.place)
        }
    }

    func test_cities_inTheAppsGeography() throws {
        let geography = try FactsTestData.appGeography()
        for expected in try TripMapFixtures.factsCases().cities {
            XCTAssertEqual(geography.city(near: CLLocationCoordinate2D(latitude: expected.lat, longitude: expected.lon))?.name, expected.city,
                           "\(expected.lat), \(expected.lon)")
        }
    }

    func test_stories_milestones() throws {
        let cases = try TripMapFixtures.factsCases()
        for story in cases.stories {
            let storyFacts = facts(for: story, in: cases.testGeography)
            let found = storyFacts.milestones(on: storyFacts.tripMap.legs[0])
            XCTAssertEqual(found.count, story.milestones.count, story.name)
            for (milestone, expected) in zip(found, story.milestones) {
                let actual = describe(milestone.kind)
                XCTAssertEqual(actual.kind, expected.kind, story.name)
                XCTAssertEqual(actual.name, expected.name, story.name)
                XCTAssertEqual(actual.miles, expected.miles, story.name)
                XCTAssertEqual(milestone.time.timeIntervalSince1970, expected.time.timeIntervalSince1970, accuracy: 60, story.name)
            }
        }
    }

    func test_headlines() throws {
        let cases = try TripMapFixtures.factsCases()
        for headline in cases.headlines {
            let story = try XCTUnwrap(cases.stories.first { $0.name == headline.story })
            XCTAssertEqual(facts(for: story, in: cases.testGeography).headline(at: headline.at), headline.text, "\(headline.story) at \(headline.at)")
        }
    }

    func test_sunEvents() throws {
        for expected in try TripMapFixtures.factsCases().sunEvents {
            let events = SkyFacts.sunEvents(on: flight("sun", from: expected.from, to: expected.to, departure: expected.departure, arrival: expected.arrival))
            XCTAssertEqual(events.count, expected.events.count, expected.name)
            for (event, wanted) in zip(events, expected.events) {
                XCTAssertEqual(kindName(event.kind), wanted.kind, expected.name)
                XCTAssertEqual(event.time.timeIntervalSince1970, wanted.time.timeIntervalSince1970, accuracy: 60, expected.name)
                XCTAssertEqual((event.peopleBelowGap ?? 0) / 60, wanted.peopleBelowMinutes ?? 0, accuracy: 1, expected.name)
            }
        }
    }

    func test_moonPhases() throws {
        for expected in try TripMapFixtures.factsCases().moonPhases {
            XCTAssertEqual("\(MoonPosition.phase(at: expected.at))", expected.phase, "\(expected.at)")
        }
    }

    func test_moonUp() throws {
        for expected in try TripMapFixtures.factsCases().moonUp {
            XCTAssertEqual(MoonPosition.altitude(latitude: expected.lat, longitude: expected.lon, at: expected.at) > 0, expected.isUp, "\(expected.at)")
        }
    }

    func test_groundSun() throws {
        for expected in try TripMapFixtures.factsCases().groundSun {
            let event = try XCTUnwrap(SkyFacts.nextGroundSunEvent(at: CLLocationCoordinate2D(latitude: expected.lat, longitude: expected.lon), after: expected.after))
            XCTAssertEqual(kindName(event.kind), expected.kind)
            XCTAssertEqual(event.time.timeIntervalSince1970, expected.time.timeIntervalSince1970, accuracy: 60)
        }
    }

    func test_totals() throws {
        let expected = try TripMapFixtures.factsCases().totals
        func mark(_ code: String, zone: String? = nil) -> AirportMark {
            AirportMark(code: code, city: nil, coordinate: coordinate(expected.airports[code]!), timeZone: zone.flatMap(TimeZone.init(identifier:)))
        }
        let legs = expected.legs.map {
            MapLeg(id: $0.id, kind: .flight, origin: mark($0.from, zone: $0.fromZone), destination: mark($0.to, zone: $0.toZone),
                   start: $0.departure, end: $0.arrival, flightNumber: nil)
        }
        let map = TripMap(mode: .onTrip, legs: legs, home: mark(expected.home),
                          span: DateInterval(start: legs[0].start, end: legs[legs.count - 1].end), tripDays: nil)
        let sunEvents = Dictionary(uniqueKeysWithValues: legs.map { ($0.id, SkyFacts.sunEvents(on: $0)) })
        XCTAssertEqual(TripTotals.whole(map, sunEvents: sunEvents),
                       TripTotals(cities: expected.cities, miles: expected.miles, timeZones: expected.timeZones, cockpitSunsets: expected.cockpitSunsets))
    }
}
