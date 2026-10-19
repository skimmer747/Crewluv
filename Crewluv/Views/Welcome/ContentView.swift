//
//  ContentView.swift
//  CrewLuve
//
//  Main view coordinator for CrewLuve app
//  100% free app - requires share invitation from Duty app pilot
//

import SwiftUI

struct ContentView: View {
    @State private var statusReceiver: PartnerStatusReceiver?
    @State private var showShareError = false
    @State private var showsHandOff = false
    @State private var disconnectQuestion: DisconnectQuestion?
    @Environment(CloudKitShareManager.self) private var shareManager
    @Environment(\.scenePhase) private var scenePhase
    private let joiner = PartnerJoiner.shared

    var body: some View {
        ZStack {
            mainContent

            if shareManager.isAcceptingShare {
                ProgressOverlay(title: "Accepting Share Invitation...")
            }
            if joiner.isConnecting, joiner.switchQuestion == nil {
                ProgressOverlay(title: "Connecting...")
            }
        }
        .onAppear {
            if statusReceiver == nil {
                statusReceiver = PartnerStatusReceiver(shareManager: shareManager)
            }
            statusReceiver?.startPeriodicCheck()
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
        .modifier(JoinAlerts(joiner: joiner))
        .onChange(of: joiner.isConnecting) { _, isConnecting in
            // A link tapped in the demo leaves the demo first (partner links piece 4 spec §7.2).
            if isConnecting, statusReceiver?.isInDemoMode == true {
                statusReceiver?.exitDemoMode()
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
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            iPadStatusLayout(status: status, receiver: receiver)
                        } else {
                            PilotStatusView(
                                status: status,
                                lastSyncTime: receiver.lastSyncTime,
                                lastSyncError: receiver.lastSyncError,
                                isSyncing: receiver.isSyncing,
                                isInDemoMode: receiver.isInDemoMode,
                                isOnCrewluCloud: receiver.isOnCrewluCloud,
                                onExitDemo: { receiver.exitDemoMode() },
                                connectionMenu: connectionMenu(for: receiver),
                                onRefresh: { Task { await receiver.refresh() } }
                            )
                        }
                    } else if receiver.isWaitingForFirstUpdate {
                        // Scrollable, so pull-to-refresh keeps looking (partner links piece 4 spec §7.7).
                        ScrollView {
                            LoadingView(text: "Waiting for your pilot's first update...")
                                .containerRelativeFrame([.horizontal, .vertical])
                        }
                    } else if receiver.hasAcceptedShare {
                        ConnectionErrorView(receiver: receiver)
                    } else {
                        WelcomeView(
                            sharingEndedWith: receiver.sharingEndedWith,
                            onTryDemo: { receiver.enterDemoMode() },
                            onJoin: { await joiner.join($0) },
                            onPaste: { LinkRouter.paste($0) }
                        )
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(receiver.pilotStatus != nil ? "Where's \(receiver.pilotStatus!.pilotFirstName)?" : "CrewLuve")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
            }
            .refreshable {
                await receiver.refresh()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    receiver.reResolve()
                    if !receiver.isSyncing {
                        Task { await receiver.refresh() }
                    }
                    receiver.startPeriodicCheck()
                    Task { await BackgroundRefreshManager.shared.scheduleNextRefresh() }
                    Task { await PushRegistrar.shared.appBecameActive() }
                } else {
                    receiver.stopPeriodicCheck()
                }
            }
            .sheet(isPresented: $showsHandOff) {
                HandOffSheet()
            }
            .modifier(DisconnectAlerts(question: $disconnectQuestion, onDisconnect: { await receiver.disconnect() }))
        } else {
            LoadingView()
        }
    }

    private func iPadStatusLayout(status: SharedPilotStatus, receiver: PartnerStatusReceiver) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                PilotStatusView(
                    status: status,
                    lastSyncTime: receiver.lastSyncTime,
                    lastSyncError: receiver.lastSyncError,
                    isSyncing: receiver.isSyncing,
                    isCompanionLayout: true,
                    isInDemoMode: receiver.isInDemoMode,
                    isOnCrewluCloud: receiver.isOnCrewluCloud,
                    onExitDemo: { receiver.exitDemoMode() },
                    connectionMenu: connectionMenu(for: receiver),
                    onRefresh: { Task { await receiver.refresh() } }
                )
                .frame(width: geometry.size.width * 0.4)

                Divider()

                EventTimelineView(status: status)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// The ••• menu, on Crewlu Cloud outside the demo (partner links piece 4 spec §7.5).
    private func connectionMenu(for receiver: PartnerStatusReceiver) -> ConnectionMenu? {
        guard receiver.isOnCrewluCloud, !receiver.isInDemoMode else { return nil }
        return ConnectionMenu(
            onUseOnAnotherDevice: { showsHandOff = true },
            onDisconnect: {
                disconnectQuestion = DisconnectQuestion(
                    pilot: receiver.pilotStatus?.pilotFirstName ?? "your pilot", deviceModel: UIDevice.current.model
                )
            }
        )
    }
}

// MARK: - Sync Debug View

struct SyncDebugView: View {
    let lastSyncTime: Date
    let lastSyncError: String?
    let isSyncing: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isSyncing {
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

#Preview {
    ContentView()
        .environment(CloudKitShareManager.shared)
}
