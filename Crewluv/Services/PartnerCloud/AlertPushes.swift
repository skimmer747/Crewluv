//
//  AlertPushes.swift
//  CrewLuve
//
//  Whether Crewlu Cloud sends this device alert pushes, so the app leaves the alerts to them
//

import CryptoKit
import Foundation

/// Whether Crewlu Cloud sends this device alert pushes (alert pushes spec §6.3): it accepted this device's push
/// registration, which always says it shows them, for the key the device holds now. A new key isn't accepted until
/// its own registration is, and until then the app makes its own alerts.
struct AlertPushes {
    let defaults: UserDefaults
    let keys: DeviceKeyStore

    /// Where the accepted key's fingerprint is kept. The key itself never goes in the defaults.
    static let acceptedKey = "partnerCloud.alertPushesAccepted"

    /// Crewlu Cloud accepted this device's registration for `deviceKey`.
    func accepted(forKey deviceKey: String) {
        defaults.set(Self.fingerprint(deviceKey), forKey: Self.acceptedKey)
    }

    /// Whether they're accepted for the key this device holds now. A key that can't be read counts as not accepted,
    /// so the app goes on making its own alerts.
    var areAccepted: Bool {
        guard let key = try? keys.deviceKey(), let accepted = defaults.string(forKey: Self.acceptedKey) else { return false }
        return accepted == Self.fingerprint(key)
    }

    /// The key's SHA-256, as hex.
    static func fingerprint(_ key: String) -> String {
        SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
