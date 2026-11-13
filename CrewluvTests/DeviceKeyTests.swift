//
//  DeviceKeyTests.swift
//  CrewluvTests
//
//  Each device makes its own key (partner-api.md, "The device key").
//

import Foundation
import Testing
@testable import Crewluv

struct DeviceKeyTests {

    @Test func test_make_gives64LowerCaseHexCharacters() throws {
        let key = try #require(DeviceKey.make())

        #expect(key.count == 64)
        #expect(key.allSatisfy { "0123456789abcdef".contains($0) })
    }

    @Test func test_make_givesANewKeyEachTime() throws {
        let keys = try (0..<20).map { _ in try #require(DeviceKey.make()) }

        #expect(Set(keys).count == keys.count)
    }
}
