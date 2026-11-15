//
//  TripMapFixtures.swift
//  CrewluvTests
//
//  Reads Fixtures/TripMap: the trip map's shared cases, which the website runs too (moving map spec §15.1).
//

import Foundation
@testable import Crewluv

enum TripMapFixtures {

    /// Found beside this file on the Mac's disk, which tests on a simulator can read.
    static let folder = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/TripMap")

    struct ProgressCases: Decodable {
        struct Constants: Decodable {
            let taxiOutMinutes: Double
            let taxiInMinutes: Double
            let shortestCruiseMinutes: Double
        }

        struct ScheduleCase: Decodable {
            let name: String
            let departure: Date
            let arrival: Date
            let at: Date
            let fraction: Double
        }

        let constants: Constants
        let scheduleCases: [ScheduleCase]
    }

    static func progressCases() throws -> ProgressCases {
        let data = try Data(contentsOf: folder.appending(path: "progress-cases.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProgressCases.self, from: data)
    }

    // MARK: - The facts (Stage 2 spec §12.1)

    struct FactsCases: Decodable {
        struct Constants: Decodable {
            let cockpitHorizonDegrees: Double
            let milestoneMinutes: Double
            let sunHeadlineMinutes: Double
            let sampleMiles: Double
            let holdMiles: Double
            let homeRadiusMiles: Double
            let cityRadiusMiles: Double
            let coastSnapMiles: Double
            let weatherHours: Double
        }

        struct Comparison: Decodable {
            let miles: Double
            let phrase: String?
        }

        struct PlaceCase: Decodable {
            let lat: Double
            let lon: Double
            let place: String
            let kind: String
            let country: String?
        }

        struct CityCase: Decodable {
            let lat: Double
            let lon: Double
            let city: String?
        }

        struct Story: Decodable {
            struct Expected: Decodable {
                let kind: String
                let name: String?
                let miles: Int?
                let time: Date
            }

            let name: String
            /// Latitude, longitude.
            let from: [Double]
            let to: [Double]
            let departure: Date
            let arrival: Date
            let home: [Double]?
            let milestones: [Expected]
        }

        struct Headline: Decodable {
            let story: String
            let at: Date
            let text: String
        }

        struct SunCase: Decodable {
            struct Expected: Decodable {
                let kind: String
                let time: Date
                let peopleBelowMinutes: Double?
            }

            let name: String
            let from: [Double]
            let to: [Double]
            let departure: Date
            let arrival: Date
            let events: [Expected]
        }

        struct MoonPhaseCase: Decodable {
            let at: Date
            let phase: String
        }

        struct MoonUpCase: Decodable {
            let lat: Double
            let lon: Double
            let at: Date
            let isUp: Bool
        }

        struct GroundSunCase: Decodable {
            let lat: Double
            let lon: Double
            let after: Date
            let kind: String
            let time: Date
        }

        struct TotalsCase: Decodable {
            struct Leg: Decodable {
                let id: String
                let from: String
                let to: String
                let departure: Date
                let arrival: Date
                let fromZone: String
                let toZone: String
            }

            let airports: [String: [Double]]
            let home: String
            let legs: [Leg]
            let cities: Int
            let miles: Int
            let timeZones: Int
            let cockpitSunsets: Int
        }

        let constants: Constants
        let comparisons: [Comparison]
        let places: [PlaceCase]
        let cities: [CityCase]
        let testGeography: Geography
        let stories: [Story]
        let headlines: [Headline]
        let sunEvents: [SunCase]
        let moonPhases: [MoonPhaseCase]
        let moonUp: [MoonUpCase]
        let groundSun: [GroundSunCase]
        let totals: TotalsCase
    }

    static func factsCases() throws -> FactsCases {
        let data = try Data(contentsOf: folder.appending(path: "facts-cases.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FactsCases.self, from: data)
    }

    // MARK: - The replay's pace (activity markers design §3.2, §4.1, §5)

    struct ReplayCases: Decodable {
        struct Constants: Decodable {
            let baseRate: Double
            let legMinimumSeconds: Double
            let waitMinimumSeconds: Double
            let quickWaitRate: Double
        }

        struct Stretch: Decodable {
            let start: Date
            let end: Date

            var clockStretch: TripReplayClock.Stretch { TripReplayClock.Stretch(start: start, end: end) }
        }

        struct Check: Decodable {
            /// Real seconds after pressing play, at the case's speed.
            let seconds: Double
            let at: Date
        }

        struct Case: Decodable {
            let name: String
            let note: String
            let span: Stretch
            let legs: [Stretch]
            let waits: [Stretch]
            let quickLayovers: Bool
            let speed: Int
            /// The whole replay at 1x, in seconds.
            let replayLength: Double
            let checks: [Check]
        }

        struct WaitLabel: Decodable {
            let hours: Double
            let label: String?
            let note: String
        }

        let constants: Constants
        let cases: [Case]
        let waitLabels: [WaitLabel]
    }

    static func replayCases() throws -> ReplayCases {
        let data = try Data(contentsOf: folder.appending(path: "replay-cases.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ReplayCases.self, from: data)
    }

    // MARK: - What the pilot is doing (activity markers design §2.2, §4.2, §5)

    struct ActivityCases: Decodable {
        struct Constants: Decodable {
            let shortestLayoverHours: Double
        }

        struct Airport: Decodable {
            let lat: Double
            let lon: Double
            let city: String?
        }

        enum Mode: String, Decodable {
            case trip, nextTrip, recap
        }

        /// Where a next trip's pilot waits for it.
        enum Place: String, Decodable {
            case home, base
        }

        struct Leg: Decodable {
            let id: String
            let type: TripLeg.LegType
            /// A flight's or a drive's airports.
            let from: String?
            let to: String?
            /// A ground leg's airport.
            let airport: String?
            let start: Date
            let end: Date
            let delayMinutes: Int?
        }

        struct Moment: Decodable {
            let at: Date
            /// `TripActivity.Kind`'s raw value.
            let kind: String
            let words: String
            let note: String
        }

        struct Trip: Decodable {
            let name: String
            let note: String
            let home: String
            /// The base airport, when the case gives one.
            let base: String?
            let mode: Mode
            /// Where a next trip's pilot waits: home when the case leaves it out.
            let waitingAt: Place?
            let legs: [Leg]
            let moments: [Moment]
        }

        let constants: Constants
        let airports: [String: Airport]
        let trips: [Trip]
    }

    static func activityCases() throws -> ActivityCases {
        let data = try Data(contentsOf: folder.appending(path: "activity-cases.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ActivityCases.self, from: data)
    }
}
