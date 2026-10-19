//
//  CodeEntryView.swift
//  CrewLuve
//
//  The six boxes for a code from another device
//

import SwiftUI

/// The code from another device (partner links piece 4 spec §7.4): one text field drawn as six
/// boxes. It takes letters and digits in any case and shows them in capitals. The sixth character
/// sends the code, and a pasted code fills the boxes. A code that fails clears them.
struct CodeEntryView: View {
    /// Joins with the code. False when it didn't connect.
    var onJoin: (PartnerLink) async -> Bool

    @State private var code = ""
    @State private var isJoining = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            field
            boxes
        }
        .contentShape(.rect)
        .onTapGesture { isFocused = true }
    }

    /// The field takes the typing and pasting; the boxes show it.
    private var field: some View {
        TextField("", text: $code)
            .focused($isFocused)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .foregroundStyle(.clear)
            .tint(.clear)
            .disabled(isJoining)
            .accessibilityLabel("Code from another device")
            .onChange(of: code) { _, typed in
                let kept = PartnerLink.codeBoxes(typed)
                if kept != typed {
                    code = kept
                } else if kept.count == 6 {
                    join(kept)
                }
            }
    }

    private var boxes: some View {
        HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { index in
                box(at: index)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func box(at index: Int) -> some View {
        let characters = Array(code)
        let isNext = isFocused && index == min(characters.count, 5)
        return Text(index < characters.count ? String(characters[index]) : " ")
            .font(.title2.monospaced().weight(.semibold))
            .frame(width: 40, height: 50)
            .glassEffect(.regular, in: .rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.tint, lineWidth: isNext ? 2 : 0)
            }
    }

    private func join(_ code: String) {
        isJoining = true
        Task {
            if await !onJoin(.code(code)) {
                self.code = ""
            }
            isJoining = false
        }
    }
}
