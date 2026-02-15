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
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let isActive = leg.startTime <= now && now <= leg.endTime

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

                // Duration / countdown
                Text(durationText(now: now))
                    .font(.caption)
                    .fontWeight(isActive ? .semibold : .regular)
                    .foregroundColor(isActive ? iconColor : .secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }
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

    // Thread-safe cache of DateFormatters keyed by timezone identifier.
    // DateFormatter is expensive to create, so we cache one per timezone.
    // NSLock protects the dictionary from concurrent access.
    private static var formatterCache: [String: DateFormatter] = [:]
    private static let formatterLock = NSLock()

    /// Returns a cached DateFormatter configured for "h:mm a" in the given timezone.
    /// Creates and caches a new one if none exists yet for that timezone.
    private static func formatter(for timeZone: TimeZone) -> DateFormatter {
        let key = timeZone.identifier
        formatterLock.lock()
        defer { formatterLock.unlock() }

        if let cached = formatterCache[key] {
            return cached
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"
        fmt.timeZone = timeZone
        formatterCache[key] = fmt
        return fmt
    }

    private var subtitle: String {
        let tz = TimeZone.current
        let fmt = Self.formatter(for: tz)
        let tzAbbr = (tz.abbreviation() ?? "").lowercased()
        let start = fmt.string(from: leg.startTime).lowercased()
        let end = fmt.string(from: leg.endTime).lowercased()
        return "\(start) \(tzAbbr) – \(end) \(tzAbbr)"
    }

    // MARK: - Duration

    private func durationText(now: Date) -> String {
        let isActive = leg.startTime <= now && now <= leg.endTime
        let interval = isActive
            ? leg.endTime.timeIntervalSince(now)
            : leg.endTime.timeIntervalSince(leg.startTime)
        return formattedDuration(max(interval, 0), showSeconds: isActive)
    }

    private func formattedDuration(_ interval: TimeInterval, showSeconds: Bool = false) -> String {
        let total = Int(interval)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if days > 0 {
            return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        } else if hours > 0 {
            if showSeconds {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            }
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            if showSeconds {
                return String(format: "%d:%02d", minutes, seconds)
            }
            return "\(minutes)m"
        }
    }
}
