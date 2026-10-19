//
//  PartnerCloudStandIns.swift
//  CrewluvTests
//
//  Stand-ins for Crewlu Cloud, iCloud, the Keychain and the alerts, and statuses made
//  from a few fields
//

import Foundation
import Security
import Testing
@testable import Crewluv

/// The partner door, answering from a script and recording each call.
@MainActor
final class StandInPartnerDoor: PartnerDoor {
    /// The answers to `view`, in order. With none left, the door can't be reached.
    var viewAnswers: [Result<PartnerViewAnswer, PartnerDoorError>] = []
    /// The answers to `setPush`, in order. With none left, it says ok.
    var setPushAnswers: [Result<Void, PartnerDoorError>] = []
    /// The answers to `join` and `redeem`, in order. With none left, the door can't be reached.
    var joinAnswers: [Result<PartnerJoinAnswer, PartnerDoorError>] = []
    /// The answers to `makeHandOffCode`, in order. With none left, the door can't be reached.
    var handOffAnswers: [Result<HandOffCode, PartnerDoorError>] = []
    /// The answers to `leave`, in order. With none left, it says ok.
    var leaveAnswers: [Result<Void, PartnerDoorError>] = []
    /// While true, each `view` waits for `release()`.
    var holdsViews = false
    /// While true, each `leave` waits for `release()`.
    var holdsLeaves = false
    /// While true, each `makeHandOffCode` waits for `release()`.
    var holdsHandOffs = false
    /// Runs while `setPush` waits for its answer, as if something happened meanwhile.
    var whileSettingPush: (() -> Void)?

    private(set) var views: [(key: String, since: String?)] = []
    private(set) var pushes: [(key: String, token: String, environment: PushEnvironment)] = []
    /// Each join and redeem: what it joined with, and the key and label it sent.
    private(set) var joins: [(link: PartnerLink, key: String, label: String)] = []
    private(set) var handOffs: [String] = []
    private(set) var leaves: [String] = []
    private var held: [CheckedContinuation<Void, Never>] = []

    func view(key: String, since: String?) async throws(PartnerDoorError) -> PartnerViewAnswer {
        views.append((key, since))
        if holdsViews {
            await withCheckedContinuation { held.append($0) }
        }
        guard !viewAnswers.isEmpty else { throw .unavailable }
        return try viewAnswers.removeFirst().get()
    }

    func setPush(key: String, token: String, environment: PushEnvironment) async throws(PartnerDoorError) {
        pushes.append((key, token, environment))
        whileSettingPush?()
        guard !setPushAnswers.isEmpty else { return }
        try setPushAnswers.removeFirst().get()
    }

    func join(invite: String, key: String, label: String) async throws(PartnerDoorError) -> PartnerJoinAnswer {
        joins.append((.invite(invite), key, label))
        return try nextJoinAnswer()
    }

    func redeem(code: String, key: String, label: String) async throws(PartnerDoorError) -> PartnerJoinAnswer {
        joins.append((.code(code), key, label))
        return try nextJoinAnswer()
    }

    func makeHandOffCode(key: String) async throws(PartnerDoorError) -> HandOffCode {
        handOffs.append(key)
        if holdsHandOffs {
            await withCheckedContinuation { held.append($0) }
        }
        guard !handOffAnswers.isEmpty else { throw .unavailable }
        return try handOffAnswers.removeFirst().get()
    }

    func leave(key: String) async throws(PartnerDoorError) {
        leaves.append(key)
        if holdsLeaves {
            await withCheckedContinuation { held.append($0) }
        }
        guard !leaveAnswers.isEmpty else { return }
        try leaveAnswers.removeFirst().get()
    }

    private func nextJoinAnswer() throws(PartnerDoorError) -> PartnerJoinAnswer {
        guard !joinAnswers.isEmpty else { throw .unavailable }
        return try joinAnswers.removeFirst().get()
    }

    /// Lets every held call go on.
    func release() {
        held.forEach { $0.resume() }
        held.removeAll()
    }
}

/// iCloud, answering from a script and counting reads.
@MainActor
final class StandInICloud: ICloudStatusFetching {
    /// The reads' results, in order. With none left, there's no share.
    var results: [Result<ICloudReading, any Error>] = []
    private(set) var fetches = 0

    func fetch() async throws -> ICloudReading {
        fetches += 1
        guard !results.isEmpty else { throw ICloudFetchError.notConnected }
        return try results.removeFirst().get()
    }
}

/// The Keychain, in memory.
@MainActor
final class InMemoryDeviceKeyStore: DeviceKeyStore {
    var key: String?
    var pending: String?
    /// While true, reading a key fails, as the Keychain's does before the phone's first unlock.
    var readFails = false
    /// While true, saving a key fails.
    var savesFail = false

    func deviceKey() throws(DeviceKeyUnreadable) -> String? {
        if readFails {
            throw DeviceKeyUnreadable(status: errSecInteractionNotAllowed)
        }
        return key
    }

    func save(deviceKey: String) -> Bool {
        guard !savesFail else { return false }
        key = deviceKey
        return true
    }

    func forgetDeviceKey() {
        key = nil
    }

    func pendingKey() throws(DeviceKeyUnreadable) -> String? {
        if readFails {
            throw DeviceKeyUnreadable(status: errSecInteractionNotAllowed)
        }
        return pending
    }

