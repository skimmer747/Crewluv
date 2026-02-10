//
//  AppDelegate.swift
//  CrewLuv
//
//  Receives CloudKit share metadata when user taps a share link

import UIKit
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Scene connection (cold launch)

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        debugLog("[AppDelegate] configurationForConnecting called")
        debugLog("[AppDelegate]   cloudKitShareMetadata: \(options.cloudKitShareMetadata != nil ? "YES" : "nil")")
        debugLog("[AppDelegate]   urlContexts count: \(options.urlContexts.count)")
        debugLog("[AppDelegate]   userActivities count: \(options.userActivities.count)")

        for ctx in options.urlContexts {
            debugLog("[AppDelegate]   urlContext: \(ctx.url)")
        }
        for activity in options.userActivities {
            debugLog("[AppDelegate]   activity type: \(activity.activityType), webpageURL: \(activity.webpageURL?.absoluteString ?? "nil")")
        }

        // Path A: Direct metadata (preferred but often nil on iOS 17+)
        if let metadata = options.cloudKitShareMetadata {
            debugLog("[AppDelegate] Found CloudKit metadata — accepting share")
            Task { @MainActor in
                await CloudKitShareManager.shared.acceptShare(with: metadata)
            }
        }
        // Path B: iCloud share URL in urlContexts
        else if let shareCtx = options.urlContexts.first(where: { $0.url.absoluteString.contains("icloud.com/share") }) {
            debugLog("[AppDelegate] Found share URL in urlContexts — accepting share")
            let url = shareCtx.url
            Task { @MainActor in
                try? await CloudKitShareManager.shared.acceptShare(from: url)
            }
        }
        // Path C: Share URL in user activities
        else if let shareURL = options.userActivities.compactMap({ $0.webpageURL }).first(where: { $0.absoluteString.contains("icloud.com/share") }) {
            debugLog("[AppDelegate] Found share URL in userActivities — accepting share")
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
        if url.absoluteString.contains("icloud.com/share") {
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
        if let url = userActivity.webpageURL, url.absoluteString.contains("icloud.com/share") {
            debugLog("[AppDelegate] Found share URL in userActivity continuation")
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
