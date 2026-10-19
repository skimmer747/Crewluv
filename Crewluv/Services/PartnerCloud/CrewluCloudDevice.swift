//
//  CrewluCloudDevice.swift
//  CrewLuve
//
//  This device on Crewlu Cloud: its key, its partner, and its reads
//

import Foundation
import Observation

/// This device on Crewlu Cloud: the key it holds, the partner it's a device of, and what its reads
/// send back (partner links piece 4 spec §5.1–§5.3). The status source reads through it.
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
    @ObservationIgnored private var generation = 0

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
    /// it's tried on every refresh until Crewlu Cloud answers, or the Keychain can be read.
    func adoptLeftoverKey() async -> PartnerViewAnswer? {
        guard let key = try? keys.deviceKey() else { return nil }
        let answer: PartnerViewAnswer
        do {
            answer = try await door.view(key: key, since: nil)
        } catch .refused(.sharingEnded) {
            keys.forgetDeviceKey()
            return nil
        } catch {
            return nil
        }
        if case .noSummaryYet = answer.content, connection.hasICloudShare {
            return nil
        }
        connection.partnerID = answer.partnerID
        partnerID = answer.partnerID
        return answer
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
