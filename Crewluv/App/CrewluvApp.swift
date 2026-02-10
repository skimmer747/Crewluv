//
//  CrewluvApp.swift
//  CrewLuv
//
//  Main entry point for CrewLuv companion app
//

import SwiftUI

// Notification names
extension Notification.Name {
    static let shareAccepted = Notification.Name("shareAccepted")
}

@main
struct CrewluvApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var purchaseManager = PurchaseManager.shared
    @State private var shareManager = CloudKitShareManager.shared

    init() {
        debugLog("[CrewLuv] 🚀 App launching...")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(purchaseManager)
                .environment(shareManager)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    debugLog("[CrewLuv] 📲 onContinueUserActivity triggered")
                    debugLog("[CrewLuv]   activityType: \(userActivity.activityType)")
                    debugLog("[CrewLuv]   webpageURL: \(userActivity.webpageURL?.absoluteString ?? "nil")")
                    if let url = userActivity.webpageURL {
                        handleShareURL(url)
                    } else {
                        debugLog("[CrewLuv] No URL in user activity")
                    }
                }
                .onOpenURL { url in
                    debugLog("[CrewLuv] 🔗 onOpenURL triggered with: \(url)")
                    handleShareURL(url)
                }
        }
    }

    private func handleShareURL(_ url: URL) {
        debugLog("[CrewLuv] 🔗 Processing share URL: \(url)")
        Task {
            do {
                try await shareManager.acceptShare(from: url)
            } catch {
                debugLog("[CrewLuv] ❌ Share acceptance failed: \(error)")
                // Error is already set in shareManager.shareState
            }
        }
    }
}
