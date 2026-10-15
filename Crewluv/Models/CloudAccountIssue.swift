//
//  CloudAccountIssue.swift
//  CrewLuve
//
//  Why the user's iCloud account can't serve CloudKit requests right now
//

import CloudKit

/// Why the user's iCloud account can't serve CloudKit requests right now.
///
/// An account issue says nothing about the pilot's share. Apple's guidance for an
/// account that isn't ready is to keep cached state and retry once it reports
/// `.available`, so no case here should send a connected partner back to onboarding.
nonisolated enum CloudAccountIssue: Equatable, Sendable {
    /// Signed in, but iCloud needs the user to act in Settings before CloudKit
    /// responds — surfaced as `CKError.Code.accountTemporarilyUnavailable` (code 36).
    case needsAttention
    /// No iCloud account is signed in on this device.
    case signedOut
    /// Screen Time or device management blocks iCloud access.
    case restricted
    /// The system couldn't determine the account's status.
    case undetermined

    /// Creates the issue an account status represents, or `nil` when the account is ready.
    init?(accountStatus: CKAccountStatus) {
        switch accountStatus {
        case .available:
            return nil
        case .temporarilyUnavailable:
            self = .needsAttention
        case .noAccount:
            self = .signedOut
        case .restricted:
            self = .restricted
        case .couldNotDetermine:
            self = .undetermined
        @unknown default:
            self = .undetermined
        }
    }

    /// A plain-language explanation that tells the user how to recover.
    var message: String {
        switch self {
        case .needsAttention:
            "Your iCloud account needs attention. Open Settings, tap your name at the top, and follow any prompts to verify your Apple Account."
        case .signedOut:
            "Sign in to iCloud in Settings to see your pilot's status."
        case .restricted:
            "iCloud is restricted on this device. Check Screen Time in Settings, or ask whoever manages this device."
        case .undetermined:
            "CrewLuve couldn't check your iCloud account. Check your connection and try again."
        }
    }
}
