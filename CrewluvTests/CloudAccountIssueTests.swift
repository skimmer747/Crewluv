//
//  CloudAccountIssueTests.swift
//  CrewluvTests
//
//  A temporarily unavailable iCloud account (CKError 36) must explain how to
//  recover — never read as a missing share or a bare error code.
//

import Testing
import CloudKit
@testable import Crewluv

struct CloudAccountIssueTests {

    // MARK: - Account Status Mapping

    @Test func test_init_availableStatus_returnsNil() {
        #expect(CloudAccountIssue(accountStatus: .available) == nil)
    }

    @Test func test_init_temporarilyUnavailableStatus_returnsNeedsAttention() {
        #expect(CloudAccountIssue(accountStatus: .temporarilyUnavailable) == .needsAttention)
    }

    @Test func test_init_otherUnavailableStatuses_mapToMatchingIssue() {
        #expect(CloudAccountIssue(accountStatus: .noAccount) == .signedOut)
        #expect(CloudAccountIssue(accountStatus: .restricted) == .restricted)
        #expect(CloudAccountIssue(accountStatus: .couldNotDetermine) == .undetermined)
    }

    // MARK: - Share Acceptance Copy

    @Test func test_userFriendlyError_accountTemporarilyUnavailable_explainsRecovery() {
        let message = CloudKitShareManager.userFriendlyError(CKError(.accountTemporarilyUnavailable))
        #expect(message == CloudAccountIssue.needsAttention.message)
    }
}
