//
//  NotificationDiagnostics.swift
//  CrewLuve
//
//  Records notification pipeline events for DEBUG diagnostics.
//  Stored in UserDefaults so data survives app restarts.
//

import Foundation

actor NotificationDiagnostics {
    static let shared = NotificationDiagnostics()

    // MARK: - Event Types

    enum Event: String {
        case apnsRegistered = "apns_registered"
        case apnsRegistrationFailed = "apns_registration_failed"
        case silentPushReceived = "silent_push_received"
        case backgroundRefresh = "background_refresh"
        case localNotificationFired = "local_notification_fired"
    }

    // MARK: - Diagnostic Snapshot

    struct Snapshot: Sendable {
        let apnsRegisteredAt: Date?
        let apnsError: String?
        let silentPushCount: Int
        let lastSilentPushAt: Date?
        let backgroundRefreshCount: Int
        let lastBackgroundRefreshAt: Date?
        let localNotificationCount: Int
        let lastLocalNotificationAt: Date?
    }

    // MARK: - UserDefaults Keys

    private let prefix = "NotifDiag_"
    private var defaults: UserDefaults { .standard }

    // MARK: - Recording

    nonisolated func record(_ event: Event, error: String? = nil) {
        Task { await _record(event, error: error) }
    }

    private func _record(_ event: Event, error: String?) {
        let now = Date()

        switch event {
        case .apnsRegistered:
            defaults.set(now, forKey: prefix + "apnsRegisteredAt")
            defaults.removeObject(forKey: prefix + "apnsError")

        case .apnsRegistrationFailed:
            defaults.set(error, forKey: prefix + "apnsError")

        case .silentPushReceived:
            let count = defaults.integer(forKey: prefix + "silentPushCount") + 1
            defaults.set(count, forKey: prefix + "silentPushCount")
            defaults.set(now, forKey: prefix + "lastSilentPushAt")

        case .backgroundRefresh:
            let count = defaults.integer(forKey: prefix + "bgRefreshCount") + 1
            defaults.set(count, forKey: prefix + "bgRefreshCount")
            defaults.set(now, forKey: prefix + "lastBgRefreshAt")

        case .localNotificationFired:
            let count = defaults.integer(forKey: prefix + "localNotifCount") + 1
            defaults.set(count, forKey: prefix + "localNotifCount")
            defaults.set(now, forKey: prefix + "lastLocalNotifAt")
        }
    }

    // MARK: - Snapshot

    func snapshot() -> Snapshot {
        Snapshot(
            apnsRegisteredAt: defaults.object(forKey: prefix + "apnsRegisteredAt") as? Date,
            apnsError: defaults.string(forKey: prefix + "apnsError"),
            silentPushCount: defaults.integer(forKey: prefix + "silentPushCount"),
            lastSilentPushAt: defaults.object(forKey: prefix + "lastSilentPushAt") as? Date,
            backgroundRefreshCount: defaults.integer(forKey: prefix + "bgRefreshCount"),
            lastBackgroundRefreshAt: defaults.object(forKey: prefix + "lastBgRefreshAt") as? Date,
            localNotificationCount: defaults.integer(forKey: prefix + "localNotifCount"),
            lastLocalNotificationAt: defaults.object(forKey: prefix + "lastLocalNotifAt") as? Date
        )
    }
}
