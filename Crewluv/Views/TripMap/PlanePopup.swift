//
//  PlanePopup.swift
//  CrewLuve
//
//  A plane's popup on the full-screen map (which plane design §3): its title, then a line or two, in the glass of the
//  map's buttons. It's part of the map's picture, which VoiceOver doesn't see, so VoiceOver doesn't see it either:
//  the pill and the facts say the same.
//

import SwiftUI

struct PlanePopup: View {
    /// The widest a popup is at the default text size, in points: its lines wrap beyond it. `TripMapPopupController`
    /// scales it with the text and proposes no more.
    static let widest: CGFloat = 240

    let words: PlanePopupWords

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(words.title)
                .fontWeight(.semibold)
            ForEach(Array(words.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .accessibilityHidden(true)
    }
}

#Preview {
    PlanePopup(words: PlanePopupWords(title: "UPS2963 · best guess",
                                      lines: ["Out of tracking range since 4:05 PM, so it's shown where it should be by now",
                                              "About 14 min ahead · lands about 6:58 PM"]))
        .frame(width: PlanePopup.widest)
        .padding()
        .background(.teal)
}
