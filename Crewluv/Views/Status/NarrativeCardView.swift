//
//  NarrativeCardView.swift
//  CrewLuve
//
//  "What's happening now" narrative card with live countdown
//

import SwiftUI
import Combine

struct NarrativeCardView: View {
    let status: SharedPilotStatus

    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 14) {
            statusIconView

            narrativeText
                .font(.body)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .onReceive(timer) { _ in
            withAnimation(.snappy(duration: 0.3)) {
                now = Date()
            }
        }
    }

    // MARK: - Narrative Text

    @ViewBuilder
    private var narrativeText: some View {
        switch status.displayStatus {
        case "Home":
            homeNarrative
        case "In Flight":
            inFlightNarrative
        case "Turn":
            turnNarrative
        case "Layover":
            layoverNarrative
        default:
            Text("On duty")
        }
    }

    private var name: String { status.pilotFirstName }

    @ViewBuilder
    private var homeNarrative: some View {
        if let departureTime = status.nextDepartureTime, let dest = nextFlightCity() {
            Text("\(name) is home — heads to \(Text(dest).bold()) in \(countdownText(to: departureTime))")
        } else if let departureTime = status.nextDepartureTime {
            Text("\(name) is home — heads out in \(countdownText(to: departureTime))")
        } else {
            Text("\(name) is home and relaxing")
        }
    }

    @ViewBuilder
    private var inFlightNarrative: some View {
        if let dest = currentArrivalCity(), let flt = status.currentFlightNumber, let arrTime = status.currentFlightArrivalTime {
            Text("\(name) is flying to \(Text(dest).bold()) on FLT \(flt) — landing in \(countdownText(to: arrTime))")
        } else if let dest = currentArrivalCity(), let arrTime = status.currentFlightArrivalTime {
            Text("\(name) is flying to \(Text(dest).bold()) — landing in \(countdownText(to: arrTime))")
        } else if let dest = currentArrivalCity() {
            Text("\(name) is flying to \(Text(dest).bold())")
        } else {
            Text("\(name) is in flight")
        }
    }

    @ViewBuilder
    private var turnNarrative: some View {
        if let city = status.currentCity, let dest = nextFlightCity(), let nextTime = nextFlightDepartureTime() {
            Text("\(name) is in \(Text(city).bold()) — heading to \(Text(dest).bold()) in \(countdownText(to: nextTime))")
        } else if let city = status.currentCity, let nextTime = nextFlightDepartureTime() {
            Text("\(name) is in \(Text(city).bold()) — next flight in \(countdownText(to: nextTime))")
        } else if let city = status.currentCity {
            Text("\(name) is in \(Text(city).bold()) between flights")
        } else {
            Text("\(name) is between flights")
        }
    }

    @ViewBuilder
    private var layoverNarrative: some View {
        if let city = status.currentCity, let dest = nextFlightCity(), let nextTime = nextFlightDepartureTime() {
            Text("\(name) is laying over in \(Text(city).bold()) — flies to \(Text(dest).bold()) in \(countdownText(to: nextTime))")
        } else if let city = status.currentCity, let nextTime = nextFlightDepartureTime() {
            Text("\(name) is laying over in \(Text(city).bold()) — next flight in \(countdownText(to: nextTime))")
        } else if let city = status.currentCity {
            Text("\(name) is laying over in \(Text(city).bold())")
        } else {
            Text("\(name) is on a layover")
        }
    }

    // MARK: - Status Icon with Progress Ring

    private var statusIconView: some View {
        ZStack {
            if status.displayStatus == "Layover", let progress = layoverProgress {
                Circle()
                    .stroke(statusColor.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
            }

            Image(systemName: statusIcon)
                .font(.system(size: 28))
                .foregroundColor(statusColor)
        }
        .frame(width: 44)
    }

    private var layoverProgress: Double? {
        let legs = sortedTripLegs
        guard !legs.isEmpty else { return nil }
        guard let layover = legs.first(where: {
            $0.type == .layover && $0.startTime <= now && now < $0.endTime
        }) else { return nil }
        let total = layover.endTime.timeIntervalSince(layover.startTime)
        guard total > 0 else { return nil }
        let elapsed = now.timeIntervalSince(layover.startTime)
        return min(max(elapsed / total, 0), 1)
    }

    // MARK: - Countdown Formatting

    private func countdownText(to target: Date) -> Text {
        let interval = target.timeIntervalSince(now)
        guard interval > 0 else {
            return Text("now!").bold().foregroundColor(statusColor)
        }

        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        let formatted: String
        if days > 0 {
            formatted = "\(days)d \(hours)h \(minutes)m \(seconds)s"
        } else if hours > 0 {
            formatted = "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            formatted = "\(minutes)m \(seconds)s"
        } else {
            formatted = "\(seconds)s"
        }
        return Text(formatted).bold().foregroundColor(statusColor).monospacedDigit()
    }

    // MARK: - City Name Helpers

    /// Sorted trip legs by start time (ascending) for consistent processing
    /// This ensures all helper methods reference the same sorted order
    private var sortedTripLegs: [TripLeg] {
        status.tripLegs.sorted { $0.startTime < $1.startTime }
    }

    /// Finds the next flight leg after the current time
    /// Uses sortedTripLegs to ensure consistent results across all helper methods
    /// Returns the first flight leg where startTime > now
    private func nextFlight() -> TripLeg? {
        sortedTripLegs.first(where: { $0.type == .flight && $0.startTime > now })
    }

    private func currentArrivalCity() -> String? {
        let legs = status.tripLegs
        if !legs.isEmpty {
            let currentFlight = legs.first(where: { (leg: TripLeg) in
                leg.type == .flight && leg.startTime <= now && now < leg.endTime
            })
            if let city = currentFlight?.arrivalCity, !city.isEmpty {
                return city
            }
        }
        return status.currentFlightArrival
    }

    private func nextFlightCity() -> String? {
        let sorted = sortedTripLegs
        if !sorted.isEmpty {
            // Use the shared helper to get the next flight leg
            // This ensures consistency with nextFlightDepartureTime()
            let nextFlight = nextFlight()
            // Standalone jumpseat — chain through to the trip it connects to
            // If homeAirport is known, only chain if jumpseat departs from there
            if let js = nextFlight, js.tripId == nil,
               (status.homeAirportCode == nil || js.departureAirport == status.homeAirportCode),
               let jsArrival = js.arrivalAirport {
                if let tripFlight = sorted.first(where: {
                    $0.tripId != nil && $0.type == .flight &&
                    $0.startTime >= js.endTime &&
                    $0.departureAirport == jsArrival
                }), let city = tripFlight.arrivalCity, !city.isEmpty {
                    return city
                }
            }
            if let city = nextFlight?.arrivalCity, !city.isEmpty {
                return city
            }
        }
        return status.nextFlightDestination
    }

    private func nextFlightDepartureTime() -> Date? {
        // Use the shared helper to get the next flight leg
        // This ensures consistency with nextFlightCity() - both reference the same TripLeg instance
        if let nextFlight = nextFlight() {
            return nextFlight.startTime
        }
        return status.nextDepartureTime
    }

    // MARK: - Status Icon & Color

    private var statusIcon: String {
        switch status.displayStatus {
        case "Home": return "house.fill"
        case "In Flight": return "airplane"
        case "Turn": return "arrow.triangle.2.circlepath"
        case "Layover": return "bed.double.fill"
        default: return "circle.fill"
        }
    }

    private var statusColor: Color {
        switch status.displayStatus {
        case "Home": return .green
        case "In Flight": return .blue
        case "Turn": return .orange
        case "Layover": return .purple
        default: return .gray
        }
    }
}
