//
//  PartnerCloudStandIns.swift
//  CrewluvTests
//
//  Stand-ins for Crewlu Cloud, iCloud, the Keychain and the alerts, and statuses made
//  from a few fields
//

import Foundation
import Testing
@testable import Crewluv

/// The partner door, answering from a script and recording each call.
@MainActor
final class StandInPartnerDoor: PartnerDoor {
    /// The answers to `view`, in order. With none left, the door can't be reached.
    var viewAnswers: [Result<PartnerViewAnswer, PartnerDoorError>] = []
    /// The answers to `setPush`, in order. With none left, it says ok.
    var setPushAnswers: [Result<Void, PartnerDoorError>] = []
    /// While true, each `view` waits for `release()`.
    var holdsViews = false

    private(set) var views: [(key: String, since: String?)] = []
    private(set) var pushes: [(key: String, token: String, environment: PushEnvironment)] = []
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
        guard !setPushAnswers.isEmpty else { return }
        try setPushAnswers.removeFirst().get()
    }

    /// Lets every held `view` go on.
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

    func deviceKey() -> String? {
        key
    }

    func save(deviceKey: String) -> Bool {
        key = deviceKey
        return true
    }

    func forgetDeviceKey() {
        key = nil
    }
}

/// The alerts, recording what they're handed.
actor RecordingNotifier: StatusNotifying {
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

/// Counts what a test is told.
@MainActor
final class Counter {
    var count = 0
}

/// Summaries, door answers and iCloud readings for tests, made from a few fields.
@MainActor
enum Make {
    static let partnerA = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
    static let key = String(repeating: "5e", count: 32)

    /// A summary with the four fields every summary has, and `fields`.
    static func summary(lastUpdated: TimeInterval = 1_792_605_600, _ fields: [String: Any] = [:]) throws -> CloudSummary {
        var json: [String: Any] = ["pilotId": "pilot", "pilotFirstName": "Alex", "lastUpdated": lastUpdated, "appVersion": "3.0"]
        json.merge(fields) { $1 }
        return try CloudSummary.decoder().decode(CloudSummary.self, from: JSONSerialization.data(withJSONObject: json))
    }

    /// partner_view's answer with a summary for partner A.
    static func answer(updatedAt: String, _ summary: CloudSummary) -> Result<PartnerViewAnswer, PartnerDoorError> {
        .success(PartnerViewAnswer(partnerID: partnerA, updatedAt: updatedAt, content: .summary(summary)))
    }

    static func unchanged(updatedAt: String) -> Result<PartnerViewAnswer, PartnerDoorError> {
        .success(PartnerViewAnswer(partnerID: partnerA, updatedAt: updatedAt, content: .unchanged))
    }

    static let noSummaryYet: Result<PartnerViewAnswer, PartnerDoorError> =
        .success(PartnerViewAnswer(partnerID: partnerA, updatedAt: nil, content: .noSummaryYet))

    /// An iCloud read of a record made at `lastUpdated`.
    static func iCloud(lastUpdated: TimeInterval, displayName: String? = nil) throws -> ICloudReading {
        ICloudReading(
            status: try summary(lastUpdated: lastUpdated).pilotStatus(partnerID: partnerA, at: .now),
            displayName: displayName,
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
