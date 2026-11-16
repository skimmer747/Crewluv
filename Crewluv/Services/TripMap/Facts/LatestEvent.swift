//
//  LatestEvent.swift
//  CrewLuve
//
//  The newest event of the flight in the air, as the banner shows it large on the card and the full-screen map
//  (latest event design §1): what it was, and how long ago.
//

nonisolated struct LatestEvent: Equatable, Sendable {
    /// "Crossed into Canada", "Out over the Pacific", "Halfway" or "Closest to home, 35 mi".
    let title: String
    /// "12 min ago", "Just now", or "About 12 min ago" for a best guess. In a replay, its clock time: "10:37 AM".
    let when: String
    /// The banner as VoiceOver reads it, as its own sentence: "Latest: crossed into Canada, 12 minutes ago."
    let sentence: String
}
