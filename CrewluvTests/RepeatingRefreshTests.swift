//
//  RepeatingRefreshTests.swift
//  CrewluvTests
//
//  The 60-second check's timer (partner links piece 4 spec §5.5)
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
struct RepeatingRefreshTests {

    @Test func test_start_runsTheActionAfterEachInterval() async {
        let clock = HandClock()
        let runs = Counter()
        let check = RepeatingRefresh(sleep: clock.sleep)

        check.start { runs.count += 1 }
        await until { clock.sleeps.count == 1 }
        #expect(runs.count == 0)
        clock.tick()
        await until { runs.count == 1 }
        clock.tick()
        await until { runs.count == 2 }

        #expect(clock.sleeps.allSatisfy { $0 == .seconds(60) })
        #expect(check.isRunning)
        check.stop()
    }

    @Test func test_stop_endsTheChecks() async {
        let clock = HandClock()
        let runs = Counter()
        let check = RepeatingRefresh(sleep: clock.sleep)

        check.start { runs.count += 1 }
        await until { clock.sleeps.count == 1 }
        check.stop()
        clock.tick()
        for _ in 0..<100 {
            await Task.yield()
        }

        #expect(runs.count == 0)
        #expect(!check.isRunning)
    }

    @Test func test_startAgain_replacesTheChecks() async {
        let clock = HandClock()
        let first = Counter()
        let second = Counter()
        let check = RepeatingRefresh(sleep: clock.sleep)

        check.start { first.count += 1 }
        await until { clock.sleeps.count == 1 }
        check.start { second.count += 1 }
        await until { clock.sleeps.count == 2 && clock.waitingCount == 1 }
        clock.tick()
        await until { second.count == 1 }
        for _ in 0..<100 {
            await Task.yield()
        }

        #expect(first.count == 0)
        check.stop()
    }

    /// Yields until `condition` holds, failing the test if it never does.
    private func until(_ condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async {
        for _ in 0..<10_000 where !condition() {
            await Task.yield()
        }
        #expect(condition(), "never happened", sourceLocation: sourceLocation)
    }
}

/// A clock whose sleeps end when the test says: each `tick()` ends the oldest sleep, and a
/// cancelled sleep ends by throwing, as `Task.sleep` does.
@MainActor
private final class HandClock {
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