    func save(pendingKey: String) -> Bool {
        guard !savesFail else { return false }
        pending = pendingKey
        return true
    }

    func forgetPendingKey() {
        pending = nil
    }
}

/// The alerts, recording what they're handed.
actor RecordingNotifier {
    private(set) var evaluations: [(status: SharedPilotStatus, pilotName: String)] = []

    func evaluateChanges(
        old: SharedPilotStatus?,
        new: SharedPilotStatus,
        pilotName: String,
        newEffectiveDelay: Int?,
        resolvedHomeArrivalTime: Date?
    ) {
        evaluations.append((new, pilotName))
    }
}

// In an extension, not on the actor: declared on the actor, the conformance to a `nonisolated`
// protocol can make Swift infer `nonisolated` for the whole actor, depending on the order the
// files compile in, and then reject it.
extension RecordingNotifier: StatusNotifying {}

/// Counts what a test is told.
@MainActor
final class Counter {
    var count = 0
}

/// A screen in front, as the 60-second check sees it: iPad can show several.
@MainActor
final class StandInScreen {
    var isInDemo: Bool

    init(isInDemo: Bool = false) {
        self.isInDemo = isInDemo
    }
}

/// What the status source told the screen, in order.
@MainActor
final class Heard {
    private(set) var outcomes: [RefreshOutcome] = []

    /// Listens until the returned observer is removed.
    func listen(to source: PilotStatusSource) -> any NSObjectProtocol {
        NotificationCenter.default.addObserver(forName: .pilotStatusDidUpdate, object: source, queue: nil) { _ in
            MainActor.assumeIsolated {
                if let outcome = source.lastUpdate?.outcome {
                    self.outcomes.append(outcome)
                }
            }
        }
    }
}

/// Summaries, door answers and iCloud readings for tests, made from a few fields.
@MainActor
enum Make {
    /// Plain strings, so a default argument can name them.
    nonisolated static let partnerA = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
    nonisolated static let partnerB = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
    static let key = String(repeating: "5e", count: 32)

    /// A summary with the four fields every summary has, and `fields`.
    static func summary(lastUpdated: TimeInterval = 1_792_605_600, _ fields: [String: Any] = [:]) throws -> CloudSummary {
        var json: [String: Any] = ["pilotId": "pilot", "pilotFirstName": "Alex", "lastUpdated": lastUpdated, "appVersion": "3.0"]
        json.merge(fields) { $1 }
        return try CloudSummary.decoder().decode(CloudSummary.self, from: JSONSerialization.data(withJSONObject: json))
    }

    /// partner_view's answer with a summary for a partner, A unless said.
    static func answer(
        updatedAt: String, _ summary: CloudSummary, partnerID: String = partnerA
    ) -> Result<PartnerViewAnswer, PartnerDoorError> {
        .success(PartnerViewAnswer(partnerID: partnerID, updatedAt: updatedAt, content: .summary(summary)))
    }

    static func unchanged(updatedAt: String) -> Result<PartnerViewAnswer, PartnerDoorError> {
        .success(PartnerViewAnswer(partnerID: partnerA, updatedAt: updatedAt, content: .unchanged))
    }

    static let noSummaryYet: Result<PartnerViewAnswer, PartnerDoorError> =
        .success(PartnerViewAnswer(partnerID: partnerA, updatedAt: nil, content: .noSummaryYet))

    /// An iCloud read of a record made at `lastUpdated`.
    static func iCloud(
        lastUpdated: TimeInterval, displayName: String? = nil, isDisplayNameKnown: Bool = true
    ) throws -> ICloudReading {
        ICloudReading(
            status: try summary(lastUpdated: lastUpdated).pilotStatus(partnerID: partnerA, at: .now),
            displayName: displayName,
            isDisplayNameKnown: isDisplayNameKnown,
            recordModifiedAt: nil
        )
    }
}

/// Yields until `condition` holds, failing the test if it never does.
@MainActor
func eventually(_ condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async {
    for _ in 0..<10_000 where !condition() {
        await Task.yield()
    }
    #expect(condition(), "never happened", sourceLocation: sourceLocation)
}

/// A clock whose sleeps end when the test says: each `tick()` ends the oldest sleep, and a
/// cancelled sleep ends by throwing, as `Task.sleep` does.
@MainActor
final class HandClock {
    private(set) var sleeps: [Duration] = []
    private var waiting: [(id: UUID, continuation: CheckedContinuation<Void, any Error>)] = []

    /// How many sleeps are waiting for a tick.
    var waitingCount: Int { waiting.count }

    func sleep(_ duration: Duration) async throws {
        sleeps.append(duration)
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                self.wait(id, continuation)
            }
        } onCancel: {
            Task { @MainActor in self.cancel(id) }
        }
    }

    func tick() {
        guard !waiting.isEmpty else { return }
        waiting.removeFirst().continuation.resume()
    }

    private func wait(_ id: UUID, _ continuation: CheckedContinuation<Void, any Error>) {
        if Task.isCancelled {
            continuation.resume(throwing: CancellationError())
        } else {
            waiting.append((id: id, continuation: continuation))
        }
    }

    private func cancel(_ id: UUID) {
        guard let index = waiting.firstIndex(where: { $0.id == id }) else { return }
        waiting.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}
