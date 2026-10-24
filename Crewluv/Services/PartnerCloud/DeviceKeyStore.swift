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

/// Where this device keeps its partner-door key, the key it joins with until it's connected
/// (spec §5.3), the hand-off copy (§8.3), and the alerts' title name (alert pushes spec §6.2).
protocol DeviceKeyStore {
    /// This device's key, or nil when it has none.
    func deviceKey() throws(DeviceKeyUnreadable) -> String?
    /// Saves this device's key in place of any other. False if it couldn't be saved.
    @discardableResult func save(deviceKey: String) -> Bool
    func forgetDeviceKey()

    /// The key a join used while this device isn't connected with it yet, or nil when there's none.
    func pendingKey() throws(DeviceKeyUnreadable) -> String?
    /// Saves the pending key in place of any other. False if it couldn't be saved.
    @discardableResult func save(pendingKey: String) -> Bool
    func forgetPendingKey()

    /// The hand-off copy: the key of this partner's device that moved to Crewlu Cloud most recently,
    /// which their other devices read to follow it there (spec §8.3). Nil when there's none.
    func handOffCopy() throws(DeviceKeyUnreadable) -> String?
    /// Saves the hand-off copy in place of any other. False if it couldn't be saved.
    @discardableResult func save(handOffCopy: String) -> Bool
    func forgetHandOffCopy()

    /// The name the alerts are titled with, kept beside the key for the alert pushes' helper, which titles its plain
    /// lines with it (alert pushes spec §6.2). Nil when there's none.
    func pilotName() throws(DeviceKeyUnreadable) -> String?
    /// Saves the name in place of any other. False if it couldn't be saved.
    @discardableResult func save(pilotName: String) -> Bool
    func forgetPilotName()
}

/// The keys in the Keychain, each as a generic password that iOS can read in the background once the
/// phone has been unlocked since it started, so a push at night still finds them. This device's key,
/// the pending key and the pilot's name are for this device only: they never sync, and never move to
/// another device in a backup. The hand-off copy syncs through iCloud Keychain, which only Crewluve on this partner's
/// own devices can read, encrypted end to end (spec §8.3).
struct KeychainDeviceKeyStore: DeviceKeyStore {
    static let service = "com.ToddAnderson.Crewluv.partnerCloud"

    /// Where each key is kept.
    private enum Slot: String {
        case device = "deviceKey"
        case pending = "pendingKey"
        case handOffCopy
        case pilotName

        var syncs: Bool { self == .handOffCopy }
    }

    private let service: String

    init(service: String = Self.service) {
        self.service = service
    }

    func deviceKey() throws(DeviceKeyUnreadable) -> String? {
        try key(in: .device)
    }

    @discardableResult
    func save(deviceKey: String) -> Bool {
        save(deviceKey, in: .device)
    }

    func forgetDeviceKey() {
        SecItemDelete(item(.device) as CFDictionary)
    }

    func pendingKey() throws(DeviceKeyUnreadable) -> String? {
        try key(in: .pending)
    }

    @discardableResult
    func save(pendingKey: String) -> Bool {
        save(pendingKey, in: .pending)
    }

    func forgetPendingKey() {
        SecItemDelete(item(.pending) as CFDictionary)
    }

    func handOffCopy() throws(DeviceKeyUnreadable) -> String? {
        try key(in: .handOffCopy)
    }

    @discardableResult
    func save(handOffCopy: String) -> Bool {
        save(handOffCopy, in: .handOffCopy)
    }

    func forgetHandOffCopy() {
        SecItemDelete(item(.handOffCopy) as CFDictionary)
    }

    func pilotName() throws(DeviceKeyUnreadable) -> String? {
        try key(in: .pilotName)
    }

    @discardableResult
    func save(pilotName: String) -> Bool {
        save(pilotName, in: .pilotName)
    }

    func forgetPilotName() {
        SecItemDelete(item(.pilotName) as CFDictionary)
    }

    /// Nil when the Keychain has no key in `slot`, or holds one that isn't text, which can't be used
    /// and which the next save replaces. Any other failure throws.
    private func key(in slot: Slot) throws(DeviceKeyUnreadable) -> String? {
        var query = item(slot)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            debugLog("[DeviceKey] The \(slot.rawValue) couldn't be read: OSStatus \(status)")
            throw DeviceKeyUnreadable(status: status)
        }
        guard let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            debugLog("[DeviceKey] The Keychain holds a \(slot.rawValue) that isn't text")
            return nil
        }
        return key
    }

    private func save(_ key: String, in slot: Slot) -> Bool {
        let data = Data(key.utf8)
        let updated = SecItemUpdate(item(slot) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard updated == errSecItemNotFound else { return updated == errSecSuccess }
        var newItem = item(slot)
        newItem[kSecValueData as String] = data
        newItem[kSecAttrAccessible as String] = slot.syncs
            ? kSecAttrAccessibleAfterFirstUnlock
            : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(newItem as CFDictionary, nil) == errSecSuccess
    }

    /// A synced item is found, changed and deleted only when the query says it syncs.
    private func item(_ slot: Slot) -> [String: Any] {
        var item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: slot.rawValue,
        ]
        if slot.syncs {
            item[kSecAttrSynchronizable as String] = true
        }
        return item
    }
}
