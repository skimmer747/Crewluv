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
    static let shareDataReset = Notification.Name("shareDataReset")
}

@main
struct CrewluvApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var shareManager = CloudKitShareManager.shared

    init() {
        debugLog("[CrewLuve] 🚀 App launching...")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(shareManager)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    guard let url = userActivity.webpageURL else { return }
                    debugLog("[CrewLuve] onContinueUserActivity: \(PartnerLink.logDescription(of: url))")
                    LinkRouter.open(url)
                }
                .onOpenURL { url in
                    debugLog("[CrewLuve] 🔗 onOpenURL triggered with: \(PartnerLink.logDescription(of: url))")
                    LinkRouter.open(url)
                }
        }
    }
}
