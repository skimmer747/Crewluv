//
//  AirReturnTests.swift
//  CrewluvTests
//
//  An air return (air return design §2 to §4): a plane back on the ground at its departure airport after flying, and
//  the trail of its latest try. The shared cases hold the phase, the label, the path and the record; these hold the
//  rest.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class AirReturnTests: XCTestCase {

    private let louisville = CLLocationCoordinate2D(latitude: 38.1744, longitude: -85.736)
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func point(_ minutes: Double, milesOut: Double, feet: Double?) -> LiveFlight.TrailPoint {
        // Due east of Louisville: a degree of longitude there is about 47 nautical miles.
        LiveFlight.TrailPoint(time: start.addingTimeInterval(minutes * 60), latitude: louisville.latitude,
                              longitude: louisville.longitude + milesOut / 47, altitudeFeet: feet)
    }

    private func flight(_ state: LiveFlight.State, onGroundAt milesOut: Double? = nil,
                        trail: [LiveFlight.TrailPoint]) -> LiveFlight {
        let fix = milesOut.map {
            LiveFlight.Fix(latitude: louisville.latitude, longitude: louisville.longitude + $0 / 47, altitudeFeet: nil,
                           groundSpeedKnots: 0, trackDegrees: nil, isOnGround: true, registration: "N370UP",
                           typeCode: "B763", seenAt: start.addingTimeInterval(60 * 60))
        }
        return LiveFlight(legID: "f1", callsign: "UPS1234", state: state, fix: fix, landedAt: nil, trail: trail)
    }

    /// Out 40 nm and back, from 500 ft up to 8,500 and down again.
    private var outAndBack: [LiveFlight.TrailPoint] {
        [point(1, milesOut: 2, feet: 900), point(5, milesOut: 20, feet: 6_000), point(9, milesOut: 38, feet: 8_500),
         point(13, milesOut: 20, feet: 6_000), point(18, milesOut: 3, feet: 1_000)]
    }

    // MARK: - The constants

    func test_constants_matchTheSharedCases() throws {
        let constants = try TripMapFixtures.liveCases().constants
        XCTAssertEqual(LiveFlight.returnClimbFeet, constants.returnClimbFeet)
        XCTAssertEqual(LiveFlight.restartGap, constants.restartGapMinutes * 60)
    }

    // MARK: - Back at the airport

    func test_isBack_onTheGroundNearTheAirport_afterTheTrailClimbed() {
        XCTAssertTrue(flight(.ground, onGroundAt: 0.5, trail: outAndBack).isBack(at: louisville))
        XCTAssertFalse(flight(.ground, onGroundAt: 15, trail: outAndBack).isBack(at: louisville), "a diversion")
        XCTAssertFalse(flight(.airborne, trail: outAndBack).isBack(at: louisville))
        XCTAssertFalse(flight(.airborne, onGroundAt: 0.5, trail: outAndBack).isBack(at: louisville), "in the air by its state")
        XCTAssertFalse(flight(.ground, onGroundAt: 0.5, trail: []).isBack(at: louisville), "never flew")
    }

    func test_isBack_needsAClimbOfAThousandFeet_notAHeight() {
        // A stray point at Denver's height, 5,400 ft from sea level, climbs nothing.
        let stray = [point(1, milesOut: 0.2, feet: 5_400)]
        XCTAssertFalse(flight(.ground, onGroundAt: 0.5, trail: stray).isBack(at: louisville))
        let level = [point(1, milesOut: 2, feet: 5_400), point(5, milesOut: 20, feet: 6_399)]
        XCTAssertFalse(flight(.ground, onGroundAt: 0.5, trail: level).isBack(at: louisville), "999 ft")
        let climbed = [point(1, milesOut: 2, feet: 5_400), point(5, milesOut: 20, feet: 6_400)]
        XCTAssertTrue(flight(.ground, onGroundAt: 0.5, trail: climbed).isBack(at: louisville))
        let noHeights = [point(1, milesOut: 2, feet: nil), point(5, milesOut: 20, feet: nil)]
        XCTAssertFalse(flight(.ground, onGroundAt: 0.5, trail: noHeights).isBack(at: louisville))
        // A point with no height isn't at sea level: one height left climbs nothing.
        let oneHeight = [point(1, milesOut: 2, feet: nil), point(5, milesOut: 20, feet: 1_200)]
        XCTAssertFalse(flight(.ground, onGroundAt: 0.5, trail: oneHeight).isBack(at: louisville))
    }

    // MARK: - The latest try

    func test_latestTry_isNone_whileThePlaneIsBack() {
        XCTAssertEqual(flight(.ground, onGroundAt: 0.5, trail: outAndBack).latestTry(from: louisville), [])
    }

    func test_latestTry_startsAgain_nearTheAirport_afterTenMinutes() {
        let again = [point(40, milesOut: 6, feet: 3_000), point(42, milesOut: 20, feet: 9_000)]
        let tries = flight(.airborne, trail: outAndBack + again).latestTry(from: louisville)
        XCTAssertEqual(tries, again)
    }

    func test_latestTry_startsAgain_atAFirstPointUpTo30NauticalMilesOut() {
        // Coverage low down can miss the first minutes of the climb.
        let again = [point(42, milesOut: 28, feet: 9_000), point(44, milesOut: 40, feet: 14_000)]
        XCTAssertEqual(flight(.airborne, trail: outAndBack + again).latestTry(from: louisville), again)
        let unsorted = (outAndBack + again).reversed()
        XCTAssertEqual(flight(.airborne, trail: Array(unsorted)).latestTry(from: louisville), again, "sorted first")
    }

    func test_latestTry_startsAgain_atTheFixInTheAir_beforeAnyNewPoint() {
        let fix = LiveFlight.Fix(latitude: louisville.latitude, longitude: louisville.longitude + 8.0 / 47, altitudeFeet: 3_000,
                                 groundSpeedKnots: 250, trackDegrees: 90, isOnGround: false, registration: "N370UP",
                                 typeCode: "B763", seenAt: start.addingTimeInterval(40 * 60))
        let flying = LiveFlight(legID: "f1", callsign: "UPS1234", state: .airborne, fix: fix, landedAt: nil, trail: outAndBack)
        XCTAssertEqual(flying.latestTry(from: louisville), [])
        let soon = LiveFlight(legID: "f1", callsign: "UPS1234", state: .airborne,
                              fix: LiveFlight.Fix(latitude: fix.latitude, longitude: fix.longitude, altitudeFeet: 3_000,
                                                  groundSpeedKnots: 250, trackDegrees: 90, isOnGround: false,
                                                  registration: "N370UP", typeCode: "B763",
                                                  seenAt: start.addingTimeInterval(25 * 60)),
                              landedAt: nil, trail: outAndBack)
        XCTAssertEqual(soon.latestTry(from: louisville), outAndBack, "seven minutes on: the same try")
    }

    func test_latestTry_isTheWholeTrail_withoutAGapNearTheAirport() {
        // Ten minutes or less, or a gap that ends further out, is the same try.
        let soon = [point(28, milesOut: 6, feet: 3_000)]
        XCTAssertEqual(flight(.airborne, trail: outAndBack + soon).latestTry(from: louisville), outAndBack + soon)
        let further = [point(40, milesOut: 32, feet: 9_000)]
        XCTAssertEqual(flight(.airborne, trail: outAndBack + further).latestTry(from: louisville), outAndBack + further)
        // Nor does one that comes back near the airport from further out, as a plane unseen on its way back would.
        let fromFurther = [point(1, milesOut: 2, feet: 900), point(5, milesOut: 20, feet: 8_000), point(20, milesOut: 5, feet: 3_000)]
        XCTAssertEqual(flight(.airborne, trail: fromFurther).latestTry(from: louisville), fromFurther)
    }

    func test_latestTry_doesntStartAgain_beforeTheFirstTryClimbed() {
        // A stray point while taxiing, then the real takeoff half an hour later.
        let trail = [point(1, milesOut: 0.2, feet: 500), point(31, milesOut: 2, feet: 1_200), point(33, milesOut: 15, feet: 7_000)]
        XCTAssertEqual(flight(.airborne, trail: trail).latestTry(from: louisville), trail)
    }

    func test_latestTry_sortsTheTrail_byTime() {
        let trail = outAndBack
        XCTAssertEqual(flight(.airborne, trail: trail.reversed()).latestTry(from: louisville), trail)
    }

    // MARK: - The label and the flight

    func test_label_isReturned_whateverTheGap() {
        XCTAssertEqual(LiveLabel(phase: .returned, gapMinutes: nil), .returned)
        XCTAssertEqual(LiveLabel(phase: .returned, gapMinutes: -26), .returned)
    }

    func test_mapFlight_hasReturned_andIsAtDeparture_onlyWhileBack() throws {
        let cases = try TripMapFixtures.liveCases()
        let back = try cases.flight(named: "an air return, back on the ground")
        let backFlight = try cases.mapFlight(back)
        let now = try cases.moment("13T12:41:00", of: back).at
        XCTAssertTrue(backFlight.hasReturned(at: now))
        XCTAssertTrue(backFlight.isAtDeparture(at: now))

        let again = try cases.flight(named: "an air return, then off again")
        let againAt = try cases.moment("13T13:41:40", of: again).at
        XCTAssertFalse(try cases.mapFlight(again).hasReturned(at: againAt))

        let stray = try cases.flight(named: "a stray point while taxiing")
        let strayAt = try cases.moment("13T12:20:30", of: stray).at
        XCTAssertFalse(try cases.mapFlight(stray).hasReturned(at: strayAt))
        XCTAssertTrue(try cases.mapFlight(stray).isAtDeparture(at: strayAt), "still on the ground")
    }
}
