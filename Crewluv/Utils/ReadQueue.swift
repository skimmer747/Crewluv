//
//  ReadQueue.swift
//  CrewLuve
//
//  Runs reads one at a time, with at most one waiting
//

import Foundation

/// Runs reads one at a time. A read asked for while one is under way, say for a push that came
/// mid-read, starts once that one ends, since the read under way may have missed what it was asked
/// for. Every read asked for meanwhile shares it.
final class ReadQueue<Outcome: Sendable> {
    private var readUnderWay: Task<Outcome, Never>?
    /// The read that starts once the one under way ends.
    private var queuedRead: Task<Outcome, Never>?

    /// Whether a read waits for the one under way to end.
    var isReadQueued: Bool { queuedRead != nil }

    /// Runs `read` now, or once the read under way ends, and gives its outcome. Every caller passes
    /// the same read.
    func run(_ read: @escaping @MainActor () async -> Outcome) async -> Outcome {
        if let queuedRead {
            return await queuedRead.value
        }
        guard let readUnderWay else {
            return await start(read)
        }
        let next = Task {
            _ = await readUnderWay.value
            return await self.start(read)
        }
        queuedRead = next
        return await next.value
    }

    private func start(_ read: @escaping @MainActor () async -> Outcome) async -> Outcome {
        queuedRead = nil
        let task = Task { await read() }
        readUnderWay = task
        let outcome = await task.value
        // The queued read may have started before this caller carried on.
        if readUnderWay == task {
            readUnderWay = nil
        }
        return outcome
    }
}
