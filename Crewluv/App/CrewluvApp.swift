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
    @State private var purchaseManager = PurchaseManager.shared
    
    init() {
        debugLog("[CrewLuv] 🚀 App launching...")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(purchaseManager)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    debugLog("[CrewLuv] 📲 onContinueUserActivity triggered")
                    handleIncomingShare(userActivity)
                }
                .onOpenURL { url in
                    debugLog("[CrewLuv] 🔗 onOpenURL triggered with: \(url)")
                    handleIncomingShareURL(url)
                }
                .task {
                    // Check for recently accepted shares on launch
                    await CloudKitShareManager.shared.checkForAcceptedShares()
                }
        }
    }

    private func handleIncomingShare(_ userActivity: NSUserActivity) {
        guard let url = userActivity.webpageURL else {
            debugLog("[CrewLuv] No URL in user activity")
            return
        }

        debugLog("[CrewLuv] Received share URL from user activity: \(url)")
        Task {
            do {
                try await CloudKitShareManager.shared.acceptShare(from: url)
            } catch {
                debugLog("[CrewLuv] ❌ Error accepting share: \(error)")
            }
        }
    }

    private func handleIncomingShareURL(_ url: URL) {
        debugLog("[CrewLuv] Received URL: \(url)")
        Task {
            do {
                try await CloudKitShareManager.shared.acceptShare(from: url)
            } catch {
                debugLog("[CrewLuv] ❌ Error accepting share: \(error)")
            }
        }
    }
}
