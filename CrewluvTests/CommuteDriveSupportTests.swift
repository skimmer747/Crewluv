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
}
