//
//  CloudKitSubscriptionManager.swift
//  CrewLuve
//
//  Manages CloudKit database subscriptions for silent push notifications.
//  Creates subscriptions so the app wakes on record changes in the shared zone.
//

import CloudKit
import Foundation

actor CloudKitSubscriptionManager {
    static let shared = CloudKitSubscriptionManager()

    private let container = CKContainer(identifier: "iCloud.com.toddanderson.duty")
    private let sharedSubKey = "CK_SharedDBSubscriptionID"
    private let privateSubKey = "CK_PrivateZoneSubscriptionID"
    private let oldSharedSubID = "crewluv-shared-db"
    private let currentSharedSubID = "crewluv-shared-zone"

    // MARK: - Verification

    /// Checks that our subscriptions still exist server-side and recreates any that are missing.
    /// Call on every app launch to handle CloudKit silently purging subscriptions.
    func verifySubscriptions() async {
        let dataSource = UserDefaults.standard.string(forKey: "PilotDataSource")

        if dataSource == "privateDB" {
            await verifyPrivateZoneSubscription()
        } else if UserDefaults.standard.string(forKey: "SharedZoneOwner") != nil {
            await verifySharedZoneSubscription()
        } else {
            debugLog("[SubManager] No data source configured, skipping verification")
        }
    }

    private func verifySharedZoneSubscription() async {
        // Migrate old CKDatabaseSubscription → CKRecordZoneSubscription (one-time)
        if let savedID = UserDefaults.standard.string(forKey: sharedSubKey),
           savedID == oldSharedSubID {
            debugLog("[SubManager] Migrating stale database subscription → zone subscription")
            do {
                try await container.sharedCloudDatabase.deleteSubscription(withID: oldSharedSubID)
                debugLog("[SubManager] Deleted old database subscription: \(oldSharedSubID)")
            } catch {
                debugLog("[SubManager] Best-effort delete of old subscription failed: \(error)")
            }
            UserDefaults.standard.removeObject(forKey: sharedSubKey)
            await ensureSharedZoneSubscription()
            return
        }

        // Force-refresh: delete stale subscription so ensureSharedZoneSubscription() recreates it
        // with the current APNS token (token may change across reinstalls/OS updates)
        if let savedID = UserDefaults.standard.string(forKey: sharedSubKey) {
            do {
                try await container.sharedCloudDatabase.deleteSubscription(withID: savedID)
                debugLog("[SubManager] Deleted shared subscription for refresh")
            } catch {
                debugLog("[SubManager] Delete before refresh failed (may already be gone): \(error)")
            }
            UserDefaults.standard.removeObject(forKey: sharedSubKey)
        }
        await ensureSharedZoneSubscription()
    }

    private func verifyPrivateZoneSubscription() async {
        // Force-refresh: delete stale subscription so ensurePrivateZoneSubscription() recreates it
        // with the current APNS token (token may change across reinstalls/OS updates)
        if let savedID = UserDefaults.standard.string(forKey: privateSubKey) {
            do {
                try await container.privateCloudDatabase.deleteSubscription(withID: savedID)
                debugLog("[SubManager] Deleted private subscription for refresh")
            } catch {
                debugLog("[SubManager] Delete before refresh failed (may already be gone): \(error)")
            }
            UserDefaults.standard.removeObject(forKey: privateSubKey)
        }
        await ensurePrivateZoneSubscription()
    }

    // MARK: - Shared Zone Subscription

    /// Creates a zone-level subscription on the shared database targeting PartnerBeaconZone.
    /// Zone subscriptions are more reliable than broad database subscriptions for shared data.
    func ensureSharedZoneSubscription() async {
        if let existingID = UserDefaults.standard.string(forKey: sharedSubKey) {
            debugLog("[SubManager] Shared zone subscription already registered: \(existingID)")
            return
        }

        guard let ownerName = UserDefaults.standard.string(forKey: "SharedZoneOwner") else {
            debugLog("[SubManager] No stored zone owner, cannot create shared zone subscription")
            return
        }

        let zoneID = CKRecordZone.ID(zoneName: "PartnerBeaconZone", ownerName: ownerName)
        let subscriptionID = "crewluv-shared-zone"
        let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: subscriptionID)

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            try await container.sharedCloudDatabase.save(subscription)
            UserDefaults.standard.set(subscriptionID, forKey: sharedSubKey)
            debugLog("[SubManager] Shared zone subscription created: \(subscriptionID)")
        } catch {
            debugLog("[SubManager] Failed to create shared zone subscription: \(error)")
        }
    }

    // MARK: - Private Zone Subscription

    func ensurePrivateZoneSubscription() async {
        if let existingID = UserDefaults.standard.string(forKey: privateSubKey) {
            debugLog("[SubManager] Private zone subscription already registered: \(existingID)")
            return
        }

        let zoneID = CKRecordZone.ID(zoneName: "PartnerBeaconZone", ownerName: CKCurrentUserDefaultName)
        let subscriptionID = "crewluv-private-zone"
        let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: subscriptionID)

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            try await container.privateCloudDatabase.save(subscription)
            UserDefaults.standard.set(subscriptionID, forKey: privateSubKey)
            debugLog("[SubManager] Private zone subscription created: \(subscriptionID)")
        } catch {
            debugLog("[SubManager] Failed to create private zone subscription: \(error)")
        }
    }

    // MARK: - Cleanup

    func removeAllSubscriptions() async {
        if let sharedID = UserDefaults.standard.string(forKey: sharedSubKey) {
            do {
                try await container.sharedCloudDatabase.deleteSubscription(withID: sharedID)
                debugLog("[SubManager] Removed shared subscription")
            } catch {
                debugLog("[SubManager] Failed to remove shared subscription: \(error)")
            }
            UserDefaults.standard.removeObject(forKey: sharedSubKey)
        }

        if let privateID = UserDefaults.standard.string(forKey: privateSubKey) {
            do {
                try await container.privateCloudDatabase.deleteSubscription(withID: privateID)
                debugLog("[SubManager] Removed private zone subscription")
            } catch {
                debugLog("[SubManager] Failed to remove private subscription: \(error)")
            }
            UserDefaults.standard.removeObject(forKey: privateSubKey)
        }
    }
}
