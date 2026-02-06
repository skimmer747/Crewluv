//
//  ContentView.swift
//  CrewLuv
//
//  Main view coordinator for CrewLuv app
//  100% free app - requires share invitation from Duty app pilot
//

import SwiftUI

struct ContentView: View {
    @State private var statusReceiver = PartnerStatusReceiver()

    var body: some View {
        NavigationStack {
            Group {
                if statusReceiver.isLoading {
                    LoadingView()
                } else if let status = statusReceiver.pilotStatus {
                    PilotStatusView(status: status)
                } else {
                    NoShareView()
                }
            }
            .navigationTitle("CrewLuv")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await statusReceiver.refresh()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.glass)
                    .disabled(statusReceiver.isLoading)
                }
            }
        }
        .refreshable {
            await statusReceiver.refresh()
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
    @State private var pastedURL = ""

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
                            description: "Your pilot needs the Duty app with Duty Plus subscription"
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

                    VStack(spacing: 8) {
                        Text("CrewLuv is 100% free")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Requires pilot to have Duty Plus subscription")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
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
        .alert("Paste Share Link", isPresented: $showPasteAlert) {
            TextField("Share URL", text: $pastedURL)
            Button("Cancel", role: .cancel) { }
            Button("Accept") {
                acceptShareFromURL()
            }
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

#Preview {
    ContentView()
}
