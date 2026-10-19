//
//  CrewluCloudDevice.swift
//  CrewLuve
//
//  This device on Crewlu Cloud: its key, its partner, and its reads
//

import Foundation
import Observation

/// This device on Crewlu Cloud: the key it holds, the partner it's a device of, and what its reads
/// send back (partner links piece 4 spec §5.1–§5.3). The status source reads through it, and joining
/// switches it (§7.2).
@Observable
final class CrewluCloudDevice {
    /// This device's partner id on Crewlu Cloud, or nil while it follows its pilot through iCloud.
    private(set) var partnerID: String?

    /// The last answer's `updatedAt`, sent back as `since` within this run of the app. The first read
    /// after a launch sends none, since the app doesn't keep the summary.
    @ObservationIgnored var since: String?

    @ObservationIgnored private let door: PartnerDoor
    @ObservationIgnored private let keys: DeviceKeyStore
    @ObservationIgnored private let connection: PartnerConnection
    /// Goes up each time the connection changes, so a read begun before then brings nothing back.
    @ObservationIgnored private(set) var generation = 0

    init(door: PartnerDoor, keys: DeviceKeyStore, connection: PartnerConnection) {
        self.door = door
        self.keys = keys
        self.connection = connection
        partnerID = connection.partnerID
    }

    /// How a read went.
    enum Read {
        case answer(PartnerViewAnswer)
        /// The Keychain couldn't be read just now. The connection stays: the key is most likely
        /// there, and readable after an unlock.
        case keyUnreadable
        /// The key is gone, so this device is no longer on Crewlu Cloud.
        case keyGone
        /// The pilot stopped sharing with this device, which has forgotten its key and the connection.
        case sharingEnded
        case unavailable
        /// The connection changed while the door answered, so the answer is for one that's gone.
        case superseded
    }

    /// partner_view with this device's key, sending `since` back.
    func read() async -> Read {
        let storedKey: String?
        do {
            storedKey = try keys.deviceKey()
        } catch {
            return .keyUnreadable
        }
        guard let key = storedKey else {
            connection.partnerID = nil
            partnerID = nil
            since = nil
            return .keyGone
        }
        let generation = generation
        let answer: PartnerViewAnswer
        do {
            answer = try await door.view(key: key, since: since)
        } catch .refused(.sharingEnded) {
            // A refusal for a key the connection has since let go of forgets nothing: the key
            // saved now may be a new one.
            guard generation == self.generation else { return .superseded }
            forget()
            return .sharingEnded
        } catch {
            guard generation == self.generation else { return .superseded }
            since = nil
            return .unavailable
        }
        guard generation == self.generation else { return .superseded }
        return .answer(answer)
    }

    /// A key with no connection saved is what a reinstall leaves: iOS keeps an app's Keychain items,
    /// not its settings (spec §5.3). Reads with it, and connects when Crewlu Cloud answers with a
    /// summary, or with none yet on a device without an iCloud share. Nil carries on with iCloud;
    /// it's tried on every refresh until Crewlu Cloud answers, or the Keychain can be read. An
    /// answer that a switch overtook, say a join with the same key, forgets and connects nothing.
    func adoptLeftoverKey() async -> PartnerViewAnswer? {
        guard let key = try? keys.deviceKey() else { return nil }
        let generation = generation
        let answer: PartnerViewAnswer
        do {
            answer = try await door.view(key: key, since: nil)
        } catch .refused(.sharingEnded) {
            if generation == self.generation {
                keys.forgetDeviceKey()
            }
            return nil
        } catch {
            return nil
        }
        guard generation == self.generation else { return nil }
        if case .noSummaryYet = answer.content, connection.hasICloudShare {
            return nil
        }
        self.generation += 1
        connection.partnerID = answer.partnerID
        partnerID = answer.partnerID
        return answer
    }

    // MARK: - Joining

    /// What a join used and got (spec §7.2 steps 1–2).
    struct Joined: Equatable {
        let partnerID: String
        /// The key the join sent: this device's own, or the pending one.
        let key: String
        let isDeviceKey: Bool
    }

    /// Joins with an invite or a code, as `label` in the pilot's list (spec §7.2 steps 1–2): with this
    /// device's key, or else the pending key, saved first, so this device's key changes only when it
    /// switches. A key another person's device has gets the pending key a join that didn't finish
    /// kept, and then, if that one is another person's too, a new one.
    func join(_ link: PartnerLink, label: String) async throws(PartnerDoorError) -> Joined {
        if let deviceKey = try readKey(keys.deviceKey) {
            do {
                return try await join(link, key: deviceKey, label: label, isDeviceKey: true)
            } catch .refused(.keyInUse) {
                // Another person's device has this key: a pending key joins instead.
            }
        }
        do {
            return try await join(link, key: pendingKey(reusingKept: true), label: label, isDeviceKey: false)
        } catch .refused(.keyInUse) {
            return try await join(link, key: pendingKey(reusingKept: false), label: label, isDeviceKey: false)
        }
    }

