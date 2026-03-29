//
//  TimelineRowView.swift
//  CrewLuve
//
//  Simplified timeline row for the partner schedule view
//

import SwiftUI

struct TimelineRowView: View {
    let leg: TripLeg
    var homeAirportCode: String?
    var isUpNext: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private var isHomebound: Bool {
        guard leg.type == .flight,
              let home = homeAirportCode, !home.isEmpty,
              let arrival = leg.arrivalAirport
        else { return false }
        return arrival.caseInsensitiveCompare(home) == .orderedSame
    }

    private var staticIconName: String {
        switch leg.type {
        case .flight:
            if leg.airlineCode != nil {
                return AirlineBranding.symbolName(for: leg.airlineCode)
            }
            return leg.tripId == nil ? "figure.seated.seatbelt" : "airplane"
        case .turn:       return "clock.arrow.circlepath"
        case .layover:    return "bed.double.fill"
        case .home:       return "house.fill"
        case .reserve:    return "clock.badge.questionmark"
        case .hotStandby: return "bolt.fill"
        case .event:      return "book.fill"
        default:          return "clock"
        }
    }

    var body: some View {
        // TimelineView drives periodic re-evaluation so isActive (and thus pulse + border)
        // stay correct as time passes, without relying on other view updates.
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            let now = context.date
            let isActive = leg.startTime <= now && now <= leg.endTime

            HStack(spacing: 12) {
                // Icon circle (symbolEffect animates based on active state)
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: staticIconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(iconColor)
                        .symbolEffect(.pulse, isActive: isActive)
                }

                // Title + subtitle (static)
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

                // Duration / countdown (dynamic — updates every second)
                CountdownText(leg: leg, activeColor: iconColor, isUpNext: isUpNext)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
            .overlay(borderOverlay(isActive: isActive))
            .overlay(alignment: .topTrailing) {
                if isUpNext, !isActive {
                    upNextBadge
                }
            }
            .accessibilityHint(
                isUpNext ? "Up next event" : (isHomebound ? "Arriving at home airport" : "")
            )
        }
    }

    // MARK: - Border

    @ViewBuilder
    private func borderOverlay(isActive: Bool) -> some View {
        if isActive {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    (isHomebound ? Color.green : iconColor).opacity(0.5),
                    lineWidth: 2
                )
        } else if isUpNext {
            RotatingGradientBorder(cornerRadius: 14, lineWidth: 2)
        } else if isHomebound {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.green.opacity(0.5), lineWidth: 2)
        }
    }

    // MARK: - Up Next Badge

    private var upNextBadge: some View {
        Text("UP NEXT")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.red, in: Capsule())
            .padding(.top, 6)
            .padding(.trailing, 8)
    }

    // MARK: - Icon

    private func iconName(isActive: Bool) -> String {
        switch leg.type {
        case .flight:
            if leg.airlineCode != nil {
                return AirlineBranding.symbolName(for: leg.airlineCode)
            }
            if leg.tripId == nil { return "figure.seated.seatbelt" }
            return isActive ? "airplane.departure" : "airplane"
        case .turn:       return "clock.arrow.circlepath"
        case .layover:    return isActive ? "moon.zzz.fill" : "bed.double.fill"
        case .home:       return "house.fill"
        case .reserve:    return "clock.badge.questionmark"
        case .hotStandby: return "bolt.fill"
        case .event:      return "book.fill"
        default:          return "clock"
        }
    }

    private var iconColor: Color {
        switch leg.type {
        case .flight:
            if leg.airlineCode != nil {
                return AirlineBranding.color(for: leg.airlineCode, colorScheme: colorScheme)
            }
            if leg.tripId == nil { return .green }
            return .blue
        case .turn:       return .orange
        case .layover:    return .yellow
        case .home:       return .green
        case .reserve:    return .red
        case .hotStandby: return .orange
        case .event:      return .purple
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

        case .reserve:
            let prefix = leg.label ?? "Reserve"
            if let city = leg.city { return "\(prefix) in \(city)" }
            if let apt = leg.airportCode { return "\(prefix) at \(apt)" }
            return prefix

        case .hotStandby:
            let prefix = leg.label ?? "Hot Standby"
            if let city = leg.city { return "\(prefix) in \(city)" }
            if let apt = leg.airportCode { return "\(prefix) at \(apt)" }
            return prefix

        case .event:
            let prefix = leg.label ?? "Training"
            if let city = leg.city { return "\(prefix) in \(city)" }
            if let apt = leg.airportCode { return "\(prefix) at \(apt)" }
            return prefix

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
        fmt.locale = Locale(identifier: "en_US_POSIX")
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

}

// MARK: - Countdown (isolated TimelineView to prevent layout propagation)

private struct CountdownText: View {
    let leg: TripLeg
    let activeColor: Color
    var isUpNext: Bool = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let isActive = leg.startTime <= now && now <= leg.endTime
            let showUpNext = isUpNext && !isActive && now < leg.startTime
            VStack(alignment: .trailing, spacing: 2) {
                Text(label(isActive: isActive, showUpNext: showUpNext))
                    .font(.system(size: 9))
                    .foregroundColor(showUpNext ? .cyan : .secondary)
                Text(durationText(now: now, showUpNext: showUpNext))
                    .font(.system(size: 11))
                    .fontWeight(isActive || showUpNext ? .semibold : .regular)
                    .foregroundColor(
                        showUpNext ? .cyan : (isActive ? activeColor : .secondary)
                    )
                    .monospacedDigit()
            }
        }
        .frame(minWidth: 56, alignment: .trailing)
    }

    private func label(isActive: Bool, showUpNext: Bool) -> String {
        if isActive { return "Ends in" }
        if showUpNext { return "Starts in" }
        return "Duration"
    }

    private func durationText(now: Date, showUpNext: Bool) -> String {
        let isActive = leg.startTime <= now && now <= leg.endTime
        let interval: TimeInterval
        if isActive {
            interval = leg.endTime.timeIntervalSince(now)
        } else if showUpNext {
            interval = leg.startTime.timeIntervalSince(now)
        } else {
            interval = leg.endTime.timeIntervalSince(leg.startTime)
        }
        return formattedDuration(max(interval, 0), showSeconds: isActive || showUpNext)
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
