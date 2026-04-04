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

        guard userInfo["ck"] != nil else {
            debugLog("[AppDelegate] Not a CloudKit notification, ignoring")
            completionHandler(.noData)
            return
        }

        NotificationDiagnostics.shared.record(.silentPushReceived)

        // Post for foreground UI updates (PartnerStatusReceiver observes this)
        NotificationCenter.default.post(name: .cloudKitPushReceived, object: nil)

        // Fetch status directly so notifications fire even when the app is suspended
        Task {
            do {
                let newStatus = try await fetchPilotStatusFromCloudKit()
                let pilotName = UserDefaults.standard.string(forKey: "ResolvedPilotDisplayName")
                    ?? newStatus.pilotFirstName
                let resolvedHome = TripStateResolver.resolveHomeArrival(
                    legs: newStatus.tripLegs, homeAirportCode: newStatus.homeAirportCode, at: Date()
                )?.arrivalTime

                await StatusChangeNotifier.shared.evaluateChanges(
                    old: nil,
                    new: newStatus,
                    pilotName: pilotName,
                    newEffectiveDelay: newStatus.effectiveFlightDelayMinutes,
                    resolvedHomeArrivalTime: resolvedHome ?? newStatus.homeArrivalTime
                )

                // Re-schedule BG refresh after successful push handling
                await BackgroundRefreshManager.shared.scheduleNextRefresh()

                debugLog("[AppDelegate] Background fetch + evaluate completed")
                completionHandler(.newData)
            } catch {
                debugLog("[AppDelegate] Background fetch failed: \(error)")
                completionHandler(.failed)
            }
        }
    }

    // MARK: - Background CloudKit Fetch

    /// Fetches the pilot-status record directly from CloudKit using persisted config.
    /// Mirrors the database/owner resolution logic in PartnerStatusReceiver.
    private func fetchPilotStatusFromCloudKit() async throws -> SharedPilotStatus {
        let container = CKContainer(identifier: "iCloud.com.toddanderson.duty")

        let database: CKDatabase
        let ownerName: String

        if UserDefaults.standard.string(forKey: "PilotDataSource") == "privateDB" {
            database = container.privateCloudDatabase
            ownerName = CKCurrentUserDefaultName
        } else {
            guard let storedOwner = UserDefaults.standard.string(forKey: "SharedZoneOwner") else {
                throw NSError(
                    domain: "CrewLuve",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No stored zone owner"]
                )
            }
            database = container.sharedCloudDatabase
            ownerName = storedOwner
        }

        let zoneID = CKRecordZone.ID(zoneName: "PartnerBeaconZone", ownerName: ownerName)
        let recordID = CKRecord.ID(recordName: "pilot-status", zoneID: zoneID)
        let record = try await database.record(for: recordID)

        guard let status = SharedPilotStatus.from(record: record) else {
            throw NSError(
                domain: "CrewLuve",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to parse status record"]
            )
        }

        return status
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
