//
//  FactsTestData+Live.swift
//  CrewluvTests
//
//  A made-up real plane for the equator flight (Stage 3 spec §8), so the facts on a real path can be worked out by
//  hand. The schedule has the flight in the air from 10:15 to 13:15 UTC, and its plan cruises at about 420 kt. The
//  real plane leaves 0° E at 10:15 too, and flies a degree of longitude every 8 minutes (450 kt): it's at 5° E at
//  10:55, 10° E at 11:35, 14° E at 12:07 and 20° E at 12:55. It's seen every 2 minutes from 10:17.
//

import CoreLocation
import Foundation
@testable import Crewluv

extension FactsTestData {

    /// When the real plane leaves the ground: 10:15 UTC.
    static let liveTakeoff = equinox.addingTimeInterval(15 * 60)

    /// The real plane takes this long for each degree of longitude.
    static let liveSecondsADegree: TimeInterval = 480

    /// One degree along the equator, in meters and in miles.
    static let metersADegree = GreatCircle.earthRadius * .pi / 180
    static let milesADegree = metersADegree / GreatCircle.metersPerMile

    static func liveLongitude(at date: Date) -> Double {
        date.timeIntervalSince(liveTakeoff) / liveSecondsADegree
    }

    static func liveTime(atLongitude degrees: Double) -> Date {
        liveTakeoff.addingTimeInterval(degrees * liveSecondsADegree)
    }

    /// The real plane's live data as Crewlu Cloud has it once it was last seen at `seenUntil`.
    /// - Parameters:
    ///   - unseen: longitudes between which nobody saw it.
    ///   - landedAt: when it was seen on the ground at the arrival airport, for a flight that has landed.
    ///   - latitude: how far north of the equator it flies at a longitude, for a path that leaves the great circle.
    static func equatorLive(
        seenUntil: Date, unseen: ClosedRange<Double>? = nil, landedAt: Date? = nil, altitudeFeet: Double? = 36_000,
        typeCode: String? = "B763", registration: String? = "N370UP", latitude: (Double) -> Double = { _ in 0 }
    ) -> LiveFlight {
        var trail: [LiveFlight.TrailPoint] = []
        var time = liveTakeoff.addingTimeInterval(120)
        while time <= seenUntil {
            let longitude = liveLongitude(at: time)
            let isSeen = unseen.map { !($0.lowerBound < longitude && longitude < $0.upperBound) } ?? true
            if isSeen {
                trail.append(LiveFlight.TrailPoint(time: time, latitude: latitude(longitude), longitude: longitude,
                                                   altitudeFeet: altitudeFeet))
            }
            time = time.addingTimeInterval(120)
        }
        let longitude = liveLongitude(at: seenUntil)
        let fix = landedAt.map {
            LiveFlight.Fix(latitude: 0, longitude: 20, altitudeFeet: nil, groundSpeedKnots: 30, trackDegrees: nil,
                           isOnGround: true, registration: registration, typeCode: typeCode, seenAt: $0)
        } ?? LiveFlight.Fix(latitude: latitude(longitude), longitude: longitude, altitudeFeet: altitudeFeet,
                            groundSpeedKnots: 450, trackDegrees: 90, isOnGround: false, registration: registration,
                            typeCode: typeCode, seenAt: seenUntil)
        return LiveFlight(legID: "eq", callsign: "TST1", state: landedAt == nil ? .airborne : .landed, fix: fix,
                          landedAt: landedAt, trail: trail)
    }

    /// The equator flight with `live` for its real plane, as the status screen's model hands it on at `now`:
    /// between the real plane's times.
    static func equatorLiveLeg(_ live: LiveFlight?, at now: Date, to east: Double = 20, id: String = "eq",
                               clockOffset: TimeInterval = 0) throws -> MapLeg {
        let scheduled = equatorFlight(from: 0, to: east, id: id)
        let flight = MapFlight(departure: scheduled.start, arrival: scheduled.end, from: scheduled.origin.coordinate,
                               to: scheduled.destination.coordinate, live: live, clockOffset: clockOffset)
        guard let flight else { throw TripMapFixtures.MissingPlan(name: "the equator flight") }
        let progress = flight.progress(at: now)
        return MapLeg(id: scheduled.id, kind: .flight, origin: scheduled.origin, destination: scheduled.destination,
                      start: progress.start, end: progress.end, flightNumber: scheduled.flightNumber, flight: flight)
    }

    /// Home, half a degree north of 14° E: the equator flight passes 35 mi from it.
    static let homeByTheEquator = mark("HOME", latitude: 0.5, longitude: 14)

    /// A path that leaves the great circle: north from 6° E to 2° N by 7° E, along it to 9° E, and back to the
    /// equator by 10° E.
    static func dogLeg(_ longitude: Double) -> Double {
        max(0, min(longitude - 6, 10 - longitude, 1)) * 2
    }
}
