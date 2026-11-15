//
//  FactsBody.swift
//  CrewLuve
//
//  The facts below the headline and timeline (Stage 2 spec §5): the rows, then the trip so far and the footer. The
//  sheet scrolls it with its header; the side panel scrolls it between its headline and its timeline.
//

import SwiftUI

struct FactsBody: View {
    let rows: [FactRow]
    let tripSoFar: TripSoFar

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        if row.id != rows.first?.id {
                            Divider()
                        }
                        FactRowView(row: row)
                    }
                }
            }
            TripSoFarList(tripSoFar: tripSoFar)
            FactsFooter(showsWeather: rows.contains(where: \.hasWeather))
        }
    }
}
