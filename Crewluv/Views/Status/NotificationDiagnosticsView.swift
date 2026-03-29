//
//  NotificationDiagnosticsView.swift
//  CrewLuve
//
//  DEBUG-only view showing notification pipeline diagnostics.
//

#if DEBUG

import SwiftUI
import UserNotifications

struct NotificationDiagnosticsView: View {
    @State private var snapshot: NotificationDiagnostics.Snapshot?
    @State private var authStatus: UNAuthorizationStatus?
    @State private var hasSubscription = false

    var body: some View {
        NavigationStack {
            List {
                apnsSection
                pushSection
                backgroundRefreshSection
                localNotificationSection
                subscriptionSection
                actionsSection
            }
            .navigationTitle("Notification Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") { Task { await loadDiagnostics() } }
                }
            }
            .task { await loadDiagnostics() }
        }
    }

    // MARK: - Sections

    private var apnsSection: some View {
        Section("APNS Registration") {
            if let registeredAt = snapshot?.apnsRegisteredAt {
                row("Registered", value: registeredAt.formatted(date: .abbreviated, time: .standard))
            } else {
                row("Registered", value: "Never")
            }
            if let error = snapshot?.apnsError {
                row("Last Error", value: error, isError: true)
            }
            row("Authorization", value: authStatusLabel)
        }
    }

    private var pushSection: some View {
        Section("Silent Pushes") {
            row("Total Received", value: "\(snapshot?.silentPushCount ?? 0)")
            if let lastPush = snapshot?.lastSilentPushAt {
                row("Last Received", value: lastPush.formatted(date: .abbreviated, time: .standard))
            } else {
                row("Last Received", value: "Never")
            }
        }
    }

    private var backgroundRefreshSection: some View {
        Section("Background Refresh (BGTask)") {
            row("Total Runs", value: "\(snapshot?.backgroundRefreshCount ?? 0)")
            if let lastRefresh = snapshot?.lastBackgroundRefreshAt {
                row("Last Run", value: lastRefresh.formatted(date: .abbreviated, time: .standard))
            } else {
                row("Last Run", value: "Never")
            }
        }
    }

    private var localNotificationSection: some View {
        Section("Local Notifications") {
            row("Total Fired", value: "\(snapshot?.localNotificationCount ?? 0)")
            if let lastNotif = snapshot?.lastLocalNotificationAt {
                row("Last Fired", value: lastNotif.formatted(date: .abbreviated, time: .standard))
            } else {
                row("Last Fired", value: "Never")
            }
        }
    }

    private var subscriptionSection: some View {
        Section("CloudKit Subscription") {
            row("Zone Subscription", value: hasSubscription ? "Active" : "Not Found")
            row("Data Source", value: UserDefaults.standard.string(forKey: "PilotDataSource") ?? "shared")
            row("Zone Owner", value: UserDefaults.standard.string(forKey: "SharedZoneOwner") ?? "None")
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button("Re-verify Subscriptions") {
                Task { await CloudKitSubscriptionManager.shared.verifySubscriptions() }
            }
            Button("Schedule BG Refresh Now") {
                Task { await BackgroundRefreshManager.shared.scheduleNextRefresh() }
            }
        }
    }

    // MARK: - Helpers

    private func row(_ label: String, value: String, isError: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(isError ? .red : .primary)
                .fontDesign(.monospaced)
        }
    }

    private var authStatusLabel: String {
        switch authStatus {
        case .authorized: "Authorized"
        case .denied: "Denied"
        case .provisional: "Provisional"
        case .notDetermined: "Not Determined"
        default: "Unknown"
        }
    }

    private func loadDiagnostics() async {
        snapshot = await NotificationDiagnostics.shared.snapshot()

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authStatus = settings.authorizationStatus

        // Check if subscription exists in UserDefaults
        let sharedSub = UserDefaults.standard.string(forKey: "CK_SharedDBSubscriptionID")
        let privateSub = UserDefaults.standard.string(forKey: "CK_PrivateZoneSubscriptionID")
        hasSubscription = sharedSub != nil || privateSub != nil
    }
}

#endif
