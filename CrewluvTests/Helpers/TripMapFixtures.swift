//
//  TripMapFixtures.swift
//  CrewluvTests
//
//  Reads Fixtures/TripMap: the trip map's shared cases, which the website runs too (moving map spec §15.1).
//

import Foundation

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
}
