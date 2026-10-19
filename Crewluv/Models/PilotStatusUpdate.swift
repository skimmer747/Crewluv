//
//  PilotStatusUpdate.swift
//  CrewLuve
//
//  How a read of the pilot's status went
//

import Foundation

extension Notification.Name {
    /// A read ended, or sharing ended outside one: the status source's `lastUpdate` says how it
    /// went. Posted on the main actor.
    static let pilotStatusDidUpdate = Notification.Name("pilotStatusDidUpdate")
}

/// How a read went, for the screen, whoever asked for the read.
nonisolated struct PilotStatusUpdate: Equatable, Sendable {
    let outcome: RefreshOutcome
    /// When the read began, for the screen's "Synced" line.
    let readAt: Date
}

/// How a refresh ended.
nonisolated enum RefreshOutcome: Equatable, Sendable {
    /// A status the source hadn't read before.
    case newStatus
    /// The same status as last time.
    case unchanged
    /// On Crewlu Cloud, but the pilot's CrewLu hasn't sent a status yet.
    case noStatusYet
    /// No accepted share, and no Crewlu Cloud connection.
    case notConnected
    /// The pilot stopped sharing with this device, which has forgotten the connection.
    case sharingEnded
    /// The read failed. The message says why, for the sync line.
    case failed(String)
}
