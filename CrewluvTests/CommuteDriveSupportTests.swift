import XCTest
@testable import Crewluv

final class CommuteDriveSupportTests: XCTestCase {

    // MARK: - Helpers

    private func driveLeg(
        from: String, to: String, arrivalCity: String? = nil,
        start: Date, end: Date, tripId: String? = nil, label: String? = "Driving"
    ) -> TripLeg {
        TripLeg(
            id: "drive-\(from)-\(to)", tripId: tripId, type: .drive,
            startTime: start, endTime: end,
            airportCode: nil, city: nil,
            timezoneIdentifier: nil, arrivalTimezoneIdentifier: nil,
            flightNumber: nil, departureAirport: from, arrivalAirport: to,
            departureCity: nil, arrivalCity: arrivalCity,
            tripDayNumber: nil, tripTotalDays: nil, delayMinutes: nil,
            airlineCode: nil, label: label
        )
    }

    private func flightLeg(
        from: String, to: String, start: Date, end: Date,
        tripId: String? = "t1", delayMinutes: Int? = nil, id: String? = nil
    ) -> TripLeg {
        TripLeg(
            id: id ?? "flight-\(from)-\(to)", tripId: tripId, type: .flight,
            startTime: start, endTime: end,
            airportCode: nil, city: nil,
            timezoneIdentifier: nil, arrivalTimezoneIdentifier: nil,
            flightNumber: nil, departureAirport: from, arrivalAirport: to,
            departureCity: nil, arrivalCity: nil,
            tripDayNumber: nil, tripTotalDays: nil, delayMinutes: delayMinutes,
            airlineCode: nil, label: nil
        )
    }

    // MARK: - LegType decoding

    func test_legType_decodesDriveRawValue_asDrive() throws {
        let json = #"{"type":"drive"}"#.data(using: .utf8)!
        struct Wrapper: Decodable { let type: TripLeg.LegType }
        XCTAssertEqual(try JSONDecoder().decode(Wrapper.self, from: json).type, .drive)
    }

    func test_legType_decodesUnknownRawValue_asUnknown() throws {
        let json = #"{"type":"teleport"}"#.data(using: .utf8)!
        struct Wrapper: Decodable { let type: TripLeg.LegType }
        XCTAssertEqual(try JSONDecoder().decode(Wrapper.self, from: json).type, .unknown)
    }

    // MARK: - PilotDisplayStatus bridge

    func test_displayStatus_bridgesDrivingHome() {
        XCTAssertEqual(PilotDisplayStatus(rawDisplayString: "Driving Home"), .drivingHome)
        XCTAssertEqual(PilotDisplayStatus.drivingHome.rawDisplayString, "Driving Home")
    }

    func test_displayStatus_bridgesDrivingToWork() {
        XCTAssertEqual(PilotDisplayStatus(rawDisplayString: "Driving to Work"), .drivingToWork)
        XCTAssertEqual(PilotDisplayStatus.drivingToWork.rawDisplayString, "Driving to Work")
    }

    func test_displayStatus_unknownDrivingString_isPreserved() {
        XCTAssertEqual(PilotDisplayStatus(rawDisplayString: "Driving Sideways"),
                       .unknown("Driving Sideways"))
    }

    // MARK: - Active drive resolution

    func test_resolve_activeDriveToHome_isDrivingHome() {
        let now = Date()
        let leg = driveLeg(from: "SDF", to: "MCO", arrivalCity: "Orlando",
                           start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(3600))
        let state = TripStateResolver.resolve(legs: [leg], homeAirportCode: "MCO", baseAirportCode: "SDF", at: now)
        XCTAssertEqual(state?.displayStatus, .drivingHome)
        XCTAssertEqual(state?.isInFlight, false)
    }

    func test_resolve_activeDriveToWork_isDrivingToWork() {
        let now = Date()
        let leg = driveLeg(from: "MCO", to: "SDF", arrivalCity: "Louisville",
                           start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(3600))
        let state = TripStateResolver.resolve(legs: [leg], homeAirportCode: "MCO", baseAirportCode: "SDF", at: now)
        XCTAssertEqual(state?.displayStatus, .drivingToWork)
    }

    func test_resolveHomeArrival_includesDriveHomeLeg() {
        let now = Date()
        let drive = driveLeg(from: "SDF", to: "MCO", arrivalCity: "Orlando",
                             start: now.addingTimeInterval(3600), end: now.addingTimeInterval(3600 * 6))
        let info = TripStateResolver.resolveHomeArrival(legs: [drive], homeAirportCode: "MCO", at: now)
        XCTAssertEqual(info?.arrivalTime, drive.endTime)
        XCTAssertEqual(info?.arrivalLabel, "Back Home In")
    }

