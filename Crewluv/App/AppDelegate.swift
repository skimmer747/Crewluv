//
//  AppDelegate.swift
//  CrewLuv
//
//  Receives CloudKit share metadata when user taps a share link
//

import UIKit
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        debugLog("[CrewLuv] 📲 userDidAcceptCloudKitShareWith called")
        Task { @MainActor in
            await CloudKitShareManager.shared.acceptShare(with: cloudKitShareMetadata)
        }
    }
}
