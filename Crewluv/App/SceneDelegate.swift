//
//  SceneDelegate.swift
//  CrewLuv
//
//  UIWindowSceneDelegate that receives CloudKit share acceptance on cold launch.
//  SwiftUI continues to manage windows via WindowGroup.

import UIKit
import CloudKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        debugLog("[SceneDelegate] userDidAcceptCloudKitShareWith called")
        debugLog("[SceneDelegate]   share recordID: \(cloudKitShareMetadata.share.recordID)")
        Task { @MainActor in
            await CloudKitShareManager.shared.acceptShare(with: cloudKitShareMetadata)
        }
    }
}
