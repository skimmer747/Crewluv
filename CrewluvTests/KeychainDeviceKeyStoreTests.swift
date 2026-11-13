//
//  KeychainDeviceKeyStoreTests.swift
//  CrewluvTests
//
//  The device key, the pending key and the hand-off copy in the Keychain (partner links piece 4
//  spec §5.3, §8.3), and the alerts' title name (alert pushes spec §6.2). These run only in Xcode:
//  the Mac harness can't reach the iOS Keychain.
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
        store.forgetPendingKey()
        store.forgetHandOffCopy()
        store.forgetPilotName()
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

    @Test func test_pendingKey_isKeptApartFromTheDeviceKey() throws {
        store.save(deviceKey: "device")
        #expect(store.save(pendingKey: "pending"))
        #expect(try store.deviceKey() == "device")
        #expect(try store.pendingKey() == "pending")

        store.forgetPendingKey()
        #expect(try store.pendingKey() == nil)
        #expect(try store.deviceKey() == "device")
    }

    @Test func test_pendingKey_replacesTheLastOne() throws {
        store.save(pendingKey: "first")
        #expect(store.save(pendingKey: "second"))
        #expect(try store.pendingKey() == "second")
    }

    @Test(arguments: ["deviceKey", "pendingKey"])
    func test_keys_stayOnThisDevice_andCanBeReadWhileLocked(account: String) throws {
        store.save(deviceKey: "device")
        store.save(pendingKey: "pending")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ToddAnderson.Crewluv.partnerCloud.tests",
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        #expect(SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess)
        let attributes = try #require(result as? [String: Any])

        #expect(attributes[kSecAttrAccessible as String] as? String == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        #expect(attributes[kSecAttrSynchronizable as String] as? Bool != true)
    }

    // MARK: - The Pilot's Name

    @Test func test_pilotName_isKeptApartFromTheKey_onThisDeviceOnly_andCanBeForgotten() throws {
        store.save(deviceKey: "device")
        #expect(store.save(pilotName: "Dad"))
        #expect(try store.pilotName() == "Dad")
        #expect(try store.deviceKey() == "device")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ToddAnderson.Crewluv.partnerCloud.tests",
            kSecAttrAccount as String: "pilotName",
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        #expect(SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess)
        let attributes = try #require(result as? [String: Any])
        #expect(attributes[kSecAttrAccessible as String] as? String == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        #expect(attributes[kSecAttrSynchronizable as String] as? Bool != true)

        store.forgetPilotName()
        #expect(try store.pilotName() == nil)
        #expect(try store.deviceKey() == "device")
    }

    // MARK: - The Hand-Off Copy

    @Test func test_handOffCopy_isKeptApartFromTheDeviceKey() throws {
        store.save(deviceKey: "device")
        #expect(store.save(handOffCopy: "copy"))
        #expect(try store.handOffCopy() == "copy")
        #expect(try store.deviceKey() == "device")

        store.forgetHandOffCopy()
        #expect(try store.handOffCopy() == nil)
        #expect(try store.deviceKey() == "device")
    }

    @Test func test_handOffCopy_replacesTheLastOne() throws {
        store.save(handOffCopy: "first")
        #expect(store.save(handOffCopy: "second"))
        #expect(try store.handOffCopy() == "second")
    }

    @Test func test_handOffCopy_syncsThroughICloudKeychain_andCanBeReadWhileLocked() throws {
        store.save(handOffCopy: "copy")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ToddAnderson.Crewluv.partnerCloud.tests",
            kSecAttrAccount as String: "handOffCopy",
            kSecAttrSynchronizable as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        #expect(SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess)
        let attributes = try #require(result as? [String: Any])

        #expect(attributes[kSecAttrAccessible as String] as? String == kSecAttrAccessibleAfterFirstUnlock as String)
        #expect(attributes[kSecAttrSynchronizable as String] as? Bool == true)
    }
}
