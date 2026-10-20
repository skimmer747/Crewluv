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

    /// What the status source does after the move-over's turn.
    enum Next {
        /// This device stays on iCloud.
        case stay
        /// Switch to Crewlu Cloud as `joined` (spec §8.2). `answer` is its read, nil when Crewlu Cloud
        /// couldn't be reached as the share ended (§8.4).
        case switchTo(CrewluCloudDevice.Joined, PartnerViewAnswer?)
        /// The share is gone, and nothing on Crewlu Cloud carries this device on. `leftBehind` when
        /// another of this partner's devices follows this pilot there, so a code from it works here.
        case ended(leftBehind: Bool)
    }

    /// After an iCloud read that brought the record, with this device's ticket in it (spec §8.1): a move
    /// under way, then the ticket, then another of this partner's devices (§8.3). Each switches once
    /// Crewlu Cloud has a status for it.
    func afterRead(ticket: String?) async -> Next {
        let generation = device.generation
        switch await readUnconnectedKey() {
        case .answer(let key, let answer):
            let isMoving = connection.moveToPartnerID != nil
            if case .summary(let summary) = answer.content, isMoving || summary.pilotId == connection.pilotID {
                return switching(to: .init(partnerID: answer.partnerID, key: key, isDeviceKey: true), answer, since: generation)
            }
            // A move waits for the pilot's first summary there. A key a reinstall left for another
            // pilot gives way to the ticket.
            if isMoving {
                return .stay
            }
        case .unavailable:
            return .stay
        case .noKey, .gone:
            break
        }
        if let ticket {
            let joined: CrewluCloudDevice.Joined
            do {
                joined = try await redeemForMove(ticket)
            } catch .refused(.sharingEnded) {
                // The ticket was used, by another of this partner's devices, or it ran out.
                return await followingOtherDevice(since: generation)
            } catch {
                return .stay
            }
            guard let answer = await startMove(joined, since: generation) else { return .stay }
            return switching(to: joined, answer, since: generation)
        }
        return await followingOtherDevice(since: generation)
    }

    /// When the iCloud share is gone (spec §8.4): a move under way switches at once, unless Crewlu
    /// Cloud ended sharing with its key too. Another of this partner's devices is followed before the
    /// welcome screen shows.
    func afterShareGone() async -> Next {
        let generation = device.generation
        if let movingTo = connection.moveToPartnerID {
            switch await readUnconnectedKey() {
            case .answer(let key, let answer):
                return switching(to: .init(partnerID: answer.partnerID, key: key, isDeviceKey: true), answer, since: generation)
            case .unavailable:
                if let key = try? keys.deviceKey() {
                    return switching(to: .init(partnerID: movingTo, key: key, isDeviceKey: true), nil, since: generation)
                }
            case .noKey, .gone:
                break
            }
        }
        switch await followOtherDevice(since: generation) {
        case .nothing, .couldntCheck:
            return .ended(leftBehind: false)
        case .couldntJoin:
            return .ended(leftBehind: true)
        case .joined(let joined, let answer):
            return switching(to: joined, answer, since: generation)
        }
    }

    /// A switch, unless the connection changed since the turn began, say by a join: then this device
    /// stays as that left it.
    private func switching(to joined: CrewluCloudDevice.Joined, _ answer: PartnerViewAnswer?, since generation: Int) -> Next {
        generation == device.generation ? .switchTo(joined, answer) : .stay
    }

    /// The move is under way once a redeem joined (spec §8.1): its read, or nil when it brought no
    /// status yet, or failed. The next read tries again.
    private func startMove(_ joined: CrewluCloudDevice.Joined, since generation: Int) async -> PartnerViewAnswer? {
        guard generation == device.generation else { return nil }
        connection.moveToPartnerID = joined.partnerID
        guard let answer = try? await door.view(key: joined.key, since: nil), case .summary = answer.content else { return nil }
        return answer
    }

    // MARK: - Another of This Partner's Devices

    /// How following another of this partner's devices went (spec §8.3).
    private enum Following {
        /// No hand-off copy, or one of another pilot's, or of a device that's gone.
        case nothing
        /// The copy's pilot couldn't be checked just now.
        case couldntCheck
        /// The copy is this pilot's, but no code or join came of it just now.
        case couldntJoin
        /// This device joined with a code from the other device: the move is under way, with its read.
        case joined(CrewluCloudDevice.Joined, PartnerViewAnswer?)
    }

    /// After an iCloud read: switches once Crewlu Cloud has a status, and otherwise stays.
    private func followingOtherDevice(since generation: Int) async -> Next {
        guard case .joined(let joined, let answer) = await followOtherDevice(since: generation),
              let answer, case .summary = answer.content
        else { return .stay }
        return switching(to: joined, answer, since: generation)
    }

    /// The hand-off copy's device must show the pilot this device follows. Then a code made with the
    /// copy joins this device with its own key: its own device in the pilot's list, with its own
    /// pushes. The copy never reads the status for the screen.
    private func followOtherDevice(since generation: Int) async -> Following {
        guard let copy = try? keys.handOffCopy(), copy != (try? keys.deviceKey()) else { return .nothing }
        do {
            let answer = try await door.view(key: copy, since: nil)
            guard case .summary(let summary) = answer.content, summary.pilotId == connection.pilotID else { return .nothing }
        } catch .refused(.sharingEnded) {
            keys.forgetHandOffCopy()
            return .nothing
        } catch {
            return .couldntCheck
        }
        let code: HandOffCode
        do {
            code = try await door.makeHandOffCode(key: copy)
        } catch .refused(.sharingEnded) {
            keys.forgetHandOffCopy()
            return .nothing
        } catch {
            return .couldntJoin
        }
        guard generation == device.generation, let joined = try? await redeemForMove(code.code),
              generation == device.generation
        else { return .couldntJoin }
        connection.moveToPartnerID = joined.partnerID
        return .joined(joined, try? await door.view(key: joined.key, since: nil))
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
