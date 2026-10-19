//
//  WelcomeView.swift
//  CrewLuve
//
//  The welcome screen: how to connect, by link or by code
//

import SwiftUI

/// The welcome screen (partner links piece 4 spec §7.4): today's three steps reworded for links,
/// the code from another device, Try Demo, and a small paste line for a link that opened a web page
/// instead. After sharing ends, a note at the top says so (§7.6).
struct WelcomeView: View {
    /// The pilot whose sharing with this device ended, for the note at the top.
    var sharingEndedWith: String?
    var onTryDemo: () -> Void
    /// Joins with a code. False when it didn't connect, so the boxes clear.
    var onJoin: (PartnerLink) async -> Bool
    /// Takes what was pasted into the paste box.
    var onPaste: (String) -> Void

    @State private var showsPasteBox = false

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 20) {
                VStack(spacing: 32) {
                    if let sharingEndedWith {
                        SharingEndedNote(pilot: sharingEndedWith)
                    }
                    header
                    steps
                    code
                    tryDemo
                    pasteLine
                }
                .padding()
            }
        }
        .pasteLinkBox(isPresented: $showsPasteBox, onPaste: onPaste)
    }

    private var header: some View {
        VStack(spacing: 32) {
            Image(systemName: "heart.circle")
                .font(.system(size: 80))
                .foregroundStyle(.red.gradient)

            VStack(spacing: 12) {
                Text("Welcome to CrewLuve")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Stay connected with your pilot")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var steps: some View {
        VStack(spacing: 16) {
            InstructionRow(number: "1", title: "Pilot Setup", description: "Your pilot needs the CrewLu app")
            InstructionRow(
                number: "2",
                title: "Invite Link",
                description: "Ask them to invite you from Settings → Partner Sharing. iMessage is best."
            )
            InstructionRow(
                number: "3",
                title: "Tap the Link",
                description: "Tap it on this \(UIDevice.current.model), and CrewLuve connects by itself"
            )
        }
        .padding(.horizontal, 32)
    }

    private var code: some View {
        VStack(spacing: 12) {
            Text("or type the code from CrewLuve on another device")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            CodeEntryView(onJoin: onJoin)
        }
        .padding(.horizontal, 32)
    }

    private var tryDemo: some View {
        Button(action: onTryDemo) {
            Label("Try Demo", systemImage: "play.circle")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .padding(.horizontal, 32)
    }

    private var pasteLine: some View {
        ViewThatFits {
            HStack(spacing: 4) {
                pasteQuestion
                pasteButton
            }
            VStack(spacing: 4) {
                pasteQuestion
                pasteButton
            }
        }
        .font(.footnote)
    }

    private var pasteQuestion: some View {
        Text("Link opened a web page instead?")
            .foregroundColor(.secondary)
    }

    private var pasteButton: some View {
        Button("Paste it here") { showsPasteBox = true }
    }
}

// MARK: - Sharing Ended Note

/// "Sharing with Alex has ended." at the top of the welcome screen, until the next connection.
private struct SharingEndedNote: View {
    let pilot: String

    var body: some View {
        Label {
            Text("Sharing with \(pilot) has ended.")
        } icon: {
            Image(systemName: "info.circle")
                .foregroundStyle(.orange)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
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

// MARK: - Paste Box

/// The paste box (spec §7.7), for a link that opened a web page instead of the app. It takes an
/// invite link, a code link or an iCloud share link.
private struct PasteLinkBox: ViewModifier {
    @Binding var isPresented: Bool
    let onPaste: (String) -> Void

    @State private var pasted = ""

    func body(content: Content) -> some View {
        content
            .alert("Paste Invite Link", isPresented: $isPresented) {
                TextField("Invite link", text: $pasted)
                Button("Cancel", role: .cancel) { pasted = "" }
                Button("Connect") {
                    onPaste(pasted)
                    pasted = ""
                }
            } message: {
                Text("Paste the invite link your pilot sent you.")
            }
    }
}

private extension View {
    func pasteLinkBox(isPresented: Binding<Bool>, onPaste: @escaping (String) -> Void) -> some View {
        modifier(PasteLinkBox(isPresented: isPresented, onPaste: onPaste))
    }
}
