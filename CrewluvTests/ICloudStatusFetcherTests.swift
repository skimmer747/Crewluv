//
//  ICloudStatusFetcherTests.swift
//  CrewluvTests
//
//  A record on the pilot's own iCloud that no share holds is left from sharing that ended
//

import CloudKit
import Testing
@testable import Crewluv

struct ICloudStatusFetcherTests {
    private func statusRecord() -> CKRecord {
        CKRecord(recordType: "PilotStatus",
                 recordID: CKRecord.ID(recordName: "pilot-status",
                                       zoneID: CKRecordZone.ID(zoneName: "PartnerBeaconZone",
                                                               ownerName: CKCurrentUserDefaultName)))
    }

    /// A write that came after the share was deleted made it again.
    @Test func test_onThePilotsOwnICloud_aRecordNoShareHolds_isLeftOver() {
        #expect(ICloudStatusFetcher.isLeftover(statusRecord(), onPilotsOwnICloud: true))
    }

    /// While the pilot shares through iCloud, the record is the share's.
    @Test func test_onThePilotsOwnICloud_aRecordTheShareHolds_isNotLeftOver() {
        let record = statusRecord()
        _ = CKShare(rootRecord: record)
        #expect(!ICloudStatusFetcher.isLeftover(record, onPilotsOwnICloud: true))
    }

    /// A partner reads only what the pilot's share holds.
    @Test func test_onAPartnersShare_theRecordIsNeverLeftOver() {
        #expect(!ICloudStatusFetcher.isLeftover(statusRecord(), onPilotsOwnICloud: false))
    }
}
