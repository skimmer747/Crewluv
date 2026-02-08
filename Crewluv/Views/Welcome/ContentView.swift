//
//  ContentView.swift
//  CrewLuv
//
//  Main view coordinator for CrewLuv app
//  100% free app - requires share invitation from Duty app pilot
//

import SwiftUI

struct ContentView: View {
    @State private var statusReceiver: PartnerStatusReceiver?
    @State private var showShareError = false
    @State private var showPasteShareAlert = false
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(CloudKitShareManager.self) private var shareManager

    var body: some View {
        Group {
            if !purchaseManager.hasUnlockedApp {
                // Show paywall if not purchased
                PaywallView()
            } else {
                // Show main app content if purchased
                ZStack {
                    mainContent

                    if shareManager.isAcceptingShare {
                        ShareAcceptingOverlay()
                    }
                }
            }
        }
        .onAppear {
            #if DEBUG
            purchaseManager.simulateUnlock()
            #endif
            if statusReceiver == nil {
                statusReceiver = PartnerStatusReceiver(shareManager: shareManager)
            }
        }
        .alert("Share Error", isPresented: $showShareError) {
            Button("OK") { shareManager.resetShareState() }
        } message: {
            if case .error(let msg) = shareManager.shareState {
                Text(msg)
            }
        }
        .onChange(of: shareManager.shareState) { _, newValue in
            if case .error = newValue {
                showShareError = true
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if let receiver = statusReceiver {
            NavigationStack {
                Group {
                    if receiver.isLoading {
                        LoadingView()
                    } else if let status = receiver.pilotStatus {
                        PilotStatusView(status: status)
                    } else {
                        NoShareView()
                    }
                }
                .navigationTitle("CrewLuv")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showPasteShareAlert = true
                        }) {
                            Image(systemName: "link.badge.plus")
                        }
                        .buttonStyle(.glass)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            Task {
                                await receiver.refresh()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.glass)
                        .disabled(receiver.isLoading)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if let lastSync = receiver.lastSyncTime {
                        SyncDebugView(
                            lastSyncTime: lastSync,
                            lastSyncError: receiver.lastSyncError,
                            isLoading: receiver.isLoading
                        )
                    }
                }
            }
            .refreshable {
                await receiver.refresh()
            }
            .pasteShareLinkAlert(isPresented: $showPasteShareAlert)
        } else {
            LoadingView()
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading pilot status...")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - No Share View

struct NoShareView: View {
    @State private var showPasteAlert = false

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 20) {
                VStack(spacing: 32) {
                    Image(systemName: "heart.circle")
                        .font(.system(size: 80))
                        .foregroundStyle(.red.gradient)

                    VStack(spacing: 12) {
                        Text("Welcome to CrewLuv")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Stay connected with your pilot")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 16) {
                        InstructionRow(
                            number: "1",
                            title: "Pilot Setup",
                            description: "Your pilot needs the Duty app to create a status share"
                        )

                        InstructionRow(
                            number: "2",
                            title: "Share Invitation",
                            description: "Ask them to go to Settings → Partner Sharing → Invite Partner"
                        )

                        InstructionRow(
                            number: "3",
                            title: "Accept & Connect",
                            description: "Accept the invitation and you'll see their status here"
                        )
                    }
                    .padding(.horizontal, 32)

                    VStack(spacing: 16) {
                        Button(action: {
                            showPasteAlert = true
                        }) {
                            Label("Paste Share Link", systemImage: "link")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .padding(.horizontal, 32)

                        Divider()

                        Button(action: {
                            CloudKitShareManager.shared.resetShareData()
                        }) {
                            Label("Reset Share Data", systemImage: "trash")
                                .font(.subheadline)
                        }
                        .buttonStyle(.glass)
                        .tint(.red)
                    }
                    .padding(.horizontal, 32)
                }
                .padding()
            }
        }
        .pasteShareLinkAlert(isPresented: $showPasteAlert)
    }
}

// MARK: - Instruction Row

struct InstructionRow: View {
    let number: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(.blue)
                    .frame(width: 32, height: 32)
                
                Text(number)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .glassEffect(.regular, in: .circle)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

// MARK: - Share Accepting Overlay

struct ShareAcceptingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Accepting Share Invitation...")
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

// MARK: - Sync Debug View

struct SyncDebugView: View {
    let lastSyncTime: Date
    let lastSyncError: String?
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                Text("Syncing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: lastSyncError == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(lastSyncError == nil ? .green : .orange)
                    .font(.caption)
                    .accessibilityLabel(lastSyncError == nil ? "Sync successful" : "Sync error")

                VStack(alignment: .leading, spacing: 2) {
                    Text("Last sync: \(lastSyncTime.formatted(date: .omitted, time: .standard))")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let error = lastSyncError {
                        Text(sanitizedErrorMessage(error))
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    /// Converts technical error strings into user-friendly messages
    private func sanitizedErrorMessage(_ error: String) -> String {
        let lowercased = error.lowercased()

        // Network-related errors
        if lowercased.contains("network") || lowercased.contains("connection") || lowercased.contains("internet") {
            return "Network unavailable"
        }

        // CloudKit-specific errors
        if lowercased.contains("not authenticated") || lowercased.contains("authentication") {
            return "Sign in required"
        }

        if lowercased.contains("permission") || lowercased.contains("not permitted") {
            return "Permission denied"
        }

        if lowercased.contains("zone not found") || lowercased.contains("share not found") {
            return "Share not found"
        }

        if lowercased.contains("quota") || lowercased.contains("storage") {
            return "Storage limit reached"
        }

        if lowercased.contains("timeout") || lowercased.contains("timed out") {
            return "Request timed out"
        }

        if lowercased.contains("server") || lowercased.contains("service unavailable") {
            return "Service unavailable"
        }

        // Generic fallback for any other errors
        return "Sync failed"
    }
}

// MARK: - Paste Share Link Modifier

struct PasteShareLinkModifier: ViewModifier {
    @Binding var isPresented: Bool
    @State private var pastedURL = ""

    func body(content: Content) -> some View {
        content
            .alert("Paste Share Link", isPresented: $isPresented) {
                TextField("Share URL", text: $pastedURL)
                Button("Cancel", role: .cancel) { }
                Button("Accept") { acceptShareFromURL() }
            } message: {
                Text("Paste the CloudKit share link from your pilot")
            }
    }

    private func acceptShareFromURL() {
        guard let url = URL(string: pastedURL) else {
            debugLog("[CrewLuv] Invalid URL: \(pastedURL)")
            return
        }

        debugLog("[CrewLuv] Manual share URL: \(url)")

        Task {
            do {
                try await CloudKitShareManager.shared.acceptShare(from: url)
                pastedURL = ""
            } catch {
                debugLog("[CrewLuv] ❌ Error accepting manual share: \(error)")
            }
        }
    }
}

extension View {
    func pasteShareLinkAlert(isPresented: Binding<Bool>) -> some View {
        modifier(PasteShareLinkModifier(isPresented: isPresented))
    }
}

#Preview {
    ContentView()
        .environment(PurchaseManager.shared)
        .environment(CloudKitShareManager.shared)
}
