//
//  PushRegistrarTests.swift
//  CrewluvTests
//
//  This device's push token goes to Crewlu Cloud while it's connected there
//  (partner links piece 4 spec §6.1).
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
final class PushRegistrarTests {
    private let defaultsName = "PushRegistrarTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let door = StandInPartnerDoor()
    private let keys = InMemoryDeviceKeyStore()
    private let log = Log()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: defaultsName))
    }

    deinit {
        defaults.removePersistentDomain(forName: defaultsName)
    }

    /// A registrar for a device on Crewlu Cloud as partner A, or on iCloud.
    private func makeRegistrar(onCrewluCloud: Bool = true) -> (PushRegistrar, PilotStatusSource) {
        if onCrewluCloud {
            defaults.set(Make.partnerA, forKey: "partnerCloud.partnerID")
            keys.key = Make.key
        }
        let source = PilotStatusSource(
            iCloud: StandInICloud(), door: door, keys: keys, defaults: defaults,
            notifier: RecordingNotifier(), iCloudShareEnded: {}
        )
        let registrar = PushRegistrar(
            statusSource: source, door: door, keys: keys,
            environment: { .sandbox }, record: { [log] in log.entries.append($0) }
        )
        return (registrar, source)
    }

    @Test func test_token_goesAsLowerCaseHex_withTheBuildsEnvironment() async {
        let (registrar, _) = makeRegistrar()

        await registrar.didReceive(deviceToken: Data([0x0A, 0xFF, 0x01]))

        #expect(door.pushes.map(\.key) == [Make.key])
        #expect(door.pushes.map(\.token) == ["0aff01"])
        #expect(door.pushes.map(\.environment) == [.sandbox])
        #expect(log.entries == ["Sent (sandbox)"])
    }

    @Test func test_onICloud_nothingIsSent_evenWithAKey() async {
        keys.key = Make.key
        let (registrar, _) = makeRegistrar(onCrewluCloud: false)

        await registrar.didReceive(deviceToken: Data([0x0A]))

        #expect(door.pushes.isEmpty)
        #expect(registrar.token == "0a")
    }

    @Test func test_withoutAToken_nothingIsSent() async {
        let (registrar, _) = makeRegistrar()

        await registrar.register()

        #expect(door.pushes.isEmpty)
    }

    @Test func test_register_sendsTheTokenItAlreadyHas() async {
        let (registrar, _) = makeRegistrar()
        await registrar.didReceive(deviceToken: Data([0x0A]))

        await registrar.register()

        #expect(door.pushes.map(\.token) == ["0a", "0a"])
    }

    @Test func test_unreachable_isTriedAgainOnComingToTheFront() async {
        door.setPushAnswers = [.failure(.unavailable)]
        let (registrar, _) = makeRegistrar()

        await registrar.didReceive(deviceToken: Data([0x0A]))
        #expect(registrar.isOwed)
        await registrar.appBecameActive()

        #expect(door.pushes.count == 2)
        #expect(!registrar.isOwed)
        #expect(log.entries == ["Couldn't reach Crewlu Cloud", "Sent (sandbox)"])
    }

    @Test func test_unreadableKey_isTriedAgainOnComingToTheFront() async {
        let (registrar, source) = makeRegistrar()
        keys.readFails = true

        await registrar.didReceive(deviceToken: Data([0x0A]))
        #expect(registrar.isOwed)
        #expect(door.pushes.isEmpty)
        keys.readFails = false
        await registrar.appBecameActive()

        #expect(door.pushes.map(\.token) == ["0a"])
        #expect(log.entries == ["Couldn't read this device's key", "Sent (sandbox)"])
        #expect(source.isOnCrewluCloud)
    }

    @Test func test_sent_isntSentAgainOnComingToTheFront() async {
        let (registrar, _) = makeRegistrar()

        await registrar.didReceive(deviceToken: Data([0x0A]))
        await registrar.appBecameActive()

        #expect(door.pushes.count == 1)
    }

    @Test func test_sharingEnded_endsSharing() async {
        door.setPushAnswers = [.failure(.refused(.sharingEnded))]
        let (registrar, source) = makeRegistrar()

        await registrar.didReceive(deviceToken: Data([0x0A]))

        #expect(!source.isOnCrewluCloud)
        #expect(keys.key == nil)
        #expect(!registrar.isOwed)
    }

    @Test func test_sharingEnded_forAKeyReplacedMeanwhile_endsNothing() async {
        door.setPushAnswers = [.failure(.refused(.sharingEnded))]
        let (registrar, source) = makeRegistrar()
        door.whileSettingPush = { [keys] in keys.key = "new" }

        await registrar.didReceive(deviceToken: Data([0x0A]))

        #expect(source.isOnCrewluCloud)
        #expect(keys.key == "new")
        #expect(log.entries == ["Sharing ended"])
    }

    @Test func test_sharingEnded_thatDisconnectsOwnLeaveCaused_endsNothing() async {
        door.setPushAnswers = [.failure(.refused(.sharingEnded))]
        defaults.set("Dad", forKey: "partnerCloud.pilotName")
        let (registrar, source) = makeRegistrar()
        door.holdsLeaves = true

        let disconnecting = Task { await source.disconnect() }
        await eventually { door.leaves.count == 1 }
        await registrar.didReceive(deviceToken: Data([0x0A]))
        door.release()

        #expect(await disconnecting.value)
        #expect(source.sharingEndedWith == nil)
        #expect(source.lastUpdate?.outcome == .notConnected)
    }

    @Test func test_refused_isntTriedAgainUntilTheNextLaunch() async {
        door.setPushAnswers = [.failure(.refused(.invalidInput))]
        let (registrar, source) = makeRegistrar()

        await registrar.didReceive(deviceToken: Data([0x0A]))
        await registrar.appBecameActive()

        #expect(door.pushes.count == 1)
        #expect(!registrar.isOwed)
        #expect(source.isOnCrewluCloud)
        #expect(log.entries == ["Refused: invalid_input"])
    }
}

/// What the registrar recorded for the diagnostics.
@MainActor
private final class Log {
    var entries: [String] = []
}
