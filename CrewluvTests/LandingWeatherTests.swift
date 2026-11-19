//
//  LandingWeatherTests.swift
//  CrewluvTests
//
//  Which flights get weather on landing (Stage 2 spec §7.2): the one in the air, and the next when it lands within
//  48 hours. The Europe trip's flights land at +8, +38 and +72 hours.
//

import XCTest
@testable import Crewluv

final class LandingWeatherTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart

    private func ids(at hours: Double) throws -> [String] {
        let now = start.addingTimeInterval(hours * 3600)
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: now))
        return LandingWeather.flightsToForecast(in: map, now: now).map(\.id)
    }

    func test_flightsToForecast_inTheAir_thisFlightAndTheNext() throws {
        XCTAssertEqual(try ids(at: 4), ["f1", "f2"])
    }

    func test_flightsToForecast_onALayover_theNextFlight() throws {
        XCTAssertEqual(try ids(at: 12), ["f2"])
    }

    // MARK: - At takeoff (time labels design §3.3)

    private func takeoff(at hours: Double) throws -> (id: String, takeoff: Takeoff)? {
        let now = start.addingTimeInterval(hours * 3600)
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: now))
        return LandingWeather.takeoffToFetch(in: map, now: now).map { ($0.leg.id, $0.takeoff) }
    }

    func test_takeoffToFetch_inTheAir_isThisFlightsTakeoff_theSchedulesWithNoRealPlane() throws {
        let fetch = try XCTUnwrap(try takeoff(at: 4))
        XCTAssertEqual(fetch.id, "f1")
        XCTAssertEqual(fetch.takeoff, Takeoff(time: start.addingTimeInterval(FlightProgress.taxiOutAllowance), isSeen: false))
    }

    func test_takeoffToFetch_taxiingOut_beforeTheTakeoff_isNil() throws {
        XCTAssertNil(try takeoff(at: FlightProgress.taxiOutAllowance / 3600 / 2))
    }

    func test_takeoffToFetch_onALayover_isNil() throws {
        XCTAssertNil(try takeoff(at: 12))
    }

    func test_flightsToForecast_aFlightLandingMoreThan48HoursOut_isLeftOut() throws {
        XCTAssertEqual(try ids(at: -24), ["f1"], "lands 32 hours out")
        XCTAssertEqual(try ids(at: -48), [], "lands 56 hours out")
    }
}
