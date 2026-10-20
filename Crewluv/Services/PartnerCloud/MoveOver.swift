//
//  MoveOver.swift
//  CrewLuve
//
//  Moves this device from iCloud to Crewlu Cloud by itself
//

import Foundation

/// Moves this device from iCloud to Crewlu Cloud by itself, once the pilot's CrewLu has moved this
/// partner there (partner links piece 4 spec §8). Nothing shows while it works: a step that fails
/// leaves the device on iCloud, and the next read tries again with the same key.
final class MoveOver {
    private let door: PartnerDoor
    private let keys: DeviceKeyStore
    private let connection: PartnerConnection
    private let device: CrewluCloudDevice
    /// "iPhone" or "iPad": this device's name in the pilot's list.
    private let label: String

    init(door: PartnerDoor, keys: DeviceKeyStore, connection: PartnerConnection, device: CrewluCloudDevice, label: String) {
        self.door = door
        self.keys = keys
        self.connection = connection
        self.device = device
        self.label = label
    }

    // MARK: - This Device's Key, Unconnected

    /// How reading this device's key went while it isn't connected with it: the key of a move under
    /// way, or one a reinstall left (spec §5.3, §8.1).
    enum UnconnectedRead {
        /// No key, or the Keychain couldn't be read just now.
        case noKey
        case answer(key: String, PartnerViewAnswer)
        /// The key's device is gone, so the key, a copy of it and any move under way are forgotten.
        case gone
        /// Crewlu Cloud couldn't be reached, or a switch overtook the read.
        case unavailable
    }

    /// partner_view with this device's key, asking for everything.
    func readUnconnectedKey() async -> UnconnectedRead {
        guard let key = try? keys.deviceKey() else { return .noKey }
        let generation = device.generation
        let answer: PartnerViewAnswer
        do {
            answer = try await door.view(key: key, since: nil)
        } catch .refused(.sharingEnded) {
            guard generation == device.generation else { return .unavailable }
            if (try? keys.handOffCopy()) == key {
                keys.forgetHandOffCopy()
            }
            keys.forgetDeviceKey()
            connection.moveToPartnerID = nil
            return .gone
        } catch {
            return .unavailable
        }
        guard generation == device.generation else { return .unavailable }
        return .answer(key: key, answer)
    }

    /// partner_handoff_redeem for the move-over (spec §8.1, §8.3): a ticket, or a code from another
    /// of this partner's devices, with this device's key, or a new one saved first. A key another
    /// person's device has gets a new one and one more try.
    func redeemForMove(_ token: String) async throws(PartnerDoorError) -> CrewluCloudDevice.Joined {
        let key: String
        do {
            key = try keys.deviceKey() ?? newKey()
        } catch {
            throw .unavailable
        }
        do {
            return try await redeem(token, key: key)
        } catch .refused(.keyInUse) {
            return try await redeem(token, key: newKey())
        }
    }

    private func redeem(_ token: String, key: String) async throws(PartnerDoorError) -> CrewluCloudDevice.Joined {
        let answer = try await door.redeem(code: token, key: key, label: label)
        return CrewluCloudDevice.Joined(partnerID: answer.partnerID, key: key, isDeviceKey: true)
    }

    /// A new key, saved as this device's key before it's sent. Never while this device is connected:
    /// a join that connected it meanwhile keeps its key.
    private func newKey() throws(PartnerDoorError) -> String {
        guard device.partnerID == nil, let key = DeviceKey.make(), keys.save(deviceKey: key) else { throw .unavailable }
        return key
    }
}
