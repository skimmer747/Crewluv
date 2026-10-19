//
//  ConnectionMenu.swift
//  CrewLuve
//
//  The ••• menu: Use on Another Device and Disconnect
//

import SwiftUI

/// The ••• menu in the status screen's bottom row (partner links piece 4 spec §7.5), in Paste Share
/// Link's old place. It shows only on Crewlu Cloud, outside the demo.
struct ConnectionMenu: View {
    var onUseOnAnotherDevice: () -> Void
    var onDisconnect: () -> Void

    var body: some View {
        Menu {
            Button("Use on Another Device", systemImage: "qrcode", action: onUseOnAnotherDevice)
            Button("Disconnect", systemImage: "xmark.circle", role: .destructive, action: onDisconnect)
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("More")
    }
}

// MARK: - Disconnect's Alerts

/// Disconnect's question, and what it says when it can't (spec §7.5).
struct DisconnectAlerts: ViewModifier {
    @Binding var question: DisconnectQuestion?
    /// Leaves Crewlu Cloud. False when it couldn't be reached.
    let onDisconnect: () async -> Bool

    @State private var showsFailure = false

    func body(content: Content) -> some View {
        content
            .alert(question?.title ?? "", isPresented: isAsking, presenting: question) { _ in
                Button("Disconnect", role: .destructive, action: disconnect)
                Button("Cancel", role: .cancel) {}
            } message: { question in
                Text(question.message)
            }
            .alert(DisconnectQuestion.failureTitle, isPresented: $showsFailure) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(DisconnectQuestion.failureMessage)
            }
    }

    private var isAsking: Binding<Bool> {
        Binding(get: { question != nil }, set: { if !$0 { question = nil } })
    }

    private func disconnect() {
        Task {
            if await !onDisconnect() {
                showsFailure = true
            }
        }
    }
}
