//
//  LiveStoryTests.swift
//  CrewluvTests
//
//  A flight's story and milestones along its real path (Stage 3 spec §8, §16.3): the places under the path it
//  really flew, the real plane's times, and nothing told of a stretch nobody saw. The made-up real plane is
//  `FactsTestData`'s: a degree of longitude every 8 minutes from 10:15 UTC.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LiveStoryTests: XCTestCase {

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    private let home = FactsTestData.homeByTheEquator

    /// The real plane last seen at `seenUntil`, as the leg is handed on then.
    private func leg(seenUntil: String, unseen: ClosedRange<Double>? = nil) throws -> MapLeg {
        try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at(seenUntil), unseen: unseen), at: at(seenUntil))
    }

    private func milestones(_ leg: MapLeg, home: AirportMark? = nil) -> [Milestone] {
        Milestone.milestones(on: leg, story: LegStory(leg: leg, geography: FactsTestData.equator, home: home))
    }

    private func assertMilestone(_ milestone: Milestone, _ kind: Milestone.Kind, at iso: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(milestone.kind, kind, file: file, line: line)
        XCTAssertEqual(milestone.time.timeIntervalSince1970, FactsTestData.date(iso).timeIntervalSince1970, accuracy: 5, file: file, line: line)
    }

    // MARK: - The story

    func test_story_followsTheRealPath_notTheGreatCircle() throws {
        // North of Bravo, where the great circle never goes.
        let geography = Geography(areas: FactsTestData.equator.areas + [FactsTestData.box("Charlie", .country, west: 5.5, east: 10.5, south: 1, north: 3)],
                                  cities: [])
        let seenUntil = FactsTestData.liveTime(atLongitude: 13)
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: seenUntil, latitude: FactsTestData.dogLeg), at: seenUntil)

        let story = LegStory(leg: leg, geography: geography, home: nil)
        XCTAssertEqual(story.stretches.map(\.place.name), ["Alpha", "Bravo", "Charlie", "Bravo", "the Test Sea"])
        XCTAssertEqual(story.length, leg.pathLength)

        let scheduled = LegStory(leg: FactsTestData.equatorFlight(from: 0, to: 20), geography: geography, home: nil)
        XCTAssertEqual(scheduled.stretches.map(\.place.name), ["Alpha", "Bravo", "the Test Sea"], "the great circle stays on the equator")
    }

    func test_placeAtDistance_readsThePathByItsMeters() throws {
        let leg = try leg(seenUntil: "11:10")
        let story = LegStory(leg: leg, geography: FactsTestData.equator, home: nil)
        XCTAssertEqual(story.place(atDistance: 3 * FactsTestData.metersADegree)?.name, "Alpha")
        XCTAssertEqual(story.place(atDistance: 7 * FactsTestData.metersADegree)?.name, "Bravo")
        XCTAssertEqual(story.place(atDistance: 15 * FactsTestData.metersADegree)?.name, "the Test Sea")
    }

    func test_placeAtDistance_ofAStoryMadeForAShorterPath_isStillRightWhereThePlaneHasFlown() throws {
        // The story was made when the path was shorter. A place this far along it is still this far along it.
        let geography = Geography(areas: FactsTestData.equator.areas + [FactsTestData.box("Charlie", .country, west: 5.5, east: 10.5, south: 1, north: 3)],
                                  cities: [])
        let early = FactsTestData.liveTime(atLongitude: 8)
        let earlier = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: early, latitude: FactsTestData.dogLeg), at: early)
        let late = FactsTestData.liveTime(atLongitude: 13)
        let later = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: late, latitude: FactsTestData.dogLeg), at: late)
        XCTAssertNotEqual(earlier.pathLength, later.pathLength)

        let old = LegStory(leg: earlier, geography: geography, home: nil)
        let new = LegStory(leg: later, geography: geography, home: nil)
        for degrees in stride(from: 0.5, through: 7.5, by: 0.5) {
            let far = later.path.knots[Int(degrees * 4) - 1].distance
            XCTAssertEqual(old.place(atDistance: far), new.place(atDistance: far), "\(degrees)° E")
        }
    }

    func test_closestToHome_isMeasuredAlongTheRealPath() throws {
        // Home is 2.4° N of 8° E: 166 mi from the great circle, and 28 mi from the path that goes north to 2° N.
        let homeUpNorth = CLLocationCoordinate2D(latitude: 2.4, longitude: 8)
        let seenUntil = FactsTestData.liveTime(atLongitude: 13)
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: seenUntil, latitude: FactsTestData.dogLeg), at: seenUntil)

        let closest = try XCTUnwrap(LegStory(along: leg.path, geography: nil, home: homeUpNorth).closestToHome)
        XCTAssertEqual(closest.meters, 0.4 * FactsTestData.metersADegree, accuracy: 500)
        XCTAssertEqual(leg.path.point(atDistance: closest.fraction * leg.pathLength).longitude, 8, accuracy: 0.05)
        XCTAssertNil(LegStory(along: FactsTestData.equatorFlight(from: 0, to: 20).path, geography: nil, home: homeUpNorth).closestToHome,
                     "too far from the great circle")
    }

    // MARK: - The milestones

    func test_milestones_onARealPath_haveTheRealPlanesTimes() throws {
        // The real plane is faster than the plan: it crosses into Bravo at 10:55, where the schedule has 11:00.
        let found = milestones(try leg(seenUntil: "12:30"), home: home)
        guard found.count == 4 else { return XCTFail("\(found.count) milestones, not 4: \(found.map(\.kind))") }
        assertMilestone(found[0], .crossedInto("Bravo"), at: "2026-03-20T10:55:00Z")
        assertMilestone(found[1], .halfway, at: "2026-03-20T11:35:00Z")
        assertMilestone(found[2], .outOver("the Test Sea"), at: "2026-03-20T11:51:35Z") // 5 mi offshore, by the coast snap
        assertMilestone(found[3], .closestToHome(miles: 35), at: "2026-03-20T12:07:00Z")
        XCTAssertEqual(found.map(\.isEstimate), [false, false, false, false], "it was seen all the way")
    }

    func test_milestones_aCrossingNobodySaw_isABestGuess() throws {
        // Nobody saw it from 4° E (10:47) to 6.5° E (11:07), where it crossed into Bravo. On the straight join
        // between the two it's at 5° E at 10:55.
        let found = milestones(try leg(seenUntil: "12:30", unseen: 4...6.5), home: home)
        XCTAssertEqual(found.map(\.kind), [.crossedInto("Bravo"), .halfway, .outOver("the Test Sea"), .closestToHome(miles: 35)])
        XCTAssertEqual(found.map(\.isEstimate), [true, false, false, false])
        if let crossing = found.first { assertMilestone(crossing, .crossedInto("Bravo"), at: "2026-03-20T10:55:00Z") }
    }

    func test_milestones_theClosestPointToHome_whereNobodySawIt_isABestGuess() throws {
        // Nobody saw it from 13° E to 15° E, where it passed home.
        let found = milestones(try leg(seenUntil: "12:30", unseen: 13...15), home: home)
        XCTAssertEqual(found.map(\.kind), [.crossedInto("Bravo"), .halfway, .outOver("the Test Sea"), .closestToHome(miles: 35)])
        XCTAssertEqual(found.map(\.isEstimate), [false, false, false, true])
    }

    func test_milestones_ofALegThatGoesNowhere_areHalfwayInTheMiddleOfItsTimeInTheAir() {
        // It has no length, so halfway is timed as it always was: half its time in the air, 10:15 to 13:15.
        let nowhere = FactsTestData.equatorFlight(from: 0, to: 0)
        let found = milestones(nowhere)
        XCTAssertEqual(found.map(\.kind), [.halfway])
        if let halfway = found.first { assertMilestone(halfway, .halfway, at: "2026-03-20T11:45:00Z") }
    }

    func test_milestones_aheadOfWhereThePlaneWasLastSeen_areBestGuesses() throws {
        // Last seen at 3.75° E at 10:45. Everything is still ahead, where the plan has the plane flying on.
        let found = milestones(try leg(seenUntil: "10:45"), home: home)
        XCTAssertEqual(found.map(\.kind), [.crossedInto("Bravo"), .halfway, .outOver("the Test Sea"), .closestToHome(miles: 35)])
        XCTAssertEqual(found.map(\.isEstimate), [true, true, true, true])
        XCTAssertTrue(found.allSatisfy { $0.time > at("10:45") })
        // At its own 450 kt it's at 5° E ten minutes after it was last seen.
        if let crossing = found.first { assertMilestone(crossing, .crossedInto("Bravo"), at: "2026-03-20T10:55:00Z") }
    }

    func test_milestones_halfway_isHalfThePathsWholeLength() throws {
        // The path north to 2° N and back is about 22.5° long. Its half, 11.24° along it, is on the way back
        // down, at about 9.45° E: before 10° E, the great circle's halfway, which the real plane passes at 11:35.
        let seenUntil = FactsTestData.liveTime(atLongitude: 13)
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: seenUntil, latitude: FactsTestData.dogLeg), at: seenUntil)
        let halfway = try XCTUnwrap(milestones(leg).first { $0.kind == .halfway })
        let place = leg.path.point(atDistance: leg.pathLength / 2)
        XCTAssertEqual(place.longitude, 9.45, accuracy: 0.05)
        XCTAssertEqual(halfway.time.timeIntervalSince1970, FactsTestData.liveTime(atLongitude: place.longitude).timeIntervalSince1970, accuracy: 5)
        XCTAssertLessThan(halfway.time, at("11:32"))
    }

    func test_milestones_withNoLiveData_areTheSchedules_asBefore() throws {
        let scheduled = FactsTestData.equatorFlight(from: 0, to: 20)
        let withNoAnswer = try FactsTestData.equatorLiveLeg(nil, at: at("11:10"))
        let before = milestones(scheduled, home: home)
        let after = milestones(withNoAnswer, home: home)
        XCTAssertEqual(before.map(\.kind), after.map(\.kind))
        for (earlier, later) in zip(before, after) {
            XCTAssertEqual(earlier.time.timeIntervalSince1970, later.time.timeIntervalSince1970, accuracy: 0.001)
        }
        XCTAssertEqual(before.map(\.kind), [.crossedInto("Bravo"), .halfway, .outOver("the Test Sea"), .closestToHome(miles: 35)])
        XCTAssertEqual(after.map(\.isEstimate), [false, false, false, false], "the schedule is told as it is")
        if let first = before.first { assertMilestone(first, .crossedInto("Bravo"), at: "2026-03-20T11:00:00Z") }
    }
}
