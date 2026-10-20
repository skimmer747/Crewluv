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
            LinkRouter.accept(metadata)
        }
        // Path B: an invite or code link, or a share URL (crewluv:// or icloud.com/share), in urlContexts
        else if let linkCtx = options.urlContexts.first(where: { OpenedLink(url: $0.url) != .neither }) {
            debugLog("[AppDelegate] Found a link in urlContexts: \(PartnerLink.logDescription(of: linkCtx.url))")
            LinkRouter.open(linkCtx.url)
        }
        // Path C: an invite or code link, or a share URL, in user activities
        else if let link = options.userActivities.compactMap({ $0.webpageURL }).first(where: { OpenedLink(url: $0) != .neither }) {
            debugLog("[AppDelegate] Found a link in userActivities: \(PartnerLink.logDescription(of: link))")
            LinkRouter.open(link)
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
        debugLog("[AppDelegate] application(_:open:) URL: \(PartnerLink.logDescription(of: url))")
        return LinkRouter.open(url)
    }

    // MARK: - User activity continuation fallback

    func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void) -> Bool {
        debugLog("[AppDelegate] continue userActivity: \(userActivity.activityType)")
        guard let url = userActivity.webpageURL else { return false }
        debugLog("[AppDelegate] Found a link in userActivity continuation: \(PartnerLink.logDescription(of: url))")
        return LinkRouter.open(url)
    }

    // MARK: - Warm-launch fallback

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        debugLog("[AppDelegate] userDidAcceptCloudKitShareWith called")
        LinkRouter.accept(cloudKitShareMetadata)
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