    func test_resolveGap_afterCompletedDriveHome_isHome() {
        let now = Date()
        let drive = driveLeg(from: "SDF", to: "MCO", arrivalCity: "Orlando",
                             start: now.addingTimeInterval(-3600 * 6), end: now.addingTimeInterval(-3600))
        let state = TripStateResolver.resolve(legs: [drive], homeAirportCode: "MCO", baseAirportCode: "SDF", at: now)
        XCTAssertEqual(state?.displayStatus, .home)
        XCTAssertEqual(state?.currentAirport, "MCO")
    }

    func test_resolveGap_afterCompletedDriveToWork_beforeTrip_isBase() {
        let now = Date()
        let drive = driveLeg(from: "MCO", to: "SDF", arrivalCity: "Louisville",
                             start: now.addingTimeInterval(-3600 * 3), end: now.addingTimeInterval(-3600))
        let flight = TripLeg(
            id: "f1", tripId: "t1", type: .flight,
            startTime: now.addingTimeInterval(3600 * 2), endTime: now.addingTimeInterval(3600 * 4),
            airportCode: nil, city: nil, timezoneIdentifier: nil, arrivalTimezoneIdentifier: nil,
            flightNumber: "DAL1", departureAirport: "SDF", arrivalAirport: "ATL",
            departureCity: "Louisville", arrivalCity: "Atlanta",
            tripDayNumber: 1, tripTotalDays: 3, delayMinutes: nil, airlineCode: nil, label: nil)
        let state = TripStateResolver.resolve(legs: [drive, flight], homeAirportCode: "MCO", baseAirportCode: "SDF", at: now)
        XCTAssertEqual(state?.displayStatus, .base)
        XCTAssertEqual(state?.currentAirport, "SDF")
    }

    // MARK: - nextDriveToWork (leave-home countdown)

    func test_nextDriveToWork_returnsUpcomingDriveToBase() {
        let now = Date()
        let drive = driveLeg(from: "MCO", to: "SDF", arrivalCity: "Louisville",
                             start: now.addingTimeInterval(3600), end: now.addingTimeInterval(3600 * 3))
        let leg = TripStateResolver.nextDriveToWork(legs: [drive], baseAirportCode: "SDF", at: now)
        XCTAssertEqual(leg?.id, drive.id)
    }

    func test_nextDriveToWork_ignoresPastDrive() {
        let now = Date()
        let drive = driveLeg(from: "MCO", to: "SDF", arrivalCity: "Louisville",
                             start: now.addingTimeInterval(-3600 * 3), end: now.addingTimeInterval(-3600))
        XCTAssertNil(TripStateResolver.nextDriveToWork(legs: [drive], baseAirportCode: "SDF", at: now))
    }

    func test_nextDriveToWork_ignoresDriveHome() {
        let now = Date()
        let driveHome = driveLeg(from: "SDF", to: "MCO", arrivalCity: "Orlando",
                                 start: now.addingTimeInterval(3600), end: now.addingTimeInterval(3600 * 3))
        XCTAssertNil(TripStateResolver.nextDriveToWork(legs: [driveHome], baseAirportCode: "SDF", at: now))
    }

    func test_nextDriveToWork_nilBase_returnsNil() {
        let now = Date()
        let drive = driveLeg(from: "MCO", to: "SDF", arrivalCity: "Louisville",
                             start: now.addingTimeInterval(3600), end: now.addingTimeInterval(3600 * 3))
        XCTAssertNil(TripStateResolver.nextDriveToWork(legs: [drive], baseAirportCode: nil, at: now))
    }

    func test_nextDriveToWork_picksEarliestOfMultiple() {
        let now = Date()
        let soon = driveLeg(from: "MCO", to: "SDF", arrivalCity: "Louisville",
                            start: now.addingTimeInterval(3600), end: now.addingTimeInterval(3600 * 3))
        let later = driveLeg(from: "MCO", to: "SDF", arrivalCity: "Louisville",
                             start: now.addingTimeInterval(3600 * 10), end: now.addingTimeInterval(3600 * 12))
        let leg = TripStateResolver.nextDriveToWork(legs: [later, soon], baseAirportCode: "SDF", at: now)
        XCTAssertEqual(leg?.startTime, soon.startTime)
    }

