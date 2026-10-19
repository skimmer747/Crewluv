//
//  PushRegistrar.swift
//  CrewLuve
//
//  Sends this device's push token to Crewlu Cloud
//

import Foundation

/// Sends this device's push token to Crewlu Cloud, so a change in the pilot's status wakes it
/// (partner links piece 4 spec §6.1): when iOS gives the token at launch, right after
/// connecting, and on coming to the front when the last try couldn't reach Crewlu Cloud.
final class PushRegistrar {
    static let shared = PushRegistrar()

    /// The token iOS gave in this launch, as lower-case hex.
    private(set) var token: String?
    /// Whether the last registration couldn't reach Crewlu Cloud, so it's tried again.
    private(set) var isOwed = false

    private let statusSource: PilotStatusSource
    private let door: PartnerDoor
    private let keys: DeviceKeyStore
    private let environment: () -> PushEnvironment
    /// Notes how each registration went, for the diagnostics.
    private let record: (String) -> Void

    init(
        statusSource: PilotStatusSource = .shared,
        door: PartnerDoor = LivePartnerDoor(),
        keys: DeviceKeyStore = KeychainDeviceKeyStore(),
        environment: @escaping () -> PushEnvironment = { .current },
        record: @escaping (String) -> Void = { NotificationDiagnostics.shared.recordPushRegistration($0) }
    ) {
        self.statusSource = statusSource
        self.door = door
        self.keys = keys
        self.environment = environment
        self.record = record
    }

    /// iOS gave this device's push token, as it does at every launch.
    func didReceive(deviceToken: Data) async {
        token = deviceToken.map { String(format: "%02x", $0) }.joined()
        await register()
    }

    /// The app came to the front: tries again if the last registration couldn't reach Crewlu Cloud.
    func appBecameActive() async {
        guard isOwed else { return }
        await register()
    }

    /// Sends the token, while this device is on Crewlu Cloud. Connecting calls this too.
    func register() async {
        guard let token, statusSource.isOnCrewluCloud, let key = keys.deviceKey() else { return }
        let environment = environment()
        do {
            try await door.setPush(key: key, token: token, environment: environment)
            isOwed = false
            record("Sent (\(environment.rawValue))")
        } catch .refused(.sharingEnded) {
            isOwed = false
            record("Sharing ended")
            statusSource.endSharing()
        } catch .refused(let refusal) {
            isOwed = false
            record("Refused: \(refusal.rawValue)")
        } catch {
            isOwed = true
            record("Couldn't reach Crewlu Cloud")
        }
    }
}
