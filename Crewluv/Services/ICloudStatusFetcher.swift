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
    /// The name the pilot set for this partner, or nil when there's none or it couldn't be looked up.
    let displayName: String?
    /// False when this partner's iCloud user record couldn't be looked up, so whether the pilot set
    /// them a name isn't known.
    let isDisplayNameKnown: Bool
    /// When CloudKit last saved the record, for the debug log of leg changes.
    let recordModifiedAt: Date?
    /// This partner's move-over ticket in the record, once the pilot's CrewLu has moved them to
    /// Crewlu Cloud (partner links piece 4 spec §8.1).
    var moveTicket: String? = nil
}

/// Why an iCloud read gave no status.
nonisolated enum ICloudFetchError: Error, Equatable {
    /// No share has been accepted, and this isn't the pilot's own iCloud.
    case notConnected
    /// The record or its zone is gone because the pilot stopped sharing
    /// (`unknownItem`, `zoneNotFound`), or, on the pilot's own iCloud, no share holds it any more.
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
        let onPilotsOwnICloud = UserDefaults.standard.string(forKey: "PilotDataSource") == "privateDB"
        if onPilotsOwnICloud {
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
        if Self.isLeftover(record, onPilotsOwnICloud: onPilotsOwnICloud) {
            debugLog("[StatusFetcher] The pilot's own record has no share: sharing through iCloud ended")
            throw ICloudFetchError.shareGone
        }

        guard let status = SharedPilotStatus.from(record: record) else { throw ICloudFetchError.unreadableRecord }
        let name = await displayName(in: status)
        return ICloudReading(
            status: status,
            displayName: name.name,
            isDisplayNameKnown: name.isKnown,
            recordModifiedAt: record.modificationDate,
            moveTicket: await moveTicket(in: record)
        )
    }

    /// A record on the pilot's own iCloud that no share holds is left from sharing that ended: a
    /// write that came after the share was deleted made it again.
    nonisolated static func isLeftover(_ record: CKRecord, onPilotsOwnICloud: Bool) -> Bool {
        onPilotsOwnICloud && record.share == nil
    }

    /// This partner's iCloud user record name, looked up once. It keys the pilot's names for each
    /// partner, and the move-over's tickets.
    private func recordName() async -> String? {
        if userRecordName == nil {
            userRecordName = try? await container.userRecordID().recordName
        }
        return userRecordName
    }

    /// This partner's move-over ticket, if the record has one for them (spec §8.1).
    private func moveTicket(in record: CKRecord) async -> String? {
        guard let tickets = record[MoveTicket.recordKey] as? Data else { return nil }
        return MoveTicket.ticket(in: tickets, for: await recordName())
    }

    /// The name the pilot set for this partner, looked up strictly by this partner's own iCloud
    /// user record name: falling back to another entry would show a name meant for someone else.
    /// Not known when that record name couldn't be looked up.
    private func displayName(in status: SharedPilotStatus) async -> (name: String?, isKnown: Bool) {
        let names = status.displayNameByPartner
        guard !names.isEmpty else { return (nil, true) }
        guard let userRecordName = await recordName() else { return (nil, false) }
        guard let name = names[userRecordName], !name.isEmpty else { return (nil, true) }
        return (name, true)
    }
}