    func test_nextDriveToWork_driveAfterNextFlight_returnsNil() {
        let now = Date()
        // The upcoming trip departs base in 2 days with no commute scheduled;
        // the only drive-to-base belongs to a later trip. It must not be
        // surfaced as "leaving for work" for the upcoming trip.
        let flight = flightLeg(from: "SDF", to: "HNL",
                               start: now.addingTimeInterval(3600 * 48), end: now.addingTimeInterval(3600 * 58))
        let laterTripDrive = driveLeg(from: "MCO", to: "SDF", arrivalCity: "Louisville",
                                      start: now.addingTimeInterval(3600 * 24 * 16),
                                      end: now.addingTimeInterval(3600 * (24 * 16 + 2)))
        XCTAssertNil(TripStateResolver.nextDriveToWork(legs: [flight, laterTripDrive], baseAirportCode: "SDF", at: now))
    }

    func test_nextDriveToWork_driveBeforeNextFlight_isReturned() {
        let now = Date()
        let drive = driveLeg(from: "MCO", to: "SDF", arrivalCity: "Louisville",
                             start: now.addingTimeInterval(3600 * 44), end: now.addingTimeInterval(3600 * 46))
        let flight = flightLeg(from: "SDF", to: "HNL",
                               start: now.addingTimeInterval(3600 * 48), end: now.addingTimeInterval(3600 * 58))
        let leg = TripStateResolver.nextDriveToWork(legs: [flight, drive], baseAirportCode: "SDF", at: now)
        XCTAssertEqual(leg?.id, drive.id)
    }

    /// A commute flight whose scheduled start is past but is delayed into the future must
    /// still gate out a later trip's drive; comparing scheduled starts would drop the
    /// delayed flight and resurface the far-away drive (the trip-jump countdown bug).
    func test_nextDriveToWork_delayedHomeFlightInWindow_stillGatesLaterDrive() {
        let now = Date()
        let delayedCommuteFlight = flightLeg(
            from: "MCO", to: "SDF",
            start: now.addingTimeInterval(-600), end: now.addingTimeInterval(3600),
            delayMinutes: 120) // effective start ~110 min in the future
        let laterTripDrive = driveLeg(from: "MCO", to: "SDF", arrivalCity: "Louisville",
                                      start: now.addingTimeInterval(3600 * 24 * 16),
                                      end: now.addingTimeInterval(3600 * (24 * 16 + 2)))
        XCTAssertNil(TripStateResolver.nextDriveToWork(
            legs: [delayedCommuteFlight, laterTripDrive], baseAirportCode: "SDF", at: now))
    }

    // MARK: - resolveHomeArrival (Back Home In)

    /// A later trip's drive home, beyond a >24h at-home gap, must not hijack the
    /// current trip's "Back Home In" when the current trip has no homebound leg.
    func test_resolveHomeArrival_laterTripDriveHome_doesNotHijack() {
        let now = Date()
        // Current trip: an active flight ending at base (no arrival home in this block).
        let activeFlight = flightLeg(from: "ATL", to: "SDF",
                                     start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(1800))
        // Separate later trip (>24h gap): a drive home to MCO.
        let laterDriveHome = driveLeg(from: "SDF", to: "MCO", arrivalCity: "Orlando",
                                      start: now.addingTimeInterval(3600 * 24 * 18),
                                      end: now.addingTimeInterval(3600 * (24 * 18 + 2)))
        let info = TripStateResolver.resolveHomeArrival(
            legs: [activeFlight, laterDriveHome], homeAirportCode: "MCO", at: now)
        XCTAssertNil(info)
    }

    /// Within one trip block, a mid-trip turn that touches home must not be reported as
    /// the homecoming — the last arrival home is the true return.
    func test_resolveHomeArrival_turnThroughHome_picksFinalArrival() {
        let now = Date()
        let turnToHome = flightLeg(from: "ATL", to: "MCO",
                                   start: now.addingTimeInterval(3600), end: now.addingTimeInterval(3600 * 2),
                                   id: "turn-in")
        let backOut = flightLeg(from: "MCO", to: "ATL",
                                start: now.addingTimeInterval(3600 * 3), end: now.addingTimeInterval(3600 * 4),
                                id: "turn-out")
        let finalHome = flightLeg(from: "ATL", to: "MCO",
                                  start: now.addingTimeInterval(3600 * 7), end: now.addingTimeInterval(3600 * 8),
                                  id: "final-home")
        let info = TripStateResolver.resolveHomeArrival(
            legs: [turnToHome, backOut, finalHome], homeAirportCode: "MCO", at: now)
        XCTAssertEqual(info?.arrivalTime, finalHome.endTime)
    }
}
