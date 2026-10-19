//
//  DeviceKeyStore.swift
//  CrewLuve
//
//  This device's partner-door key, and where it's kept
//

import Foundation
import Security

/// A device's partner-door key: 32 random bytes as 64 lower-case hex characters, made on the
/// device itself (partner-api.md, "The device key").
nonisolated enum DeviceKey {
    /// A new key, or nil if the system couldn't give random bytes.
    static func make() -> String? {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return nil }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}

/// The Keychain couldn't be read just now, as before the phone's first unlock since it started.
/// That says nothing about whether there's a key.
nonisolated struct DeviceKeyUnreadable: Error, Equatable {
    /// The Keychain's status code.
    let status: OSStatus
}

/// Where this device keeps its partner-door key.
protocol DeviceKeyStore {
    /// This device's key, or nil when it has none.
    func deviceKey() throws(DeviceKeyUnreadable) -> String?
    /// Saves this device's key in place of any other. False if it couldn't be saved.
    @discardableResult func save(deviceKey: String) -> Bool
    func forgetDeviceKey()
}

/// This device's key in the Keychain, as a generic password for this device only. iOS can read it
/// in the background once the phone has been unlocked since it started, so a push at night still
/// finds it. It never syncs, and never moves to another device in a backup.
struct KeychainDeviceKeyStore: DeviceKeyStore {
    static let service = "com.ToddAnderson.Crewluv.partnerCloud"
    private static let account = "deviceKey"

    private let service: String

    init(service: String = Self.service) {
        self.service = service
    }

    /// Nil when the Keychain has no key for this device, or holds one that isn't text, which can't
    /// be used and which the next save replaces. Any other failure throws.
    func deviceKey() throws(DeviceKeyUnreadable) -> String? {
        var query = item
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            debugLog("[DeviceKey] The key couldn't be read: OSStatus \(status)")
            throw DeviceKeyUnreadable(status: status)
        }
        guard let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            debugLog("[DeviceKey] The Keychain holds a key that isn't text")
            return nil
        }
        return key
    }

    @discardableResult
    func save(deviceKey: String) -> Bool {
        let data = Data(deviceKey.utf8)
        let updated = SecItemUpdate(item as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard updated == errSecItemNotFound else { return updated == errSecSuccess }
        var newItem = item
        newItem[kSecValueData as String] = data
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(newItem as CFDictionary, nil) == errSecSuccess
    }

    func forgetDeviceKey() {
        SecItemDelete(item as CFDictionary)
    }

    private var item: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.account,
        ]
    }
}
