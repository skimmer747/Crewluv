//
//  LoadingAndErrorViews.swift
//  CrewLuve
//
//  What shows instead of the status: loading, waiting, an error, or a moment's progress
//

import SwiftUI

// MARK: - Connection Error View

struct ConnectionErrorView: View {
    var receiver: PartnerStatusReceiver

    /// Peek at the receiver's error message to distinguish "share was revoked" from
    /// "iCloud unreachable." Keeps the view single-purpose without a separate component.
    private var isShareEnded: Bool {
        (receiver.errorMessage ?? "").lowercased().contains("sharing has ended")
    }

    /// On Crewlu Cloud the screen doesn't mention iCloud (partner links piece 4 spec §7.7).
    private var title: String {
        if isShareEnded {
            return "Sharing Ended"
        }
        return receiver.isOnCrewluCloud ? "Unable to Connect" : "Unable to Reach iCloud"
    }

    private var message: String {
        let checkConnection = "Check your connection and try again."
        return receiver.isOnCrewluCloud ? checkConnection : receiver.errorMessage ?? checkConnection
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: receiver.isOnCrewluCloud ? "wifi.slash" : "icloud.slash")
                .font(.system(size: 60))
                .foregroundStyle(.orange.gradient)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                Task { await receiver.refresh() }
            }) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(receiver.isSyncing)
            .padding(.horizontal, 48)
        }
        .padding()
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var text = "Loading pilot status..."

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Progress Overlay

/// A dimmed overlay with a spinner while something takes a moment: accepting an iCloud share, or
/// connecting with a link or code (partner links piece 4 spec §7.2).
struct ProgressOverlay: View {
    let title: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text("This may take a moment")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(40)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
    }
}
