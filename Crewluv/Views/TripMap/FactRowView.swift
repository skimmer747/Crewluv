//
//  FactRowView.swift
//  CrewLuve
//
//  One row of the facts (Stage 2 spec §6.3): a symbol, a title and a second line, which VoiceOver reads as one
//  sentence.
//

import SwiftUI

struct FactRowView: View {
    let row: FactRow

    @ScaledMetric(relativeTo: .subheadline) private var symbolWidth: CGFloat = 24

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: row.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: symbolWidth)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                if let detail = row.detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.sentence)
        .clockLabelHelp(for: [row.title, row.detail ?? ""].joined(separator: " "))
    }
}