    /// partner_view with the key that joined, asking for everything, so the joiner can see whose
    /// status it is (spec §7.2 step 3).
    func view(_ joined: Joined) async throws(PartnerDoorError) -> PartnerViewAnswer {
        try await door.view(key: joined.key, since: nil)
    }

    /// The device a switch replaced, which `leave(_:)` lets go.
    struct Replaced: Equatable {
        /// Its key, or nil when the switch kept this device's key.
        let key: String?
    }

    /// Makes this device `joined`'s device (spec §7.2's switching): its key becomes this device's
    /// key, all at once, so no read sees half a switch. A key forgotten since the join sent it, say
    /// by a leftover key's refusal, is saved again. Nil when the key couldn't be saved, and then
    /// nothing changes.
    func switchTo(_ joined: Joined) -> Replaced? {
        let replacedKey = try? keys.deviceKey()
        if replacedKey != joined.key {
            guard keys.save(deviceKey: joined.key) else { return nil }
        }
        if !joined.isDeviceKey {
            keys.forgetPendingKey()
        }
        generation += 1
        connection.partnerID = joined.partnerID
        partnerID = joined.partnerID
        since = nil
        return Replaced(key: replacedKey == joined.key ? nil : replacedKey)
    }

    /// The device a switch replaced leaves Crewlu Cloud, tried once: one that doesn't stays in the
    /// pilot's list, where the pilot can remove it (spec §7.2).
    func leave(_ replaced: Replaced) async {
        guard let key = replaced.key else { return }
        try? await door.leave(key: key)
    }

    /// The partner chose not to switch: the device the join made leaves Crewlu Cloud, tried once, and
    /// its key is forgotten.
    func cancel(_ joined: Joined) async {
        try? await door.leave(key: joined.key)
        if joined.isDeviceKey {
            forget()
        } else {
            keys.forgetPendingKey()
        }
    }

    private func join(_ link: PartnerLink, key: String, label: String, isDeviceKey: Bool) async throws(PartnerDoorError) -> Joined {
        let answer: PartnerJoinAnswer
        switch link {
        case .invite(let invite):
            answer = try await door.join(invite: invite, key: key, label: label)
        case .code(let code):
            answer = try await door.redeem(code: code, key: key, label: label)
        }
        return Joined(partnerID: answer.partnerID, key: key, isDeviceKey: isDeviceKey)
    }

    /// The pending key: the one a join that didn't finish kept, when `reusingKept`, so trying again
    /// gets the same device, or else a new one, saved before it's sent (spec §5.3).
    private func pendingKey(reusingKept: Bool) throws(PartnerDoorError) -> String {
        if reusingKept, let kept = try readKey(keys.pendingKey) {
            return kept
        }
        guard let key = DeviceKey.make(), keys.save(pendingKey: key) else { throw .unavailable }
        return key
    }

    /// A key from the Keychain. One it can't read means the join can't go on.
    private func readKey(_ read: () throws(DeviceKeyUnreadable) -> String?) throws(PartnerDoorError) -> String? {
        do {
            return try read()
        } catch {
            throw .unavailable
        }
    }

    /// partner_handoff_create with this device's key: a code for another of this partner's devices
    /// (spec §7.5). A refusal for a key this device has since let go of, say by switching, ends
    /// nothing: the code is unavailable.
    func makeHandOffCode() async throws(PartnerDoorError) -> HandOffCode {
        guard let key = try? keys.deviceKey() else { throw .unavailable }
        let generation = generation
        do {
            return try await door.makeHandOffCode(key: key)
        } catch .refused(.sharingEnded) where generation != self.generation {
            throw .unavailable
        }
    }

    // MARK: - Leaving and Forgetting

    /// Disconnect (spec §7.5): partner_leave with this device's key, then forgets the key and the
    /// connection. Throws when the door couldn't be reached, and then nothing changes. False when a
    /// join switched this device while the door answered: its new connection stays.
    func leave() async throws(PartnerDoorError) -> Bool {
        let generation = generation
        if let key = try? keys.deviceKey() {
            try await door.leave(key: key)
        }
        guard generation == self.generation else { return false }
        forget()
        return true
    }

    /// Forgets this device's key and its connection.
    func forget() {
        generation += 1
        keys.forgetDeviceKey()
        connection.partnerID = nil
        partnerID = nil
        since = nil
    }
}
