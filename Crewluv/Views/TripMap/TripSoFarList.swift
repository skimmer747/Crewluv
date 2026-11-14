//
//  TripSoFarList.swift
//  CrewLuve
//
//  The facts dragged all the way up (Stage 2 spec §5.2): each started flight's milestones under its name, newest
//  flight first, then the trip's totals.
//

import SwiftUI

struct TripSoFarList: View {
    let tripSoFar: TripSoFar

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(tripSoFar.flights) { flight in
                section(flight.title, lines: flight.milestones)
            }
            if let totals = tripSoFar.totals {
                section(tripSoFar.totalsTitle, lines: [totals])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section(_ title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.subheadline)
            }
        }
    }
}
