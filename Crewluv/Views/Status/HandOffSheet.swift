//
//  HandOffSheet.swift
//  CrewLuve
//
//  Use on Another Device: the code, its QR code and how long it lasts
//

import CoreImage.CIFilterBuiltins
import SwiftUI

/// Use on Another Device (partner links piece 4 spec §7.5): a code for another of this partner's
/// devices, made as the sheet opens. If the pilot has stopped sharing, the sheet closes (§7.6).
struct HandOffSheet: View {
    @State private var session = HandOffSession()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Use on Another Device")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .task { await session.makeCode() }
        .onChange(of: session.state) { _, state in
            if state == .sharingEnded {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch session.state {
        case .making, .sharingEnded:
            ProgressView()
        case .ready(let code):
            HandOffCodeView(code: code, onNewCode: makeCode)
        case .couldntMake:
            couldntMake
        }
    }

    private var couldntMake: some View {
        VStack(spacing: 20) {
            Text("Couldn't make a code. Check your connection and try again.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again", action: makeCode)
                .buttonStyle(.glassProminent)
        }
    }

    private func makeCode() {
        Task { await session.makeCode() }
    }
}

// MARK: - The Code

/// The code in two groups of three, a QR code of its link, and how long it lasts. At 0:00 the code
/// and QR code fade, and New Code asks for another, which replaces it.
private struct HandOffCodeView: View {
    let code: HandOffCode
    let onNewCode: () -> Void

    /// Made once per code: the countdown redraws every second.
    private let qrCode: UIImage?

    init(code: HandOffCode, onNewCode: @escaping () -> Void) {
        self.code = code
        self.onNewCode = onNewCode
        qrCode = Self.qrCode(for: code.link)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let hasExpired = code.hasExpired(at: context.date)
            VStack(spacing: 20) {
                codeAndQRCode
                    .opacity(hasExpired ? 0.25 : 1)
                    .animation(.easeInOut, value: hasExpired)

                Text(code.countdown(at: context.date))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                Text("On your other iPhone or iPad, open CrewLuve and type this code, or scan the QR code with its camera.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)

                if hasExpired {
                    Button("New Code", action: onNewCode)
                        .buttonStyle(.glassProminent)
                }
            }
        }
    }

    private var codeAndQRCode: some View {
        VStack(spacing: 20) {
            Text(code.grouped)
                .font(.system(size: 40, weight: .semibold, design: .monospaced))
                .textSelection(.enabled)

            if let qrCode {
                Image(uiImage: qrCode)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .accessibilityLabel("QR code for this code")
            }
        }
    }

    /// A QR code of `link`, made on the device with Core Image.
    private static func qrCode(for link: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(link.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let image = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: image)
    }
}
