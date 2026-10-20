//
//  PartnerConnection.swift
//  CrewLuve
//
//  How this device follows its pilot, as kept in its settings
//

import Foundation

/// How this device follows its pilot, as kept in its settings: through Crewlu Cloud once it has a
/// partner id there, and through iCloud otherwise, which decides by its own settings as before. With
/// the pilot of the last status seen (spec §5.1).
struct PartnerConnection {
    static let partnerIDKey = "partnerCloud.partnerID"
    static let pilotIDKey = "partnerCloud.pilotID"
    static let pilotNameKey = "partnerCloud.pilotName"
    static let sharingEndedWithKey = "partnerCloud.sharingEndedWith"
    static let leftICloudKey = "partnerCloud.leftICloud"
    static let moveToPartnerIDKey = "partnerCloud.moveToPartnerID"
    /// Where the alerts' title name is kept, as before.
    static let displayNameKey = "ResolvedPilotDisplayName"

    let defaults: UserDefaults

    /// This device's partner id on Crewlu Cloud, or nil while it follows its pilot through iCloud.
    var partnerID: String? {
        get { defaults.string(forKey: Self.partnerIDKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.partnerIDKey) }
    }

    /// A move under way (spec §8.1): the partner id that redeeming a ticket or a code gave this
    /// device's key, while this device still follows its pilot through iCloud.
    var moveToPartnerID: String? {
        get { defaults.string(forKey: Self.moveToPartnerIDKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.moveToPartnerIDKey) }
    }

    /// The pilot of the last status seen, to tell whether a link is from another pilot (spec §7.2).
    var pilotID: String? {
        get { defaults.string(forKey: Self.pilotIDKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.pilotIDKey) }
    }

    /// That pilot's name as this partner sees them: the nickname the pilot set, or their first name.
    var pilotName: String? {
        get { defaults.string(forKey: Self.pilotNameKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.pilotNameKey) }
    }

    /// The pilot whose sharing with this device ended, for the welcome screen's note (spec §7.6).
    var sharingEndedWith: String? {
        get { defaults.string(forKey: Self.sharingEndedWithKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.sharingEndedWithKey) }
    }

    /// The name the alerts' titles use: the nickname the pilot set for this partner, if any.
    var savedDisplayName: String? {
        get { defaults.string(forKey: Self.displayNameKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.displayNameKey) }
    }

    /// Remembers the pilot of a new reading (spec §5.1), and gives the name to title the alerts with:
    /// the nickname the pilot set for this partner, kept while an iCloud read can't look it up. A
    /// status means a connection, so a note that sharing ended goes.
    func remember(_ reading: PilotReading) -> String? {
        if reading.isDisplayNameKnown {
            savedDisplayName = reading.displayName
        }
        let name = savedDisplayName
        let status = reading.status(at: Date())
        pilotID = status.pilotId
        pilotName = name ?? status.pilotFirstName
        sharingEndedWith = nil
        return name
    }

    /// Forgets the pilot: their id and name, and what the alerts keep of them, which is the title
    /// name, what they compare against and when they last looked, as today's iCloud reset does.
    func forgetPilot() {
        let keys = [Self.pilotIDKey, Self.pilotNameKey, Self.displayNameKey, "LastSeenPilotSnapshot", "LastEvaluatedPilotStatusTimestamp"]
        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }

    /// Whether an iCloud share was accepted, or Crewluve runs on the pilot's own iCloud.
    var hasICloudShare: Bool {
        defaults.string(forKey: "SharedZoneOwner") != nil || defaults.string(forKey: "PilotDataSource") == "privateDB"
    }

    /// Whether this device let iCloud go, by connecting to Crewlu Cloud or by Disconnect, so the
    /// launch doesn't find its iCloud share again (spec §7.5). Accepting a share brings iCloud back.
    var hasLeftICloud: Bool {
        get { defaults.bool(forKey: Self.leftICloudKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.leftICloudKey) }
    }

    /// Lets iCloud go: an iCloud share is forgotten with `forgetShare`, and not found again.
    func leaveICloud(forgetShare: () -> Void) {
        hasLeftICloud = true
        if hasICloudShare {
            forgetShare()
        }
    }
}
