//
//  NarrativeCardView.swift
//  CrewLuv
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
            Image(systemName: statusIcon)
                .font(.system(size: 28))
                .foregroundColor(statusColor)
                .frame(width: 36)

            narrativeText
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .onReceive(timer) { _ in
            now = Date()
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

    @ViewBuilder
    private var homeNarrative: some View {
        if let departureTime = status.nextDepartureTime, let dest = nextFlightCity() {
            Text("Home sweet home! Heads out for \(Text(dest).bold()) in \(countdownText(to: departureTime))")
        } else if let departureTime = status.nextDepartureTime {
            Text("Home sweet home! Heads out in \(countdownText(to: departureTime))")
        } else {
            Text("Home and relaxing — no trips on the horizon")
        }
    }

    @ViewBuilder
    private var inFlightNarrative: some View {
        if let dest = currentArrivalCity(), let flt = status.currentFlightNumber, let arrTime = status.currentFlightArrivalTime {
            Text("En route to \(Text(dest).bold()) on FLT \(flt) — landing in \(countdownText(to: arrTime))")
        } else if let dest = currentArrivalCity(), let arrTime = status.currentFlightArrivalTime {
            Text("En route to \(Text(dest).bold()) — landing in \(countdownText(to: arrTime))")
        } else if let dest = currentArrivalCity() {
            Text("En route to \(Text(dest).bold())")
        } else {
            Text("Currently in flight")
        }
    }

    @ViewBuilder
    private var turnNarrative: some View {
        if let city = status.currentCity, let dest = nextFlightCity(), let nextTime = nextFlightDepartureTime() {
            Text("Quick turn in \(Text(city).bold()) — heading to \(Text(dest).bold()) in \(countdownText(to: nextTime))")
        } else if let city = status.currentCity, let nextTime = nextFlightDepartureTime() {
            Text("Quick turn in \(Text(city).bold()) — next flight in \(countdownText(to: nextTime))")
        } else if let city = status.currentCity {
            Text("Quick turn in \(Text(city).bold())")
        } else {
            Text("Quick turn between flights")
        }
    }

    @ViewBuilder
    private var layoverNarrative: some View {
        if let city = status.currentCity, let dest = nextFlightCity(), let nextTime = nextFlightDepartureTime() {
            Text("Layover in \(Text(city).bold()) — next flight to \(Text(dest).bold()) in \(countdownText(to: nextTime))")
        } else if let city = status.currentCity, let nextTime = nextFlightDepartureTime() {
            Text("Layover in \(Text(city).bold()) — next flight in \(countdownText(to: nextTime))")
        } else if let city = status.currentCity {
            Text("Layover in \(Text(city).bold())")
        } else {
            Text("On a layover")
        }
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

        let formatted: String
        if days > 0 {
            formatted = "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            formatted = "\(hours)h \(minutes)m"
        } else {
            formatted = "\(minutes)m"
        }
        return Text(formatted).bold().foregroundColor(statusColor)
    }

    // MARK: - City Name Helpers

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
        let legs = status.tripLegs
        if !legs.isEmpty {
            let nextFlight = legs.first(where: { (leg: TripLeg) in
                leg.type == .flight && leg.startTime > now
            })
            if let city = nextFlight?.arrivalCity, !city.isEmpty {
                return city
            }
        }
        return status.nextFlightDestination
    }

    private func nextFlightDepartureTime() -> Date? {
        let legs = status.tripLegs
        if !legs.isEmpty {
            let nextFlight = legs.first(where: { (leg: TripLeg) in
                leg.type == .flight && leg.startTime > now
            })
            if let time = nextFlight?.startTime {
                return time
            }
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
