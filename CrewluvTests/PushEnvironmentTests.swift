//
//  PushEnvironmentTests.swift
//  CrewluvTests
//
//  A push token's environment follows the build's provisioning profile, not Debug or
//  Release (partner-api.md, "Pushes"; partner links piece 4 spec §6.1).
//

import Foundation
import Testing
@testable import Crewluv

struct PushEnvironmentTests {

    /// A provisioning profile as Xcode embeds it: signed data with the profile's plist inside.
    private func profile(apsEnvironment: String?) throws -> Data {
        var entitlements: [String: Any] = ["application-identifier": "UV96Z83C7B.com.ToddAnderson.Crewluv"]
        entitlements["aps-environment"] = apsEnvironment
        let plist = try PropertyListSerialization.data(
            fromPropertyList: ["Name": "Crewluv Development", "Entitlements": entitlements],
            format: .xml,
            options: 0
        )
        return Data([0x30, 0x82, 0x4E, 0x1F, 0x06, 0x09]) + plist + Data([0xA0, 0x82, 0x0D, 0x3C])
    }

    @Test func test_developmentProfile_isSandbox() throws {
        #expect(PushEnvironment.from(provisioningProfile: try profile(apsEnvironment: "development")) == .sandbox)
    }

    @Test func test_adHocProfile_isProduction() throws {
        #expect(PushEnvironment.from(provisioningProfile: try profile(apsEnvironment: "production")) == .production)
    }

    @Test func test_noProfile_asOnTestFlightAndTheAppStore_isProduction() {
        #expect(PushEnvironment.from(provisioningProfile: nil) == .production)
    }

    @Test func test_profileWithoutPushes_isSandbox() throws {
        #expect(PushEnvironment.from(provisioningProfile: try profile(apsEnvironment: nil)) == .sandbox)
    }

    @Test func test_unreadableProfile_isSandbox() {
        #expect(PushEnvironment.from(provisioningProfile: Data("not a profile".utf8)) == .sandbox)
    }

    @Test func test_rawValues_areWhatTheDoorTakes() {
        #expect(PushEnvironment.sandbox.rawValue == "sandbox")
        #expect(PushEnvironment.production.rawValue == "production")
    }
}
