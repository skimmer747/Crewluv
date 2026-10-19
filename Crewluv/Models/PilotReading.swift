//
//  PilotReading.swift
//  CrewLuve
//
//  What was last read of the pilot's status, from iCloud or Crewlu Cloud
//

import Foundation

/// What `PilotStatusSource` last read: the iCloud record, or Crewlu Cloud's summary for this
/// partner. The screen resolves it at any moment, because a Crewlu Cloud quick status can give way
/// to another as time passes.
enum PilotReading {
    case iCloud(ICloudReading)
    /// The summary, the partner it was trimmed for, and when it last changed, as the door said.
    case crewluCloud(CloudSummary, partnerID: String, updatedAt: String?)

    /// The pilot's status at `now`, before the screen resolves it against the legs.
    func status(at now: Date) -> SharedPilotStatus {
        switch self {
        case .iCloud(let reading): reading.status
        case .crewluCloud(let summary, let partnerID, _): summary.pilotStatus(partnerID: partnerID, at: now)
        }
    }

    /// The name the pilot set for this partner, or nil when there's none.
    var displayName: String? {
        switch self {
        case .iCloud(let reading): reading.displayName
        case .crewluCloud(let summary, let partnerID, _): summary.displayName(for: partnerID)
        }
    }

    /// When the status changes by itself: when the quick status shown at `now` expires. iCloud's
    /// one quick status simply disappears then, so it never needs a wake-up.
    func change(after now: Date) -> Date? {
        guard case .crewluCloud(let summary, let partnerID, _) = self else { return nil }
        return summary.quickStatusChange(for: partnerID, after: now)
    }

    /// When CrewLu made the status.
    var lastUpdated: Date {
        switch self {
        case .iCloud(let reading): reading.status.lastUpdated
        case .crewluCloud(let summary, _, _): summary.lastUpdated
        }
    }

    /// When CloudKit last saved the record, for iCloud's debug log of leg changes.
    var recordModifiedAt: Date? {
        guard case .iCloud(let reading) = self else { return nil }
        return reading.recordModifiedAt
    }
}
