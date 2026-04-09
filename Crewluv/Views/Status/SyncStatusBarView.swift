//
//  SyncStatusBarView.swift
//  CrewLuve
//
//  Live-ticking sync status bar with freshness indicators
//

import SwiftUI

// MARK: - Sync Freshness

private enum SyncFreshness {
    case fresh   // < 2 min
    case normal  // 2–5 min
    case stale   // 5–10 min
    case expired // > 10 min

    var color: Color {
        switch self {
        case .fresh:   .green
        case .normal:  .blue
        case .stale:   .orange
        case .expired: .red
        }
    }

    init(elapsed: TimeInterval) {
        switch elapsed {
        case ..<120:   self = .fresh
        case ..<300:   self = .normal
        case ..<600:   self = .stale
        default:       self = .expired
        }
    }
}

// MARK: - Sync Status Bar View

struct SyncStatusBarView: View {
    let pilotName: String
    let pilotUpdatedAt: Date
    let lastSyncTime: Date?
    let lastSyncError: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(at: context.date)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(at now: Date) -> some View {
        if let error = lastSyncError, lastSyncTime != nil {
            Label(friendlyError(error), systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                if let syncTime = lastSyncTime {
                    let syncElapsed = now.timeIntervalSince(syncTime)
                    syncRow(
                        icon: "icloud.fill",
                        text: agoText("Synced", elapsed: syncElapsed),
                        elapsed: syncElapsed,
                        label: "iCloud sync"
                    )
                }

                let pilotElapsed = now.timeIntervalSince(pilotUpdatedAt)
                syncRow(
                    icon: "arrow.up.circle.fill",
                    text: agoText("\(pilotName) sent", elapsed: pilotElapsed),
                    elapsed: pilotElapsed,
                    label: "\(pilotName)'s update"
                )
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Sync Row

    private func syncRow(icon: String, text: String, elapsed: TimeInterval, label: String) -> some View {
        let freshness = SyncFreshness(elapsed: elapsed)

        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(freshness.color)

            Text(text)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.3), value: Int(elapsed))
        }
        .accessibilityLabel("\(label): \(elapsedText(elapsed))")
    }

    // MARK: - Elapsed Text Formatting

    private func elapsedText(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))

        if seconds < 5 {
            return "now"
        }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours >= 24 {
            return pilotUpdatedAt.formatted(date: .abbreviated, time: .shortened)
        } else if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, secs)
        } else {
            return "\(secs)s"
        }
    }

    private func agoText(_ prefix: String, elapsed: TimeInterval) -> String {
        let text = elapsedText(elapsed)
        if text == "now" {
            return "\(prefix) just now"
        }
        return "\(prefix) \(text) ago"
    }

    // MARK: - Friendly Error

    private func friendlyError(_ error: String) -> String {
        let lowercased = error.lowercased()
        if lowercased.contains("network") || lowercased.contains("connection") || lowercased.contains("internet") {
            return "Sync failed — check your connection"
        }
        if lowercased.contains("not authenticated") || lowercased.contains("authentication") {
            return "Sync failed — sign into iCloud"
        }
        if lowercased.contains("timeout") || lowercased.contains("timed out") {
            return "Sync timed out — will retry"
        }
        return "Sync failed — will retry"
    }
}

// MARK: - Previews

#Preview("Fresh") {
    SyncStatusBarView(
        pilotName: "Todd",
        pilotUpdatedAt: Date().addingTimeInterval(-30),
        lastSyncTime: Date().addingTimeInterval(-15),
        lastSyncError: nil
    )
    .padding()
}

#Preview("Stale") {
    SyncStatusBarView(
        pilotName: "Todd",
        pilotUpdatedAt: Date().addingTimeInterval(-420),
        lastSyncTime: Date().addingTimeInterval(-360),
        lastSyncError: nil
    )
    .padding()
}

#Preview("Error") {
    SyncStatusBarView(
        pilotName: "Todd",
        pilotUpdatedAt: Date().addingTimeInterval(-120),
        lastSyncTime: Date().addingTimeInterval(-60),
        lastSyncError: "Network connection failed"
    )
    .padding()
}
