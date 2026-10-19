//
//  ICloudStatusFetcher.swift
//  CrewLuve
//
//  Reads the pilot's status record from iCloud
//

import CloudKit
import Foundation

/// What one iCloud read gives.
struct ICloudReading {
    let status: SharedPilotStatus
    /// The name the pilot set for this partner, or nil when there's none.
    let displayName: String?
    /// When CloudKit last saved the record, for the debug log of leg changes.
    let recordModifiedAt: Date?
}

/// Why an iCloud read gave no status.
nonisolated enum ICloudFetchError: Error, Equatable {
    /// No share has been accepted, and this isn't the pilot's own iCloud.
    case notConnected
    /// The record or its zone is gone because the pilot stopped sharing
    /// (`unknownItem`, `zoneNotFound`).
    case shareGone
    /// The record lacks the fields a status needs.
    case unreadableRecord
}

/// Reads the pilot's status from iCloud.
protocol ICloudStatusFetching {
    func fetch() async throws -> ICloudReading
}

/// Reads the pilot's `pilot-status` record: from the shared database, in the zone of the pilot
/// whose share was accepted, or from the private database when Crewluve runs on the pilot's own
/// iCloud. The screen, the push handler and the background refresh each used to read it this way.
final class ICloudStatusFetcher: ICloudStatusFetching {
    /// Made on first use, so nothing touches CloudKit before a read.
    private lazy var container = CKContainer(identifier: "iCloud.com.toddanderson.duty")
    /// This partner's iCloud user record name, which keys the pilot's names for each partner.
    private var userRecordName: String?

    func fetch() async throws -> ICloudReading {
        let database: CKDatabase
        let ownerName: String
        if UserDefaults.standard.string(forKey: "PilotDataSource") == "privateDB" {
            database = container.privateCloudDatabase
            ownerName = CKCurrentUserDefaultName
        } else {
            guard let storedOwner = UserDefaults.standard.string(forKey: "SharedZoneOwner") else {
                throw ICloudFetchError.notConnected
            }
            database = container.sharedCloudDatabase
            ownerName = storedOwner
        }

        let zoneID = CKRecordZone.ID(zoneName: "PartnerBeaconZone", ownerName: ownerName)
        let recordID = CKRecord.ID(recordName: "pilot-status", zoneID: zoneID)
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            throw ICloudFetchError.shareGone
        }

        guard let status = SharedPilotStatus.from(record: record) else { throw ICloudFetchError.unreadableRecord }
        return ICloudReading(
            status: status,
            displayName: await displayName(in: status),
            recordModifiedAt: record.modificationDate
        )
    }

    /// The name the pilot set for this partner, looked up strictly by this partner's own iCloud
    /// user record name: falling back to another entry would show a name meant for someone else.
    private func displayName(in status: SharedPilotStatus) async -> String? {
        let names = status.displayNameByPartner
        guard !names.isEmpty else { return nil }
        if userRecordName == nil {
            userRecordName = try? await container.userRecordID().recordName
        }
        guard let name = userRecordName.flatMap({ names[$0] }), !name.isEmpty else { return nil }
        return name
    }
}
