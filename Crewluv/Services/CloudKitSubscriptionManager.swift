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
    private let currentSharedSubID = "crewluv-shared-db-v2"

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
        // Clean up any stale subscription IDs from previous attempts
        let staleIDs = [oldSharedSubID, "crewluv-shared-zone"]
        if let savedID = UserDefaults.standard.string(forKey: sharedSubKey),
           staleIDs.contains(savedID) {
            debugLog("[SubManager] Migrating stale subscription: \(savedID)")
            do {
                try await container.sharedCloudDatabase.deleteSubscription(withID: savedID)
                debugLog("[SubManager] Deleted stale subscription: \(savedID)")
            } catch {
                debugLog("[SubManager] Best-effort delete of stale subscription failed: \(error)")
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

    // MARK: - Shared Database Subscription

    /// Creates a database-level subscription on the shared database.
    /// CKDatabaseSubscription is the only subscription type Apple allows on the shared database.
    /// It fires for any record change in the shared database.
    func ensureSharedZoneSubscription() async {
        if let existingID = UserDefaults.standard.string(forKey: sharedSubKey) {
            debugLog("[SubManager] Shared database subscription already registered: \(existingID)")
            return
        }

        guard UserDefaults.standard.string(forKey: "SharedZoneOwner") != nil else {
            debugLog("[SubManager] No stored zone owner, cannot create shared database subscription")
            return
        }

        let subscriptionID = "crewluv-shared-db-v2"
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            try await container.sharedCloudDatabase.save(subscription)
            UserDefaults.standard.set(subscriptionID, forKey: sharedSubKey)
            debugLog("[SubManager] Shared database subscription created: \(subscriptionID)")
            await verifySubscriptionServerSide(database: container.sharedCloudDatabase, expectedID: subscriptionID, userDefaultsKey: sharedSubKey)
        } catch {
            debugLog("[SubManager] Failed to create shared database subscription: \(error)")
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
            await verifySubscriptionServerSide(database: container.privateCloudDatabase, expectedID: subscriptionID, userDefaultsKey: privateSubKey)
        } catch {
            debugLog("[SubManager] Failed to create private zone subscription: \(error)")
        }
    }

    // MARK: - Server-Side Verification

    /// Fetches all subscriptions from the database and confirms ours is present.
    /// Eliminates phantom saves where `save()` succeeds locally but the subscription doesn't persist server-side.
    /// When the subscription is missing, clears the persisted flag so the next `ensure*` call recreates it.
    private func verifySubscriptionServerSide(
        database: CKDatabase,
        expectedID: String,
        userDefaultsKey: String
    ) async {
        do {
            let serverSubscriptions = try await database.allSubscriptions()
            let ids = serverSubscriptions.map(\.subscriptionID)
            let isConfirmed = ids.contains(expectedID)
            debugLog("[SubManager] Server verification: \(expectedID) confirmed=\(isConfirmed), all IDs=\(ids)")

            if !isConfirmed {
                // The save() appeared to succeed but the subscription isn't actually on the server.
                // Clear the stored flag so the subscription will be recreated on the next verification cycle
                // rather than silently staying broken.
                debugLog("[SubManager] Subscription \(expectedID) NOT found server-side — clearing persisted flag for key '\(userDefaultsKey)'")
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            }
        } catch {
            debugLog("[SubManager] Server verification fetch failed: \(error)")
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
