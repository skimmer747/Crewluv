//
//  SharingEndedNote.swift
//  CrewLuve
//
//  The welcome screen's note when sharing with this device ended
//

import Foundation

/// The welcome screen's note when sharing with this device ended (partner links piece 4 spec §7.6):
/// that it ended, or, for a device left behind when another of this partner's devices moved to
/// Crewlu Cloud, how to follow it there (§7.7). On the pilot's own iCloud, how they can see their
/// status here again.
nonisolated struct SharingEndedNote: Equatable, Sendable {
    /// The pilot, as this partner saw them.
    let pilot: String
    /// Another of this partner's devices follows the pilot on Crewlu Cloud, so a code from it works here.
    let isLeftBehind: Bool
    /// This device read the pilot's own iCloud: it's the pilot's own Crewluve.
    var isPilotsOwn = false

    var text: String {
        if isLeftBehind {
            return "To keep seeing \(pilot)'s status here, type the code from CrewLuve on your other device."
        }
        return isPilotsOwn
            ? "Your partners now see your status through Crewlu Cloud. To see it here too, invite yourself from CrewLu's Settings → Partner Sharing."
            : "Sharing with \(pilot) has ended."
    }
}
