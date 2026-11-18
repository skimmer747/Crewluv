//
//  TripSoFarList.swift
//  CrewLuve
//
//  The facts dragged all the way up (Stage 2 spec §5.2; best guesses design §3, §4): each flight's events under its
//  name, newest first, then the trip's totals. The flight between its gates has a border and a tag, so it stands
//  out from the flights before it. A best guess is drawn lighter, and slanted.
//

import SwiftUI

struct TripSoFarList: View {
    let tripSoFar: TripSoFar

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(tripSoFar.flights) { flight in
                if let tag = flight.tag {
                    inTheAir(flight, tag: tag)
                } else {
                    section(flight.title, events: flight.events)
                }
            }
            if let totals = tripSoFar.totals {
                section(tripSoFar.totalsTitle, events: [TripSoFar.Event(text: totals, isEstimate: false)])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The flight between its gates: a border around it, with its tag beside its name, or under it where the
    /// text is too large for one line.
    private func inTheAir(_ flight: TripSoFar.Flight, tag: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    title(flight.title)
                    Spacer(minLength: 8)
                    tagLabel(tag)
                }
                VStack(alignment: .leading, spacing: 4) {
                    title(flight.title)
                    tagLabel(tag)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            lines(flight.events)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor, lineWidth: 1.5)
        }
    }

    private func section(_ name: String, events: [TripSoFar.Event]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            title(name)
                .accessibilityAddTraits(.isHeader)
            lines(events)
        }
    }

    private func title(_ name: String) -> some View {
        Text(name)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func tagLabel(_ tag: String) -> some View {
        Text(tag)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.15), in: .capsule)
    }

    private func lines(_ events: [TripSoFar.Event]) -> some View {
        // Each line by its place among its flight's events: a new event at the top doesn't make every line below a
        // new one.
        ForEach(events) { event in
            Text(event.text)
                .font(.subheadline)
                .italic(event.isEstimate)
                .foregroundStyle(event.isEstimate ? .secondary : .primary)
        }
    }
}
