//
//  PilotDisplayStatusTests.swift
//  CrewluvTests
//
//  Round-trip and grouping coverage for the PilotDisplayStatus enum bridge.
//

import Testing
import Foundation
@testable import Crewluv

struct PilotDisplayStatusTests {

    // MARK: - String Bridge

    @Test func test_init_fromKnownString_mapsToCase() {
        #expect(PilotDisplayStatus(rawDisplayString: "Home") == .home)
        #expect(PilotDisplayStatus(rawDisplayString: "Base") == .base)
        #expect(PilotDisplayStatus(rawDisplayString: "Commuting Home") == .commutingHome)
        #expect(PilotDisplayStatus(rawDisplayString: "In Flight") == .inFlight)
        #expect(PilotDisplayStatus(rawDisplayString: "Turn") == .turn)
        #expect(PilotDisplayStatus(rawDisplayString: "Layover") == .layover)
        #expect(PilotDisplayStatus(rawDisplayString: "Reserve") == .reserve)
        #expect(PilotDisplayStatus(rawDisplayString: "Hot Standby") == .hotStandby)
        #expect(PilotDisplayStatus(rawDisplayString: "Training") == .training)
        #expect(PilotDisplayStatus(rawDisplayString: "Off") == .elsewhere(city: nil))
    }

    @Test func test_init_fromUnknownString_preservesAsUnknown() {
        let exotic = "PilotInLimbo"
        let status = PilotDisplayStatus(rawDisplayString: exotic)
        #expect(status == .unknown(exotic))
        #expect(status.rawDisplayString == exotic)
    }

    @Test func test_rawDisplayString_roundTripsKnownCases() {
        let cases: [PilotDisplayStatus] = [
            .home, .base, .commutingHome, .inFlight, .turn,
            .layover, .reserve, .hotStandby, .training
        ]
        for status in cases {
            let raw = status.rawDisplayString
            #expect(PilotDisplayStatus(rawDisplayString: raw) == status,
                    "Round-trip failed for \(raw)")
        }
    }

    // MARK: - Semantic Groups

    @Test func test_isSettled_homeAndBase_areTrue() {
        #expect(PilotDisplayStatus.home.isSettled)
        #expect(PilotDisplayStatus.base.isSettled)
    }

    @Test func test_isSettled_others_areFalse() {
        #expect(!PilotDisplayStatus.inFlight.isSettled)
        #expect(!PilotDisplayStatus.turn.isSettled)
        #expect(!PilotDisplayStatus.layover.isSettled)
        #expect(!PilotDisplayStatus.commutingHome.isSettled)
        #expect(!PilotDisplayStatus.reserve.isSettled)
        #expect(!PilotDisplayStatus.hotStandby.isSettled)
        #expect(!PilotDisplayStatus.training.isSettled)
        #expect(!PilotDisplayStatus.elsewhere(city: "Dallas").isSettled)
        #expect(!PilotDisplayStatus.unknown("X").isSettled)
    }

    @Test func test_isLayoverLike_layoverAndBase_areTrue() {
        #expect(PilotDisplayStatus.layover.isLayoverLike)
        #expect(PilotDisplayStatus.base.isLayoverLike)
        #expect(!PilotDisplayStatus.home.isLayoverLike)
        #expect(!PilotDisplayStatus.turn.isLayoverLike)
    }

    @Test func test_isDutyPeriod_reserveHotStandbyTraining_areTrue() {
        #expect(PilotDisplayStatus.reserve.isDutyPeriod)
        #expect(PilotDisplayStatus.hotStandby.isDutyPeriod)
        #expect(PilotDisplayStatus.training.isDutyPeriod)
        #expect(!PilotDisplayStatus.home.isDutyPeriod)
        #expect(!PilotDisplayStatus.layover.isDutyPeriod)
    }

    // MARK: - Codable

    @Test func test_codable_encodesAsSingleValueString() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(PilotDisplayStatus.layover)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json == "\"Layover\"")
    }

    @Test func test_codable_decodesFromSingleValueString() throws {
        let decoder = JSONDecoder()
        let data = "\"In Flight\"".data(using: .utf8)!
        let status = try decoder.decode(PilotDisplayStatus.self, from: data)
        #expect(status == .inFlight)
    }

    @Test func test_codable_unknownStringRoundTrips() throws {
        let exotic = "MartianHoliday"
        let original = PilotDisplayStatus.unknown(exotic)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PilotDisplayStatus.self, from: data)
        #expect(decoded == original)
        #expect(decoded.rawDisplayString == exotic)
    }
}
