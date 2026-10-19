//
//  RepeatingRefresh.swift
//  CrewLuve
//
//  Runs an action every so often, while started
//

import Foundation

/// Runs an action every `interval` while started: the 60-second check while the app is in front
/// and on Crewlu Cloud (partner links piece 4 spec §5.5).
final class RepeatingRefresh {
    typealias Sleep = (Duration) async throws -> Void

    private let interval: Duration
    private let sleep: Sleep
    private var task: Task<Void, Never>?

    init(interval: Duration = .seconds(60), sleep: @escaping Sleep = { try await Task.sleep(for: $0) }) {
        self.interval = interval
        self.sleep = sleep
    }

    var isRunning: Bool { task != nil }

    /// Runs `action` after each `interval` until `stop()`, in place of anything started before.
    func start(_ action: @escaping () async -> Void) {
        task?.cancel()
        task = Task { [interval, sleep] in
            while true {
                do {
                    try await sleep(interval)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await action()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
