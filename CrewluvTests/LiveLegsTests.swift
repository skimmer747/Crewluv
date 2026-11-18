//
//  LiveLegsTests.swift
//  CrewluvTests
//
//  One landing time (Stage 3 spec §7.1): a live flight's real times in place of the schedule's, in the legs the
//  status screen's model hands on. Held to the shared cases in Fixtures/TripMap.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LiveLegsTests: XCTestCase {

    private func assertEqual(_ date: Date, _ expected: Date, _ name: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(date.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.05, name, file: file, line: line)
    }

    /// The flights of `legs` that the case's answer covers, as the model makes them.
    private func flights(
        _ cases: TripMapFixtures.LiveCases, for legs: [TripLeg], answered: [String: LiveFlight], legacyDelayMinutes: Int? = nil
    ) -> [String: MapFlight] {
        LiveLegs.flights(for: legs, legacyDelayMinutes: legacyDelayMinutes, answered: answered, clockOffset: 0,
                         coordinate: cases.coordinateOrNil)
    }

    // MARK: - Which flights are watched

    func test_watched_areTheFlights_atTheirTimesMovedByTheirDelay() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let legs = [
            cases.wait("w1", .base, at: "SDF", from: flightCase.departure.addingTimeInterval(-7200), to: flightCase.departure),
            cases.tripLeg(flightCase, id: "f1", delayMinutes: 20),
            cases.wait("w2", .layover, at: "PHL", from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(86_400)),
        ]
        XCTAssertEqual(LiveLegs.watched(in: legs),
                       [LiveFlightSource.Leg(id: "f1", departure: flightCase.departure, arrival: flightCase.arrival)])
    }

    func test_watched_legsThatAreOneFlight_areWatchedOnce_underTheFirstOfTheirIDs() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let later = TripMapTestLegs.leg("a-later", from: "SDF", to: "CGN", start: flightCase.arrival.addingTimeInterval(86_400), hours: 8,
                                        flightNumber: "UPS208")
        let legs = [cases.tripLeg(flightCase, id: "twin-b"), later, cases.tripLeg(flightCase, id: "twin-a")]
        XCTAssertEqual(LiveLegs.watched(in: legs).map(\.id), ["twin-a", "a-later"])
        // Whichever comes first in the summary.
        XCTAssertEqual(LiveLegs.watched(in: legs.reversed()).map(\.id), ["twin-a", "a-later"])
    }

    // MARK: - Each flight with live data

    func test_flights_areOnlyTheFlightsCrewluCloudAnswered() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let live = try XCTUnwrap(cases.live(flightCase))
        let later = TripMapTestLegs.leg("f2", from: "SDF", to: "CGN", start: flightCase.arrival.addingTimeInterval(86_400), hours: 8,
                                        flightNumber: "UPS208")
        let legs = [cases.tripLeg(flightCase, id: "f1"), later]
        let made = flights(cases, for: legs, answered: ["f1": live, "gone": live])
        XCTAssertEqual(Array(made.keys), ["f1"])
        XCTAssertEqual(made["f1"]?.live, live)
        XCTAssertEqual(made["f1"]?.path.isReal, true)
        XCTAssertNotNil(made["f1"]?.record)
        XCTAssertTrue(flights(cases, for: legs, answered: [:]).isEmpty)
    }

    func test_flights_legsThatAreOneFlight_shareItsAnswer_whichComesUnderTheFirstOfTheirIDs() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let live = try XCTUnwrap(cases.live(flightCase))
        let legs = [cases.tripLeg(flightCase, id: "twin-b"), cases.tripLeg(flightCase, id: "twin-a")]
        let made = flights(cases, for: legs, answered: ["twin-a": live])
        XCTAssertEqual(made.keys.sorted(), ["twin-a", "twin-b"])
        XCTAssertEqual(made["twin-b"]?.live, live)
        XCTAssertEqual(made["twin-b"]?.plan.arrival, made["twin-a"]?.plan.arrival)
        // An answer under the other id is no flight's: Crewlu Cloud answers under the first.
        XCTAssertTrue(flights(cases, for: legs, answered: ["twin-b": live]).isEmpty)
    }

    func test_flights_handTheClockOffsetOn() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let legs = [cases.tripLeg(flightCase)]
        let answered = ["f1": try XCTUnwrap(cases.live(flightCase))]
        // A phone ten minutes fast: Crewlu Cloud's clock is 600 seconds behind it.
        let made = LiveLegs.flights(for: legs, legacyDelayMinutes: nil, answered: answered, clockOffset: -600,
                                    coordinate: cases.coordinateOrNil)
        let byThePhone = moment.at.addingTimeInterval(600)
        XCTAssertEqual(try XCTUnwrap(made["f1"]).progress(at: byThePhone).phase, .inAir,
                       "the plane was seen seconds ago by Crewlu Cloud's clock, not ten minutes ago")
        // With no offset handed on, the same moment would make the plane an estimate.
        let withNoOffset = try XCTUnwrap(flights(cases, for: legs, answered: answered)["f1"])
        XCTAssertEqual(withNoOffset.progress(at: byThePhone).phase, .estimated)
    }

    func test_flights_planIsTheScheduleMovedByTheLegsOwnDelay() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let live = try XCTUnwrap(cases.live(flightCase))
        let made = flights(cases, for: [cases.tripLeg(flightCase, id: "f1", delayMinutes: 20)], answered: ["f1": live])
        XCTAssertEqual(made["f1"]?.plan.departure, flightCase.departure)
        XCTAssertEqual(made["f1"]?.plan.arrival, flightCase.arrival)
    }

    func test_flights_whileADelayIsSummaryWide_areNone() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let live = try XCTUnwrap(cases.live(flightCase))
        let untagged = [cases.tripLeg(flightCase, id: "f1")]
        XCTAssertTrue(flights(cases, for: untagged, answered: ["f1": live], legacyDelayMinutes: 20).isEmpty)
        XCTAssertEqual(flights(cases, for: untagged, answered: ["f1": live], legacyDelayMinutes: 0).count, 1)
        // A leg that carries its own delay says which flight is late, whatever the summary says.
        let tagged = [cases.tripLeg(flightCase, id: "f1", delayMinutes: 20)]
        XCTAssertEqual(flights(cases, for: tagged, answered: ["f1": live], legacyDelayMinutes: 20).count, 1)
    }

    func test_flights_aLegWithAnAirportThatIsntKnown_hasNone() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let live = try XCTUnwrap(cases.live(flightCase))
        let leg = TripMapTestLegs.leg("f1", from: "SDF", to: "XXX", start: flightCase.departure, hours: 2)
        XCTAssertTrue(flights(cases, for: [leg], answered: ["f1": live]).isEmpty)
    }

    // MARK: - The real times

    func test_replacingTimes_withNoLiveData_changesNothing() {
        let legs = TripMapTestLegs.europeTrip()
        XCTAssertEqual(LiveLegs.replacingTimes(in: legs, with: [:], at: TripMapTestLegs.tripStart.addingTimeInterval(3600)), legs)
    }

    func test_replacingTimes_everySharedMoment_givesTheLegTheCasesTimes() throws {
        let cases = try TripMapFixtures.liveCases()
        var checked = 0
        for delayMinutes in [nil, 20, -10] as [Int?] {
            for flightCase in cases.flights {
                let leg = cases.tripLeg(flightCase, delayMinutes: delayMinutes)
                let made = flights(cases, for: [leg], answered: cases.live(flightCase).map { ["f1": $0] } ?? [:])
                for moment in flightCase.moments {
                    let name = "\(flightCase.name) at \(moment.at), delayed \(delayMinutes ?? 0)"
                    let replaced = try XCTUnwrap(LiveLegs.replacingTimes(in: [leg], with: made, at: moment.at).first)
                    let delay = TimeInterval((delayMinutes ?? 0) * 60)
                    // Every reader moves a leg's times by its delay: that must land on the real ones.
                    assertEqual(replaced.startTime.addingTimeInterval(delay), moment.start, name)
                    assertEqual(replaced.endTime.addingTimeInterval(delay), moment.end, name)
                    XCTAssertEqual(replaced.delayMinutes, delayMinutes, name)
                    XCTAssertEqual(replaced.id, leg.id, name)
                    checked += 1
                }
            }
        }
        XCTAssertGreaterThanOrEqual(checked, 60)
    }

    func test_replacingTimes_aFlightWithNothingReal_keepsItsLegUntouched() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "waiting to be seen")
        let leg = cases.tripLeg(flightCase, delayMinutes: 20)
        let made = flights(cases, for: [leg], answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        XCTAssertEqual(made.count, 1)
        XCTAssertEqual(LiveLegs.replacingTimes(in: [leg], with: made, at: flightCase.moments[0].at), [leg])
    }

    func test_replacingTimes_theWaitBeforeEnds_andTheWaitAfterStarts_whereTheFlightDoes() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let before = cases.wait("w1", .base, at: "SDF", from: flightCase.departure.addingTimeInterval(-7200), to: flightCase.departure)
        let after = cases.wait("w2", .layover, at: "PHL", from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(86_400))
        let legs = [before, cases.tripLeg(flightCase), after]
        let made = flights(cases, for: legs, answered: ["f1": try XCTUnwrap(cases.live(flightCase))])

        let replaced = LiveLegs.replacingTimes(in: legs, with: made, at: moment.at)

        XCTAssertEqual(replaced.map(\.id), ["w1", "f1", "w2"])
        // It left 10 minutes early and is 14 minutes ahead.
        XCTAssertEqual(replaced[0].startTime, before.startTime)
        assertEqual(replaced[0].endTime, moment.start)
        assertEqual(replaced[1].startTime, moment.start)
        assertEqual(replaced[1].endTime, moment.end)
        assertEqual(replaced[2].startTime, moment.end)
        XCTAssertEqual(replaced[2].endTime, after.endTime)
    }

    func test_replacingTimes_aLateArrival_startsTheWaitAfterItLater_andLeavesTheWaitBeforeAlone() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "off late, and seen from the start")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let before = cases.wait("w1", .turn, at: "SDF", from: flightCase.departure.addingTimeInterval(-3600), to: flightCase.departure)
        let after = cases.wait("w2", .layover, at: "PHL", from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(86_400))
        let legs = [before, cases.tripLeg(flightCase), after]
        let made = flights(cases, for: legs, answered: ["f1": try XCTUnwrap(cases.live(flightCase))])

        let replaced = LiveLegs.replacingTimes(in: legs, with: made, at: moment.at)

        XCTAssertEqual(replaced[0], before, "a late departure doesn't move the leg's start")
        XCTAssertEqual(replaced[1].startTime, flightCase.departure)
        assertEqual(replaced[1].endTime, moment.end)
        assertEqual(replaced[2].startTime, moment.end)
        XCTAssertGreaterThan(replaced[2].startTime, after.startTime)
    }

    func test_replacingTimes_movesOnlyTheWaitsBesideTheFlight() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let drive = TripMapTestLegs.leg("d1", .drive, from: "CVG", to: "SDF", start: flightCase.departure.addingTimeInterval(-7200), hours: 2)
        let nextFlight = TripMapTestLegs.leg("f2", from: "PHL", to: "SDF", start: flightCase.arrival.addingTimeInterval(3600), hours: 2)
        let home = cases.wait("w3", .home, at: "SDF", from: nextFlight.endTime, to: nextFlight.endTime.addingTimeInterval(86_400))
        let event = cases.wait("e1", .event, at: "PHL", from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(1800))
        let legs = [drive, cases.tripLeg(flightCase), event, nextFlight, home]
        let made = flights(cases, for: legs, answered: ["f1": try XCTUnwrap(cases.live(flightCase))])

        let replaced = LiveLegs.replacingTimes(in: legs, with: made, at: moment.at)

        XCTAssertEqual(replaced[0], drive, "a drive isn't a wait")
        XCTAssertEqual(replaced[2], event, "nor is an event")
        XCTAssertEqual(replaced[3], nextFlight)
        XCTAssertEqual(replaced[4], home, "the wait after another flight")
    }

    func test_replacingTimes_aWaitThatDoesntMeetTheFlight_isLeftAlone() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        // Training for half an hour after the flight, and only then the layover.
        let event = cases.wait("e1", .event, at: "PHL", from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(1800))
        let layover = cases.wait("w2", .layover, at: "PHL", from: event.endTime, to: flightCase.arrival.addingTimeInterval(86_400))
        // And the pilot reached base an hour before the flight, with the wait there written as ending early.
        let base = cases.wait("w1", .base, at: "SDF", from: flightCase.departure.addingTimeInterval(-7200),
                              to: flightCase.departure.addingTimeInterval(-1800))
        let legs = [base, cases.tripLeg(flightCase), event, layover]
        let made = flights(cases, for: legs, answered: ["f1": try XCTUnwrap(cases.live(flightCase))])

        let replaced = LiveLegs.replacingTimes(in: legs, with: made, at: moment.at)

        XCTAssertEqual(replaced[0], base)
        XCTAssertEqual(replaced[2], event)
        XCTAssertEqual(replaced[3], layover, "moved to the early arrival, it would start before the training does")
        assertEqual(replaced[1].endTime, moment.end)
    }

    func test_replacingTimes_aWaitMeetsADelayedFlight_atItsScheduledTimeOrItsDelayedOne() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let flight = cases.tripLeg(flightCase, delayMinutes: 20)
        let made = flights(cases, for: [flight], answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        for (name, start) in [("as scheduled", flight.endTime), ("as delayed", flightCase.arrival)] {
            let after = cases.wait("w2", .layover, at: "PHL", from: start, to: flightCase.arrival.addingTimeInterval(86_400))
            let replaced = LiveLegs.replacingTimes(in: [flight, after], with: made, at: moment.at)
            assertEqual(replaced[1].startTime, moment.end, name)
        }
    }

    @MainActor
    func test_replacingTimes_aWaitBetweenTwoLiveFlights_takesBothItsEdges() throws {
        let cases = try TripMapFixtures.liveCases()
        let first = try cases.flight(named: "landed, seen all the way")
        let second = try cases.flight(named: "ahead, in the air")
        // The second flight is the next day's: the same case, a day on.
        let day: TimeInterval = 86_400
        let firstLeg = cases.tripLeg(first, id: "f1")
        let wait = cases.wait("w1", .layover, at: "PHL", from: first.arrival, to: second.departure.addingTimeInterval(day))
        let secondLeg = TripLeg(id: "f2", tripId: "T1", type: .flight, startTime: second.departure.addingTimeInterval(day),
                                endTime: second.arrival.addingTimeInterval(day), airportCode: nil, city: nil, timezoneIdentifier: nil,
                                arrivalTimezoneIdentifier: nil, flightNumber: "UPS208", departureAirport: second.from,
                                arrivalAirport: second.to, departureCity: nil, arrivalCity: nil, tripDayNumber: nil, tripTotalDays: nil,
                                delayMinutes: nil, airlineCode: nil, label: nil)
        let secondAnswer = try XCTUnwrap(second.flight)
        let aDayOn = LiveFlight(
            legID: "f2", callsign: secondAnswer.callsign, state: secondAnswer.state,
            fix: secondAnswer.fix.map {
                LiveFlight.Fix(latitude: $0.latitude, longitude: $0.longitude, altitudeFeet: $0.altitudeFeet,
                               groundSpeedKnots: $0.groundSpeedKnots, trackDegrees: $0.trackDegrees, isOnGround: $0.isOnGround,
                               registration: $0.registration, typeCode: $0.typeCode, seenAt: $0.seenAt.addingTimeInterval(day))
            },
            landedAt: nil,
            trail: secondAnswer.trail.map {
                LiveFlight.TrailPoint(time: $0.time.addingTimeInterval(day), latitude: $0.latitude, longitude: $0.longitude,
                                      altitudeFeet: $0.altitudeFeet)
            })
        let legs = [firstLeg, wait, secondLeg]
        let made = flights(cases, for: legs, answered: ["f1": try XCTUnwrap(cases.live(first)), "f2": aDayOn])
        let moment = try cases.moment("13T12:41:50", of: second)

        let replaced = LiveLegs.replacingTimes(in: legs, with: made, at: moment.at.addingTimeInterval(day))

        assertEqual(replaced[1].startTime, replaced[0].endTime, "it starts where the first flight ended")
        assertEqual(replaced[1].endTime, replaced[2].startTime, "and ends where the second began")
        XCTAssertLessThan(replaced[1].startTime, wait.startTime)
        XCTAssertLessThan(replaced[1].endTime, wait.endTime)
        // And every card reads it so.
        for (carried, resolved) in zip(readBack(replaced), replaced) {
            assertEqual(carried.startTime, resolved.startTime, "\(resolved.id) starts")
            assertEqual(carried.endTime, resolved.endTime, "\(resolved.id) ends")
        }
    }

    @MainActor
    func test_replacingTimes_theStatusIsInFlightUntilTheRealPlaneArrives_andNoLonger() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let after = cases.wait("w2", .layover, at: "PHL", from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(86_400))
        let legs = [cases.tripLeg(flightCase), after]
        let made = flights(cases, for: legs, answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        let replaced = LiveLegs.replacingTimes(in: legs, with: made, at: moment.at)

        // The plane is 14 minutes ahead. Five minutes before the scheduled arrival it has already reached the gate.
        let fiveBefore = flightCase.arrival.addingTimeInterval(-300)
        XCTAssertEqual(TripStateResolver.resolve(legs: legs, at: fiveBefore)?.displayStatus, .inFlight, "by the schedule")
        XCTAssertEqual(TripStateResolver.resolve(legs: replaced, at: fiveBefore)?.displayStatus, .layover, "by the real plane")
        let stillFlying = moment.end.addingTimeInterval(-60)
        XCTAssertEqual(TripStateResolver.resolve(legs: replaced, at: stillFlying)?.displayStatus, .inFlight)
        // And it left 10 minutes early: five minutes before the scheduled departure it's already under way.
        let fiveBeforeLeaving = flightCase.departure.addingTimeInterval(-300)
        XCTAssertNil(TripStateResolver.resolve(legs: legs, at: fiveBeforeLeaving), "by the schedule, nothing has started")
        XCTAssertEqual(TripStateResolver.resolve(legs: replaced, at: fiveBeforeLeaving)?.displayStatus, .inFlight)
    }

    // MARK: - What every card reads

    /// The legs as every card reads them: written into a status as the model writes them, and read back through
    /// `SharedPilotStatus.tripLegs`, which ends any layover, base or home wait that a flight's written start falls in.
    @MainActor
    private func readBack(_ legs: [TripLeg]) -> [TripLeg] {
        SharedPilotStatus(
            pilotId: "pilot", pilotFirstName: "Alex", homeAirportCode: "SDF", baseAirportCode: "SDF", homeTimezone: nil,
            displayStatus: .inFlight, isSleeping: false, isHome: false, isInFlight: true, isOnDuty: true, currentAirport: nil,
            currentCity: nil, currentTimezone: nil, localTimeAtPilot: nil, currentLatitude: nil, currentLongitude: nil,
            currentFlightNumber: nil, currentFlightDeparture: nil, currentFlightArrival: nil, currentFlightDepartureTime: nil,
            currentFlightArrivalTime: nil, currentFlightArrivalTimezone: nil, homeArrivalTime: nil, homeArrivalLabel: nil,
            homeArrivalCity: nil, nextDepartureTime: nil, nextFlightNumber: nil, nextFlightDestination: nil,
            nextDepartureLabel: nil, lastTripEndDate: nil, lastTripDurationDays: nil, currentTripId: nil, tripDayNumber: nil,
            tripTotalDays: nil, upcomingCities: [], tripLegsJSON: LiveLegs.blob(legs), quickStatus: nil, quickStatusIcon: nil,
            quickStatusExpiry: nil, flightDelayMinutes: nil, displayNameByPartnerJSON: nil, lastUpdated: .now, appVersion: "test"
        ).tripLegs
    }

    @MainActor
    func test_replacingTimes_whatTheModelResolvesFrom_isWhatEveryCardReads() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        var checked = 0
        for delayMinutes in [nil, 20, -10] as [Int?] {
            for waitType in [TripLeg.LegType.layover, .base, .home, .turn] {
                let name = "\(waitType) before, delayed \(delayMinutes ?? 0)"
                let flight = cases.tripLeg(flightCase, delayMinutes: delayMinutes)
                // CrewLu writes its waits to meet the flight's scheduled times.
                let before = cases.wait("w1", waitType, at: "SDF", from: flight.startTime.addingTimeInterval(-7200), to: flight.startTime)
                let after = cases.wait("w2", .layover, at: "PHL", from: flight.endTime, to: flight.endTime.addingTimeInterval(86_400))
                let legs = [before, flight, after]
                let made = flights(cases, for: legs, answered: ["f1": try XCTUnwrap(cases.live(flightCase))])

                let replaced = LiveLegs.replacingTimes(in: legs, with: made, at: moment.at)
                let read = readBack(replaced)

                XCTAssertEqual(read.map(\.id), replaced.map(\.id), name)
                for (carried, resolved) in zip(read, replaced) {
                    assertEqual(carried.startTime, resolved.startTime, "\(name): \(resolved.id) starts")
                    assertEqual(carried.endTime, resolved.endTime, "\(name): \(resolved.id) ends")
                }
                // The flight is under way from its real start, whatever its delay.
                let delay = TimeInterval((delayMinutes ?? 0) * 60)
                assertEqual(read[1].startTime.addingTimeInterval(delay), moment.start, name)
                XCTAssertLessThanOrEqual(read[0].endTime, moment.start.addingTimeInterval(0.05), "\(name): the wait is over by then")
                checked += 1
            }
        }
        XCTAssertEqual(checked, 12)
    }

    func test_replacingTimes_aDelayedFlightOffEarly_endsTheWaitBeforeItAtItsWrittenStart() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        // Reported 20 minutes late, and then off 10 minutes sooner than that.
        let flight = cases.tripLeg(flightCase, delayMinutes: 20)
        let before = cases.wait("w1", .layover, at: "SDF", from: flight.startTime.addingTimeInterval(-7200), to: flight.startTime)
        let made = flights(cases, for: [before, flight], answered: ["f1": try XCTUnwrap(cases.live(flightCase))])

        let replaced = LiveLegs.replacingTimes(in: [before, flight], with: made, at: moment.at)

        // A delayed flight's wait ends where the flight's written start is, with the delay between them, as CrewLu
        // writes every delayed flight. The real start is 20 minutes after it.
        assertEqual(replaced[0].endTime, replaced[1].startTime)
        assertEqual(replaced[1].startTime.addingTimeInterval(20 * 60), moment.start)
    }

    // MARK: - "About"

    func test_isArrivalEstimated_isTrueOfALegWhoseEndIsTheRealPlanesEstimate() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let leg = cases.tripLeg(flightCase, delayMinutes: 20)
        let made = flights(cases, for: [leg], answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        let replaced = try XCTUnwrap(LiveLegs.replacingTimes(in: [leg], with: made, at: moment.at).first)
        XCTAssertFalse(LiveLegs.isArrivalEstimated(of: leg, in: made), "the schedule's time")
        XCTAssertTrue(LiveLegs.isArrivalEstimated(of: replaced, in: made))
        XCTAssertFalse(LiveLegs.isArrivalEstimated(of: replaced, in: [:]), "a flight with no live data")
    }

    func test_isArrivalEstimated_isFalseOnceThePlaneHasLanded() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "landed, seen all the way")
        let leg = cases.tripLeg(flightCase)
        let made = flights(cases, for: [leg], answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        let replaced = try XCTUnwrap(LiveLegs.replacingTimes(in: [leg], with: made, at: flightCase.moments[0].at).first)
        XCTAssertNotEqual(replaced.endTime, leg.endTime)
        XCTAssertFalse(LiveLegs.isArrivalEstimated(of: replaced, in: made))
    }

    func test_estimatedArrival_isWhenTheFlightUnderWayReachesItsGate_byTheRealPlanesEstimate() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        // A leg that's 20 minutes late by its own delay: the time the cards show is its end moved by that delay.
        let leg = cases.tripLeg(flightCase, delayMinutes: 20)
        let after = cases.wait("w2", .layover, at: "PHL", from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(86_400))
        let made = flights(cases, for: [leg, after], answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        let replaced = LiveLegs.replacingTimes(in: [leg, after], with: made, at: moment.at)

        let arrival = try XCTUnwrap(LiveLegs.estimatedArrival(in: replaced, flights: made, at: moment.at))
        assertEqual(arrival, moment.end, "the real plane's estimate, as the countdown has it")
        XCTAssertNil(LiveLegs.estimatedArrival(in: replaced, flights: [:], at: moment.at), "a flight with no live data")
        XCTAssertNil(LiveLegs.estimatedArrival(in: [leg, after], flights: made, at: moment.at), "the schedule's time")
    }

    func test_estimatedArrival_isNil_beforeTheFlightLeavesItsGate_onceItReachesIt_andOnceThePlaneIsDown() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let leg = cases.tripLeg(flightCase)
        let made = flights(cases, for: [leg], answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        let replaced = LiveLegs.replacingTimes(in: [leg], with: made, at: moment.at)
        let flight = try XCTUnwrap(replaced.first)
        XCTAssertNil(LiveLegs.estimatedArrival(in: replaced, flights: made, at: flight.startTime.addingTimeInterval(-1)), "before it leaves its gate")
        XCTAssertNotNil(LiveLegs.estimatedArrival(in: replaced, flights: made, at: flight.startTime))
        XCTAssertNotNil(LiveLegs.estimatedArrival(in: replaced, flights: made, at: flight.endTime.addingTimeInterval(-1)))
        XCTAssertNil(LiveLegs.estimatedArrival(in: replaced, flights: made, at: flight.endTime), "once it reaches its gate")

        // A plane that's down has a real time, not an estimate, while it's still on its way to the gate.
        let landedCase = try cases.flight(named: "landed, seen all the way")
        let landedLeg = cases.tripLeg(landedCase)
        let landed = flights(cases, for: [landedLeg], answered: ["f1": try XCTUnwrap(cases.live(landedCase))])
        let taxiing = LiveLegs.replacingTimes(in: [landedLeg], with: landed, at: landedCase.moments[0].at)
        let justBeforeTheGate = try XCTUnwrap(taxiing.first).endTime.addingTimeInterval(-30)
        XCTAssertNil(LiveLegs.estimatedArrival(in: taxiing, flights: landed, at: justBeforeTheGate))
    }

    // MARK: - Legs that are one flight

    @MainActor
    func test_replacingTimes_legsThatAreOneFlight_allTakeTheRealTimes_soNoneIsLeftOnTheSchedule() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let after = cases.wait("w2", .layover, at: "PHL", from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(86_400))
        let legs = [cases.tripLeg(flightCase, id: "twin-a"), cases.tripLeg(flightCase, id: "twin-b"), after]
        let made = flights(cases, for: legs, answered: ["twin-a": try XCTUnwrap(cases.live(flightCase))])
        let replaced = LiveLegs.replacingTimes(in: legs, with: made, at: moment.at)

        for twin in replaced.prefix(2) {
            assertEqual(twin.startTime, moment.start, twin.id)
            assertEqual(twin.endTime, moment.end, twin.id)
        }
        assertEqual(replaced[2].startTime, moment.end, "the wait after starts where the flight ends")
        // The plane is ahead: five minutes before the scheduled arrival it has reached the gate, and no leg of the
        // flight still has it in the air.
        let fiveBefore = flightCase.arrival.addingTimeInterval(-300)
        XCTAssertEqual(TripStateResolver.resolve(legs: replaced, at: fiveBefore)?.displayStatus, .layover)
        XCTAssertEqual(TripStateResolver.resolve(legs: readBack(replaced), at: fiveBefore)?.displayStatus, .layover)
    }

    // MARK: - The schedule's list

    func test_forTheSchedule_aLiveFlightShowsItsRealTimes_withItsDelayInsideThem() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        // CrewLu has tagged the flight 20 minutes late, so its written times are 20 minutes before its real ones.
        // The schedule's list adds no delay: it would show them as they're written.
        let leg = cases.tripLeg(flightCase, delayMinutes: 20)
        let after = cases.wait("w2", .layover, at: "PHL", from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(86_400))
        let made = flights(cases, for: [leg, after], answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        let replaced = LiveLegs.replacingTimes(in: [leg, after], with: made, at: moment.at)
        assertEqual(replaced[0].endTime, moment.end.addingTimeInterval(-20 * 60), "as the status carries it")

        let shown = LiveLegs.forTheSchedule(replaced, with: made)
        assertEqual(shown[0].startTime, moment.start)
        assertEqual(shown[0].endTime, moment.end)
        XCTAssertNil(shown[0].delayMinutes)
        XCTAssertEqual(shown[1], replaced[1], "the wait is as the status carries it")
        assertEqual(shown[1].startTime, moment.end, "and starts where the flight is shown to end")
    }

    func test_forTheSchedule_aTimeTheRealPlaneHasntMoved_staysAsWritten_whereItsWaitMeetsIt() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "off late, and seen from the start")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        // CrewLu has tagged the flight 30 minutes late, and its waits meet its written times. The plane left later
        // still, and a late departure doesn't move a leg's start. Its landing is the real plane's.
        let leg = cases.tripLeg(flightCase, delayMinutes: 30)
        let before = cases.wait("w1", .turn, at: "SDF", from: leg.startTime.addingTimeInterval(-3600), to: leg.startTime)
        let after = cases.wait("w2", .layover, at: "PHL", from: leg.endTime, to: leg.endTime.addingTimeInterval(86_400))
        let legs = [before, leg, after]
        let made = flights(cases, for: legs, answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        let replaced = LiveLegs.replacingTimes(in: legs, with: made, at: moment.at)
        XCTAssertEqual(replaced[1].startTime, leg.startTime, "the start isn't the real plane's")
        XCTAssertEqual(replaced[0], before)

        let shown = LiveLegs.forTheSchedule(replaced, with: made)
        XCTAssertEqual(shown[1].startTime, leg.startTime, "as it's written, and not half an hour later")
        XCTAssertEqual(shown[1].startTime, shown[0].endTime, "where the wait before it ends: no gap in the list")
        assertEqual(shown[1].endTime, moment.end, "the real plane's landing")
        assertEqual(shown[2].startTime, shown[1].endTime, "where the wait after it starts: no overlap")
        XCTAssertNil(shown[1].delayMinutes)
    }

    @MainActor
    func test_forTheSchedule_theWaitBeforeAFlightTaggedLate_endsWhereTheFlightIsShownToStart() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        // CrewLu has tagged the flight 20 minutes late and written its layover up to the flight's written start. The
        // plane left before the delayed time, so its start is the real plane's.
        let leg = cases.tripLeg(flightCase, delayMinutes: 20)
        let before = cases.wait("w1", .layover, at: "SDF", from: leg.startTime.addingTimeInterval(-86_400), to: leg.startTime)
        let after = cases.wait("w2", .layover, at: "PHL", from: leg.endTime, to: leg.endTime.addingTimeInterval(86_400))
        let legs = [before, leg, after]
        let made = flights(cases, for: legs, answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        // The legs as the schedule's list is handed them: read back from the status.
        let carried = readBack(LiveLegs.replacingTimes(in: legs, with: made, at: moment.at))
        let carriedWait = try XCTUnwrap(carried.first { $0.id == "w1" })
        assertEqual(carriedWait.endTime, moment.start.addingTimeInterval(-20 * 60), "the status ends it at the flight's written start")

        let shown = LiveLegs.forTheSchedule(carried, with: made)
        let flight = try XCTUnwrap(shown.first { $0.id == "f1" })
        let waitBefore = try XCTUnwrap(shown.first { $0.id == "w1" })
        let waitAfter = try XCTUnwrap(shown.first { $0.id == "w2" })
        assertEqual(flight.startTime, moment.start, "the real plane's start")
        assertEqual(waitBefore.endTime, flight.startTime, "no hole in the list before the flight")
        XCTAssertEqual(waitBefore.startTime, before.startTime)
        assertEqual(flight.endTime, moment.end)
        assertEqual(waitAfter.startTime, flight.endTime, "and none after it")
    }

    func test_forTheSchedule_aLiveFlightWithNothingRealYet_isAsItWas() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "waiting to be seen")
        let leg = cases.tripLeg(flightCase, delayMinutes: 20)
        let made = flights(cases, for: [leg], answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        let replaced = LiveLegs.replacingTimes(in: [leg], with: made, at: flightCase.moments[0].at)
        XCTAssertEqual(LiveLegs.forTheSchedule(replaced, with: made), [leg])
    }

    func test_forTheSchedule_aFlightWithNoLiveData_isAsItWas() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let live = cases.tripLeg(flightCase, id: "f1")
        let made = flights(cases, for: [live], answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        // The next day's flight, which CrewLu has tagged 30 minutes late, has no live data: the list shows it as it
        // always has.
        let late = TripMapTestLegs.leg("late", from: "SDF", to: "CGN", start: flightCase.arrival.addingTimeInterval(86_400), hours: 8,
                                       flightNumber: "UPS208", delayMinutes: 30)
        XCTAssertEqual(LiveLegs.forTheSchedule([live, late], with: made), [live, late])
        XCTAssertEqual(LiveLegs.forTheSchedule([late], with: [:]), [late])
    }

    // MARK: - The legs as the status carries them

    func test_blob_isReadBackAsTheSameLegs() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let leg = cases.tripLeg(flightCase, delayMinutes: 20)
        let made = flights(cases, for: [leg], answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        let replaced = LiveLegs.replacingTimes(in: [leg], with: made, at: moment.at)

        let blob = try XCTUnwrap(LiveLegs.blob(replaced))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let read = try decoder.decode([TripLeg].self, from: blob)

        XCTAssertEqual(read.count, 1)
        assertEqual(read[0].endTime.addingTimeInterval(20 * 60), moment.end)
        XCTAssertTrue(LiveLegs.isArrivalEstimated(of: read[0], in: made), "it's still marked an estimate after the status carried it")
        XCTAssertEqual(LiveLegs.blob(replaced), blob, "the same legs, the same bytes")
    }

    // MARK: - The schedule's "about"

    @MainActor
    func test_estimatedArrivals_areTheLegsWhoseArrivalIsTheRealPlanesEstimate_asTheStatusCarriesThem() throws {
        let cases = try TripMapFixtures.liveCases()
        func estimated(_ name: String, at time: String) throws -> Set<String> {
            let flightCase = try cases.flight(named: name)
            let moment = try cases.moment(time, of: flightCase)
            let legs = [cases.tripLeg(flightCase)]
            let made = flights(cases, for: legs, answered: cases.live(flightCase).map { ["f1": $0] } ?? [:])
            return LiveLegs.estimatedArrivals(in: readBack(LiveLegs.replacingTimes(in: legs, with: made, at: moment.at)), flights: made)
        }
        XCTAssertEqual(try estimated("ahead, in the air", at: "13T12:41:50"), ["f1"])
        XCTAssertEqual(try estimated("still on the ground twenty minutes after", at: "13T12:35:00"), ["f1"])
        XCTAssertEqual(try estimated("landed, seen all the way", at: "13T13:30:00"), [], "a landed plane's arrival is real")
        XCTAssertEqual(try estimated("on the ground before the plan's takeoff", at: "13T12:10:00"), [], "still the plan's")
        XCTAssertEqual(try estimated("no live data", at: "13T12:30:00"), [])
    }
}
