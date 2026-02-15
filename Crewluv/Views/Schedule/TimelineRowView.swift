//
//  TimelineRowView.swift
//  CrewLuv
//
//  Simplified timeline row for the partner schedule view
//

import SwiftUI

struct TimelineRowView: View {
    let leg: TripLeg

    var body: some View {
        HStack(spacing: 12) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // Title + subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    // MARK: - Icon

    private var iconName: String {
        switch leg.type {
        case .flight:     return "airplane"
        case .turn:       return "clock.arrow.circlepath"
        case .layover:    return "bed.double.fill"
        case .home:       return "house.fill"
        default:          return "clock"
        }
    }

    private var iconColor: Color {
        switch leg.type {
        case .flight:     return .green
        case .turn:       return .orange
        case .layover:    return .blue
        case .home:       return .green
        default:          return .gray
        }
    }

    // MARK: - Title

    private var title: String {
        switch leg.type {
        case .flight:
            let route = [leg.departureAirport, leg.arrivalAirport]
                .compactMap { $0 }
                .joined(separator: " → ")
            if let flt = leg.flightNumber {
                return route.isEmpty ? flt : "\(flt): \(route)"
            }
            return route.isEmpty ? "Flight" : route

        case .layover:
            if let city = leg.city { return "Layover in \(city)" }
            if let apt = leg.airportCode { return "Layover at \(apt)" }
            return "Layover"

        case .turn:
            if let city = leg.city { return "Turn in \(city)" }
            if let apt = leg.airportCode { return "Turn at \(apt)" }
            return "Turn"

        case .home:
            return "Home"

        default:
            return "On Duty"
        }
    }

    // MARK: - Subtitle (local times)

    private static let timeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt
    }()

    private var subtitle: String {
        let tz: TimeZone = leg.timezoneIdentifier
            .flatMap { TimeZone(identifier: $0) } ?? .current
        Self.timeFormatter.timeZone = tz
        let start = Self.timeFormatter.string(from: leg.startTime).lowercased()
        let end = Self.timeFormatter.string(from: leg.endTime).lowercased()
        return "\(start) – \(end)"
    }
}
