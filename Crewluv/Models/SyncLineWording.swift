//
//  SyncLineWording.swift
//  CrewLuve
//
//  The sync line's words, on iCloud and on Crewlu Cloud
//

import Foundation

/// The sync line's words (partner links piece 4 spec §7.7). On iCloud they read as before; on
/// Crewlu Cloud they never mention iCloud.
nonisolated struct SyncLineWording {
    let isOnCrewluCloud: Bool

    /// The VoiceOver label of the "Synced" row.
    var syncLabel: String {
        isOnCrewluCloud ? "Last sync" : "iCloud sync"
    }

    /// A sync error as the line shows it.
    func error(_ message: String) -> String {
        let lowercased = message.lowercased()
        if lowercased.contains("network") || lowercased.contains("connection") || lowercased.contains("internet") {
            return "Sync failed — check your connection"
        }
        if !isOnCrewluCloud, lowercased.contains("not authenticated") || lowercased.contains("authentication") {
            return "Sync failed — sign into iCloud"
        }
        if !isOnCrewluCloud, lowercased.contains("timeout") || lowercased.contains("timed out") {
            return "Sync timed out — will retry"
        }
        return "Sync failed — will retry"
    }
}
