//
//  CrewluCloudDeviceTests.swift
//  CrewluvTests
//
//  This device on Crewlu Cloud: its key, its partner, and its reads (partner links piece 4 spec §5.1–§5.3)
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
final class CrewluCloudDeviceTests {
    private let defaultsName = "CrewluCloudDeviceTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let door = StandInPartnerDoor()
    private let keys = InMemoryDeviceKeyStore()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: defaultsName))
    }

    deinit {
        defaults.removePersistentDomain(forName: defaultsName)
    }

    /// A device on Crewlu Cloud as partner A.
    private func connectedDevice() -> CrewluCloudDevice {
        defaults.set(Make.partnerA, forKey: "partnerCloud.partnerID")
        keys.key = Make.key
        return CrewluCloudDevice(door: door, keys: keys, connection: PartnerConnection(defaults: defaults))
    }

    // MARK: - Reads the Connection Changed Under

    @Test func test_sharingEnded_forAKeyReplacedMeanwhile_forgetsNothing() async {
        door.viewAnswers = [.failure(.refused(.sharingEnded))]
        door.holdsViews = true
        let device = connectedDevice()

        let read = Task { await device.read() }
        await eventually { door.views.count == 1 }
        device.forget()
        keys.key = "new"
        door.release()

        guard case .superseded = await read.value else {
            Issue.record("expected the read to bring nothing back")
            return
        }
        #expect(keys.key == "new")
    }
}
