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

        // The read can't be cut short, since a push or the screen may share it. So when iOS asks
        // the app to stop, the task ends right then, and the read's own end changes nothing.
        let completion = OneTimeCompletion { task.setTaskCompleted(success: $0) }
        task.expirationHandler = {
            debugLog("[BGRefresh] Task expired before the read ended")
            completion(success: false)
        }

        // The status source hands a new status to the alerts.
        if case .failed(let reason) = await PilotStatusSource.shared.refresh() {
            debugLog("[BGRefresh] Background refresh failed: \(reason)")
            completion(success: false)
        } else {
            debugLog("[BGRefresh] Background refresh completed successfully")
            completion(success: true)
        }
    }
}
