//
//  BackgroundRefreshManager.swift
//  CrewLuve
//
//  Schedules BGAppRefreshTask as a fallback for when iOS throttles
//  silent push notifications, ensuring the status is read now and then.
//

import BackgroundTasks
import Foundation

actor BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()

    private let taskIdentifier = "com.ToddAnderson.Crewluv.statusRefresh"

    // MARK: - Registration

    /// Must be called synchronously during app launch (before `didFinishLaunchingWithOptions` returns).
    nonisolated func registerTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Task { await self.handleRefresh(refreshTask) }
        }
        debugLog("[BGRefresh] Registered background refresh task")
    }

    // MARK: - Scheduling

    func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            debugLog("[BGRefresh] Scheduled next refresh in ~15 min")
        } catch {
            debugLog("[BGRefresh] Failed to schedule refresh: \(error)")
        }
    }

    // MARK: - Handling

    private func handleRefresh(_ task: BGAppRefreshTask) async {
        debugLog("[BGRefresh] Background refresh started")
        NotificationDiagnostics.shared.record(.backgroundRefresh)

        // Schedule the next refresh before doing work
        scheduleNextRefresh()

        // Register the expiration handler BEFORE creating the work task.
        // CancellableHandle is thread-safe — if expiration fires before
        // track(_:) is called, the task is cancelled on assignment.
        let handle = CancellableHandle()

        task.expirationHandler = {
            handle.cancel()
            debugLog("[BGRefresh] Task expired — cancelled in-flight work")
        }

        let fetchTask = Task { try await self.fetchAndEvaluate() }
        handle.track(fetchTask)

        do {
            try await fetchTask.value
            task.setTaskCompleted(success: true)
            debugLog("[BGRefresh] Background refresh completed successfully")
        } catch {
            task.setTaskCompleted(success: false)
            debugLog("[BGRefresh] Background refresh failed: \(error)")
        }
    }

    /// Reads the status through the status source, which hands a new one to the alerts.
    private func fetchAndEvaluate() async throws {
        let outcome = await PilotStatusSource.shared.refresh()
        if case .failed(let reason) = outcome {
            throw BackgroundReadFailed(reason: reason)
        }
    }
}

/// A background read that didn't get the status.
private struct BackgroundReadFailed: Error {
    let reason: String
}

// MARK: - CancellableHandle

/// Bridges BGAppRefreshTask expiration into Swift Task cancellation.
///
/// The expiration handler runs on an arbitrary system thread, but we need
/// it to cancel a Task that may not exist yet when the handler fires.
/// This class is thread-safe via NSLock: if `cancel()` is called before
/// `track(_:)`, the task is cancelled the moment it's assigned.
private final class CancellableHandle: @unchecked Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var task: Task<Void, Error>?
    private nonisolated(unsafe) var expired = false

    nonisolated init() {}

    /// Registers the work task. If expiration already fired, cancels it immediately.
    nonisolated func track(_ work: Task<Void, Error>) {
        let shouldCancel = lock.withLock {
            task = work
            return expired
        }
        if shouldCancel { work.cancel() }
    }

    /// Marks as expired and cancels the tracked task (if any).
    nonisolated func cancel() {
        let work = lock.withLock {
            expired = true
            return task
        }
        work?.cancel()
    }
}
