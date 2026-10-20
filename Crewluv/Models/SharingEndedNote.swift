//
//  SharingEndedNote.swift
//  CrewLuve
//
//  The welcome screen's note when sharing with this device ended
//

import Foundation

/// The welcome screen's note when sharing with this device ended (partner links piece 4 spec §7.6):
/// that it ended, or, for a device left behind when another of this partner's devices moved to
/// Crewlu Cloud, how to follow it there (§7.7).
nonisolated struct SharingEndedNote: Equatable, Sendable {
    /// The pilot, as this partner saw them.
    let pilot: String
    /// Another of this partner's devices follows the pilot on Crewlu Cloud, so a code from it works here.
    let isLeftBehind: Bool

    var text: String {
        isLeftBehind
            ? "To keep seeing \(pilot)'s status here, type the code from CrewLuve on your other device."
            : "Sharing with \(pilot) has ended."
    }
}
