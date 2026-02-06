//
//  PilotStatusView.swift
//  CrewLuv
//
//  Displays pilot status with countdown, location, and trip progress
//

import SwiftUI
import Combine

struct PilotStatusView: View {
    let status: SharedPilotStatus

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 20) {
                VStack(spacing: 24) {
                    // Status Header - Shows pilot name + current state
                    StatusHeaderView(status: status)

                    // Countdown Timer (if not home)
                    if let homeTime = status.homeArrivalTime, !status.isHome {
                        CountdownCardView(
                            title: "Home In",
                            targetDate: homeTime,
                            icon: "house.fill",
                            color: .green
                        )
                    }

                    // Next Departure (if at home)
                    if status.isHome, let departureTime = status.nextDepartureTime {
                        CountdownCardView(
                            title: "Leaves In",
                            targetDate: departureTime,
                            icon: "airplane.departure",
                            color: .blue
                        )
                    }

                    // Location Card
                    LocationCardView(status: status)

                    // Trip Overview (if on trip)
                    if let dayNumber = status.tripDayNumber,
                       let totalDays = status.tripTotalDays {
                        TripProgressView(
                            dayNumber: dayNumber,
                            totalDays: totalDays,
                            upcomingCities: status.upcomingCities
                        )
                    }

                    // Last Updated
                    Text("Updated \(status.lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }
}

// MARK: - Status Header View

struct StatusHeaderView: View {
    let status: SharedPilotStatus

    var body: some View {
        VStack(spacing: 12) {
            Text(status.pilotFirstName)
                .font(.largeTitle)
                .fontWeight(.bold)

            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                Text(statusText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private var statusColor: Color {
        if status.isHome { return .green }
        if status.isInFlight { return .blue }
        return .orange
    }

    private var statusText: String {
        if status.isHome { return "Home" }
        if status.isInFlight { return "In Flight" }
        if status.isOnDuty { return "On Duty" }
        return "On Layover"
    }
}

// MARK: - Countdown Card View

struct CountdownCardView: View {
    let title: String
    let targetDate: Date
    let icon: String
    let color: Color

    @State private var timeRemaining: String = ""

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.primary)

            Text(timeRemaining)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
        .onAppear {
            updateTimeRemaining()
        }
    }

    private func updateTimeRemaining() {
        let interval = targetDate.timeIntervalSinceNow

        if interval <= 0 {
            timeRemaining = "Now!"
            return
        }

        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if days > 0 {
            timeRemaining = String(format: "%dd %02dh %02dm", days, hours, minutes)
        } else if hours > 0 {
            timeRemaining = String(format: "%dh %02dm", hours, minutes)
        } else {
            timeRemaining = String(format: "%dm", minutes)
        }
    }
}

// MARK: - Location Card View

struct LocationCardView: View {
    let status: SharedPilotStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                Text(status.currentCity ?? "Unknown Location")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            if let airport = status.currentAirport {
                HStack {
                    Image(systemName: "airplane")
                        .foregroundColor(.secondary)
                    Text(airport)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let localTime = status.localTimeAtPilot {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.secondary)
                    Text("Local time: \(localTime)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let timezone = status.currentTimezone {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.secondary)
                    Text(timezone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

// MARK: - Trip Progress View

struct TripProgressView: View {
    let dayNumber: Int
    let totalDays: Int
    let upcomingCities: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Day \(dayNumber) of \(totalDays)")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 10)
                        .cornerRadius(5)

                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat(dayNumber) / CGFloat(totalDays), height: 10)
                        .cornerRadius(5)
                }
            }
            .frame(height: 10)

            if !upcomingCities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Upcoming Cities")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(upcomingCities, id: \.self) { city in
                            Text(city)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .glassEffect(.regular, in: .capsule)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

#Preview {
    PilotStatusView(status: SharedPilotStatus(
        pilotId: "test",
        pilotFirstName: "Todd",
        isHome: false,
        isInFlight: true,
        isOnDuty: true,
        currentAirport: "SDF",
        currentCity: "Louisville",
        currentTimezone: "America/New_York",
        localTimeAtPilot: "3:45 PM",
        currentLatitude: 38.1746,
        currentLongitude: -85.7382,
        currentFlightNumber: "5X 123",
        currentFlightDeparture: "SDF",
        currentFlightArrival: "ANC",
        currentFlightDepartureTime: Date(),
        currentFlightArrivalTime: Date().addingTimeInterval(14400),
        homeArrivalTime: Date().addingTimeInterval(172800),
        nextDepartureTime: nil,
        nextFlightNumber: nil,
        nextFlightDestination: nil,
        currentTripId: "test123",
        tripDayNumber: 2,
        tripTotalDays: 4,
        upcomingCities: ["Anchorage", "Hong Kong", "Shanghai"],
        lastUpdated: Date(),
        appVersion: "1.0"
    ))
}
