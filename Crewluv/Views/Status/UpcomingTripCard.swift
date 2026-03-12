//
//  UpcomingTripCard.swift
//  Crewluv
//
//  Glass card showing upcoming trip details with city route visual
//

import SwiftUI

struct UpcomingTripCard: View {
    let trip: UpcomingTripInfo
    var showChevron: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header row: type badge + departure date + duration
            HStack(spacing: 10) {
                typeBadge

                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedDeparture)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(trip.durationDays) \(trip.durationDays == 1 ? "day" : "days")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }

            // City route visual
            if !displayRoute.isEmpty {
                cityRouteView
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }

    // MARK: - Type Badge

    private var typeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: typeIcon)
                .font(.caption2)
            Text(trip.tripType.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(typeColor, in: Capsule())
    }

    private var typeColor: Color {
        switch trip.tripType {
        case .line: return .blue
        case .reserve: return .red
        case .hotStandby: return .orange
        case .training: return .purple
        }
    }

    private var typeIcon: String {
        switch trip.tripType {
        case .line: return "airplane"
        case .reserve: return "clock.badge.questionmark"
        case .hotStandby: return "bolt.fill"
        case .training: return "book.fill"
        }
    }

    // MARK: - City Route Visual

    /// Cap route at 6 visible stops
    private var displayRoute: [String] {
        Array(trip.cityRoute.prefix(6))
    }

    private var cityRouteView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(displayRoute.enumerated()), id: \.offset) { index, code in
                    HStack(spacing: 0) {
                        // Dot + label
                        VStack(spacing: 4) {
                            Circle()
                                .fill(dotColor(for: index))
                                .frame(width: 10, height: 10)
                            Text(code)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(dotColor(for: index))
                        }

                        // Connecting line (except after last dot)
                        if index < displayRoute.count - 1 {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 24, height: 2)
                                .padding(.bottom, 18)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func dotColor(for index: Int) -> Color {
        // First and last dots are blue (home base), middle dots secondary
        if index == 0 || index == displayRoute.count - 1 {
            return .blue
        }
        return .secondary
    }

    // MARK: - Formatted Departure

    private var formattedDeparture: String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        timeFormatter.amSymbol = "am"
        timeFormatter.pmSymbol = "pm"
        let timeStr = timeFormatter.string(from: trip.departureDate)

        if calendar.isDateInToday(trip.departureDate) {
            return "Departs today at \(timeStr)"
        } else if calendar.isDateInTomorrow(trip.departureDate) {
            return "Departs tomorrow at \(timeStr)"
        } else {
            let weekday = trip.departureDate.formatted(.dateTime.weekday(.abbreviated))
            let dateStr = trip.departureDate.formatted(.dateTime.month(.abbreviated).day())
            return "Departs \(weekday) \(dateStr) at \(timeStr)"
        }
    }
}
