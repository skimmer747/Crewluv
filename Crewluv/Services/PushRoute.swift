//
//  PushRoute.swift
//  CrewLuve
//
//  What a silent push means, and what iOS is told afterwards
//

import Foundation

/// What a remote notification means (partner links piece 4 spec §6.2). On Crewlu Cloud, a silent
/// push without iCloud's `ck` key means "check now", and iCloud's own pushes no longer matter.
/// On iCloud, iCloud's pushes do, as before.
nonisolated enum PushRoute: Equatable, Sendable {
    case refresh
    case ignore

    init(userInfo: [AnyHashable: Any], isOnCrewluCloud: Bool) {
        let isFromICloud = userInfo["ck"] != nil
        guard isOnCrewluCloud else {
            self = isFromICloud ? .refresh : .ignore
            return
        }
        let aps = userInfo["aps"] as? [AnyHashable: Any]
        let isSilent = aps?["content-available"] as? Int == 1
        self = isSilent && !isFromICloud ? .refresh : .ignore
    }
}

/// What a background wake-up tells iOS: whether it brought anything new.
nonisolated enum BackgroundFetchOutcome: Equatable, Sendable {
    case newData
    case noData
    case failed
}

extension RefreshOutcome {
    /// What to tell iOS once a push or the background refresh has read the status.
    nonisolated var backgroundFetchOutcome: BackgroundFetchOutcome {
        switch self {
        case .newStatus, .sharingEnded: .newData
        case .unchanged, .noStatusYet, .notConnected, .superseded: .noData
        case .failed: .failed
        }
    }
}
