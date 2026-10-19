//
//  AppDelegate.swift
//  CrewLuve
//
//  Receives CloudKit share metadata when user taps a share link
//  and handles remote notification registration for silent pushes.

import UIKit
import CloudKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // MARK: - Launch

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackgroundRefreshManager.shared.registerTask()
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        Task { await StatusChangeNotifier.shared.requestAuthorizationIfNeeded() }
        Task { await CloudKitSubscriptionManager.shared.verifySubscriptions() }

        return true
    }

    // MARK: - Remote Notifications

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        debugLog("[AppDelegate] Registered for remote notifications")
        NotificationDiagnostics.shared.record(.apnsRegistered)
        Task { await PushRegistrar.shared.didReceive(deviceToken: deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        debugLog("[AppDelegate] Failed to register for remote notifications: \(error)")
        NotificationDiagnostics.shared.record(.apnsRegistrationFailed, error: error.localizedDescription)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        debugLog("[AppDelegate] Received remote notification")

        let source = PilotStatusSource.shared
        guard PushRoute(userInfo: userInfo, isOnCrewluCloud: source.isOnCrewluCloud) == .refresh else {
            debugLog("[AppDelegate] Not a status push, ignoring")
            completionHandler(.noData)
            return
        }

        NotificationDiagnostics.shared.record(.silentPushReceived)

        // Read the status now, so alerts fire even when the app is suspended. The source hands a
        // new status to the alerts, and the screen hears of it from the source. iOS allows about
        // 30 seconds, and a push that lands mid-read waits for that read and one more, so a read
        // still going after 25 seconds is reported as failed and carries on.
        let complete = OneTimeCompletion(completionHandler)
        let deadline = Task {
            try await Task.sleep(for: .seconds(25))
            debugLog("[AppDelegate] Push read still going after 25 s")
            complete(.failed)
        }
        Task {
            let outcome = await source.refresh().backgroundFetchOutcome
            deadline.cancel()
            if outcome != .failed {
                // Re-schedule BG refresh after successful push handling
                await BackgroundRefreshManager.shared.scheduleNextRefresh()
            }
            debugLog("[AppDelegate] Push handled: \(outcome)")
            complete(outcome.backgroundFetchResult)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Scene connection (cold launch)

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        debugLog("[AppDelegate] configurationForConnecting — metadata: \(options.cloudKitShareMetadata != nil), urls: \(options.urlContexts.count), activities: \(options.userActivities.count)")

        // Path A: Direct metadata (preferred but often nil on iOS 17+)
        if let metadata = options.cloudKitShareMetadata {
            debugLog("[AppDelegate] Found CloudKit metadata — accepting share")
            Task { @MainActor in
                await CloudKitShareManager.shared.acceptShare(with: metadata)
            }
        }
        // Path B: Share URL in urlContexts (crewluv:// or icloud.com/share)
        else if let shareCtx = options.urlContexts.first(where: { ShareURLResolver.isShareURL($0.url) }) {
            debugLog("[AppDelegate] Found share URL in urlContexts — accepting share: \(shareCtx.url)")
            Task { @MainActor in
                try? await CloudKitShareManager.shared.acceptShare(from: shareCtx.url)
            }
        }
        // Path C: Share URL in user activities
        else if let shareURL = options.userActivities.compactMap({ $0.webpageURL }).first(where: { ShareURLResolver.isShareURL($0) }) {
            debugLog("[AppDelegate] Found share URL in userActivities — accepting share: \(shareURL)")
            Task { @MainActor in
                try? await CloudKitShareManager.shared.acceptShare(from: shareURL)
            }
        }

        let config = UISceneConfiguration(
            name: connectingSceneSession.configuration.name,
            sessionRole: connectingSceneSession.role
        )
        config.delegateClass = SceneDelegate.self
        return config
    }

    // MARK: - URL open fallback

    // Deprecated in iOS 26, but still called on older versions
    @available(iOS, deprecated: 26.0)
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        debugLog("[AppDelegate] application(_:open:) URL: \(url)")
        if ShareURLResolver.isShareURL(url) {
            Task { @MainActor in
                try? await CloudKitShareManager.shared.acceptShare(from: url)
            }
            return true
        }
        return false
    }

    // MARK: - User activity continuation fallback

    func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void) -> Bool {
        debugLog("[AppDelegate] continue userActivity: \(userActivity.activityType)")
        if let url = userActivity.webpageURL, ShareURLResolver.isShareURL(url) {
            debugLog("[AppDelegate] Found share URL in userActivity continuation: \(url)")
            Task { @MainActor in
                try? await CloudKitShareManager.shared.acceptShare(from: url)
            }
            return true
        }
        return false
    }

    // MARK: - Warm-launch fallback

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        debugLog("[AppDelegate] userDidAcceptCloudKitShareWith called")
        Task { @MainActor in
            await CloudKitShareManager.shared.acceptShare(with: cloudKitShareMetadata)
        }
    }
}

// MARK: - Background Fetch Results

private extension BackgroundFetchOutcome {
    var backgroundFetchResult: UIBackgroundFetchResult {
        switch self {
        case .newData: .newData
        case .noData: .noData
        case .failed: .failed
        }
    }
}
