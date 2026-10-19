//
//  PartnerConnection.swift
//  CrewLuve
//
//  How this device follows its pilot, as kept in its settings
//

import Foundation

/// How this device follows its pilot, as kept in its settings: through Crewlu Cloud once it has a
/// partner id there, and through iCloud otherwise, which decides by its own settings as before.
struct PartnerConnection {
    static let partnerIDKey = "partnerCloud.partnerID"

    let defaults: UserDefaults

    /// This device's partner id on Crewlu Cloud, or nil while it follows its pilot through iCloud.
    var partnerID: String? {
        get { defaults.string(forKey: Self.partnerIDKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.partnerIDKey) }
    }

    /// Whether an iCloud share was accepted, or Crewluve runs on the pilot's own iCloud.
    var hasICloudShare: Bool {
        defaults.string(forKey: "SharedZoneOwner") != nil || defaults.string(forKey: "PilotDataSource") == "privateDB"
    }
}
