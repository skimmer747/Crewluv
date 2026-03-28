//
//  CrewluvApp.swift
//  CrewLuve
//
//  Main entry point for CrewLuve companion app
//

import SwiftUI

// Notification names
extension Notification.Name {
    static let shareAccepted = Notification.Name("shareAccepted")
    static let cloudKitPushReceived = Notification.Name("cloudKitPushReceived")
}

@main
struct CrewluvApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var purchaseManager = PurchaseManager.shared
    @State private var shareManager = CloudKitShareManager.shared

    init() {
        debugLog("[CrewLuve] 🚀 App launching...")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(purchaseManager)
                .environment(shareManager)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    debugLog("[CrewLuve] onContinueUserActivity: \(userActivity.webpageURL?.absoluteString ?? "nil")")
                    if let url = userActivity.webpageURL {
                        handleShareURL(url)
                    }
                }
                .onOpenURL { url in
                    debugLog("[CrewLuve] 🔗 onOpenURL triggered with: \(url)")
                    handleShareURL(url)
                }
        }
    }

    private func handleShareURL(_ url: URL) {
        Task {
            do {
                try await shareManager.acceptShare(from: url)
            } catch {
                debugLog("[CrewLuve] ❌ Share acceptance failed: \(error)")
                // Error is already set in shareManager.shareState
            }
        }
    }
}
