//
//  LiveCases.swift
//  CrewluvTests
//
//  Reads Fixtures/TripMap/live-cases.json: the real plane's shared cases, which the website runs too (Stage 3 spec
//  §16.1). Its distances are nautical miles, and its flights are entries of partner_live's answer as the door sends them.
//

import CoreLocation
import Foundation
@testable import Crewluv

extension TripMapFixtures {

    struct LiveCases: Decodable {
        struct Constants: Decodable {
            let taxiOutMinutes: Double
            let taxiInMinutes: Double
            let shortestCruiseMinutes: Double
            let descentDistanceNm: Double
            let descentSpeedKt: Double
            let freshSeconds: Double
            let airportRadiusNm: Double
            let onScheduleMinutes: Int
            let unseenGapMinutes: Double
            let firstPointRadiusNm: Double
            let ownSpeedLeastMinutes: Double
            let ownSpeedLeastShare: Double
            let ownSpeedMostShare: Double
            let ownSpeedAheadMinutes: Double
            let windowOpensMinutesBefore: Double
            let windowClosesHoursAfter: Double
            let windowKeepsMinutes: Double
            let windowEndsHoursAfter: Double
        }

        struct Plan: Decodable {
            struct TimeToFly: Decodable {
                let distanceNm: Double
                let seconds: Double
            }

            struct DistanceLeft: Decodable {
                let minutes: Double
                let distanceNm: Double
            }

            let name: String
            let from: String
            let to: String
            let departure: Date
            let arrival: Date
            let lengthNm: Double
            let takeoff: Date
            let touchdown: Date
            let isShort: Bool
            let speedKt: Double
            let timeToFly: [TimeToFly]
            let distanceLeft: [DistanceLeft]
        }

        struct Flight: Decodable {
            struct Path: Decodable {
                let isReal: Bool
                let lengthNm: Double
                let flownNm: Double
                /// The plane's own speed over its cruise so far, or nil when too little of it has been seen.
                let ownSpeedKt: Double?
                /// `FlightPath.Kind`'s raw values, one for each stretch.
                let stretchKinds: [String]
                let seenNm: Double
                let unseenNm: Double
                let plannedNm: Double
            }

            struct Moment: Decodable {
                let at: Date
                let note: String
                /// `LiveProgress.Phase`'s raw value.
                let phase: String
                let touchdown: Date?
                let liveArrival: Date?
                let gapMinutes: Int?
                let label: String?
                let planeAlongNm: Double?
                let plane: [Double]?
                let ghostAlongNm: Double?
                let ghost: [Double]?
                let start: Date
                let end: Date
            }

            struct Record: Decodable {
                struct Place: Decodable {
                    let at: Date
                    let alongNm: Double
                    let point: [Double]
                }

                struct Time: Decodable {
                    let alongNm: Double
                    let at: Date
                }

                let takeoff: Date?
                let touchdown: Date
                let places: [Place]
                let times: [Time]
            }

            let name: String
            let from: String
            let to: String
            let departure: Date
            let arrival: Date
            /// One entry of partner_live's `flights`, or nil where the door answers none for the leg.
            let flight: PartnerLiveAnswer.Flight?
            let path: Path
            /// The speed the estimate, the estimated plane and the ghost fly before the descent.
            let flownSpeedKt: Double
            let moments: [Moment]
            let record: Record?
        }

        struct Label: Decodable {
            let phase: String
            let gapMinutes: Int?
            let label: String?
        }

        struct Gap: Decodable {
            let aheadSeconds: Double
            let gapMinutes: Int
        }

        struct Window: Decodable {
            let name: String
            let departure: Date
            let arrival: Date
            let at: Date
            let flight: PartnerLiveAnswer.Flight?
            let isOpen: Bool
        }

        let constants: Constants
        /// Latitude, longitude.
        let airports: [String: [Double]]
        let plans: [Plan]
        let flights: [Flight]
        let labels: [Label]
        let gaps: [Gap]
        let windows: [Window]

        func coordinate(of code: String) throws -> CLLocationCoordinate2D {
            guard let place = airports[code], place.count == 2 else { throw MissingAirport(code: code) }
            return CLLocationCoordinate2D(latitude: place[0], longitude: place[1])
        }

        /// A flight case as the app's types: its plan, its live data, and the path and record made from them.
        func made(_ flight: Flight) throws -> Made {
            let origin = try coordinate(of: flight.from)
            let destination = try coordinate(of: flight.to)
            let distance = GreatCircle.distance(from: origin, to: destination)
            guard let plan = FlightPlan(departure: flight.departure, arrival: flight.arrival, distance: distance) else {
                throw MissingPlan(name: flight.name)
            }
            let live = flight.flight.map { LiveFlight($0, trail: $0.trail) }
            let path = FlightPath(from: origin, to: destination, flight: live)
            return Made(plan: plan, flight: live, path: path, record: FlightRecord(path: path, plan: plan))
        }
    }

    struct Made {
        let plan: FlightPlan
        let flight: LiveFlight?
        let path: FlightPath
        let record: FlightRecord?
    }

    struct MissingAirport: Error {
        let code: String
    }

    struct MissingPlan: Error {
        let name: String
    }

    /// One nautical mile in meters, for comparing with the cases.
    static let nauticalMile = GreatCircle.metersPerNauticalMile

    static func liveCases() throws -> LiveCases {
        let data = try Data(contentsOf: folder.appending(path: "live-cases.json"))
        let decoder = JSONDecoder()
        // The cases' times have milliseconds, which `.iso8601` doesn't read.
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            return try Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        }
        return try decoder.decode(LiveCases.self, from: data)
    }
}
