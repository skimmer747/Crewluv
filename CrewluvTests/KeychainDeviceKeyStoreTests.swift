//
//  KeychainDeviceKeyStoreTests.swift
//  CrewluvTests
//
//  The device key in the Keychain (partner links piece 4 spec §5.3). These run only in
//  Xcode: the Mac harness can't reach the iOS Keychain.
//

import Foundation
import Security
import Testing
@testable import Crewluv

@MainActor
@Suite(.serialized)
struct KeychainDeviceKeyStoreTests {
    /// Its own service, so the tests never touch the app's key.
    private let store = KeychainDeviceKeyStore(service: "com.ToddAnderson.Crewluv.partnerCloud.tests")

    init() {
        store.forgetDeviceKey()
    }

    @Test func test_noKey_readsNil() throws {
        #expect(try store.deviceKey() == nil)
    }

    @Test func test_save_thenRead() throws {
        #expect(store.save(deviceKey: "first"))
        #expect(try store.deviceKey() == "first")
    }

    @Test func test_save_replacesTheKey() throws {
        store.save(deviceKey: "first")
        #expect(store.save(deviceKey: "second"))
        #expect(try store.deviceKey() == "second")
    }

    @Test func test_forget_leavesNoKey() throws {
        store.save(deviceKey: "first")
        store.forgetDeviceKey()
        #expect(try store.deviceKey() == nil)
    }

    @Test func test_aKeyThatIsntText_readsNil() throws {
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ToddAnderson.Crewluv.partnerCloud.tests",
            kSecAttrAccount as String: "deviceKey",
            kSecValueData as String: Data([0xFF, 0xFE]),
        ]
        #expect(SecItemAdd(item as CFDictionary, nil) == errSecSuccess)

        #expect(try store.deviceKey() == nil)
    }

    @Test func test_key_staysOnThisDevice_andCanBeReadWhileLocked() throws {
        store.save(deviceKey: "first")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ToddAnderson.Crewluv.partnerCloud.tests",
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        #expect(SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess)
        let attributes = try #require(result as? [String: Any])

        #expect(attributes[kSecAttrAccessible as String] as? String == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        #expect(attributes[kSecAttrSynchronizable as String] as? Bool != true)
    }
}
