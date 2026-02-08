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
                    if let homeTime = status.homeArrivalTime, status.displayStatus != "Home" {
                        CountdownCardView(
                            title: "Home In",
                            targetDate: homeTime,
                            icon: "house.fill",
                            color: .green
                        )
                    } else if status.displayStatus != "Home",
                              let dayNumber = status.tripDayNumber,
                              let totalDays = status.tripTotalDays {
                        EstimatedReturnCardView(
                            tripDayNumber: dayNumber,
                            tripTotalDays: totalDays
                        )
                    }

                    // Next Departure (if at home)
                    if status.displayStatus == "Home", let departureTime = status.nextDepartureTime {
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
                    if status.displayStatus != "Home",
                       let dayNumber = status.tripDayNumber,
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

    @State private var currentTime = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

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
        .onReceive(timer) { time in
            currentTime = time
            // This will trigger view refresh and recompute status
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

    private var statusText: String {
        return status.displayStatus
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

            formattedTimeText
                .lineLimit(1)
                .minimumScaleFactor(0.5)
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

    private var formattedTimeText: Text {
        if timeRemaining == "Now!" {
            return Text(timeRemaining)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        
        var attributedString = AttributedString()
        let components = timeRemaining.split(separator: " ")
        
        for (index, component) in components.enumerated() {
            let str = String(component)
            
            // Find where the unit letter starts (d, h, or m)
            if let unitIndex = str.firstIndex(where: { $0.isLetter }) {
                let number = String(str[..<unitIndex])
                let unit = String(str[unitIndex...])
                
                // Add the number in large, colored font
                var numberAttr = AttributedString(number)
                numberAttr.font = .system(size: 52, weight: .bold, design: .rounded)
                numberAttr.foregroundColor = color
                attributedString.append(numberAttr)
                
                // Add the unit in smaller, primary color font
                var unitAttr = AttributedString(unit)
                unitAttr.font = .system(size: 32, weight: .medium, design: .rounded)
                unitAttr.foregroundColor = .primary
                attributedString.append(unitAttr)
                
                // Add space between components
                if index < components.count - 1 {
                    attributedString.append(AttributedString("  "))
                }
            }
        }
        
        return Text(attributedString)
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
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var liveLocalTime: String = ""
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        if status.displayStatus == "In Flight" {
            inFlightView
        } else {
            standardLocationView
        }
    }
    
    // MARK: - In-Flight View (Widget Style)
    
    private var inFlightView: some View {
        VStack(spacing: 0) {
            // Flight route display with gradient background
            ZStack {
                // Background gradient
                flightGradient
                
                // Route information
                HStack(spacing: 12) {
                    // Departure
                    VStack(spacing: 4) {
                        Text(status.currentFlightDeparture ?? "---")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(primaryTextColor)
                        
                        if let depTime = status.currentFlightDepartureTime {
                            Text(formatFlightTime(depTime))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                    
                    Spacer()
                    
                    // Arrow with flight progress
                    Image(systemName: "airplane")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(urgencyColor)
                    
                    Spacer()
                    
                    // Arrival
                    VStack(spacing: 4) {
                        Text(status.currentFlightArrival ?? "---")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(primaryTextColor)
                        
                        if let arrTime = status.currentFlightArrivalTime {
                            Text(formatFlightTime(arrTime))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(height: 110)
            
            // Info bar (matching widget style)
            HStack(spacing: 0) {
                // Left: Flight info
                VStack(alignment: .leading, spacing: 2) {
                    if let flightNumber = status.currentFlightNumber {
                        Text("FLT \(flightNumber)")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(primaryTextColor)
                    }
                    
                    Text(status.currentCity ?? "In Flight")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
                
                Spacer()
                
                // Right: Local time at current position
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                        Text(liveLocalTime)
                            .font(.system(size: 16, weight: .semibold))
                            .monospacedDigit()
                    }
                    .foregroundColor(primaryTextColor)
                    
                    if let airport = status.currentAirport {
                        Text(airport)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(infoBarBackground)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .onReceive(timer) { _ in
            updateLiveLocalTime()
        }
        .onAppear {
            updateLiveLocalTime()
        }
    }
    
    // MARK: - Standard Location View (Not In Flight)
    
    private var standardLocationView: some View {
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

            if status.currentTimezone != nil {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.secondary)
                    Text("Local time: \(liveLocalTime)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
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
        .onReceive(timer) { _ in
            updateLiveLocalTime()
        }
        .onAppear {
            updateLiveLocalTime()
        }
    }
    
    // MARK: - Helper Properties
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 0.1, green: 0.15, blue: 0.25)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .gray : Color(red: 0.3, green: 0.38, blue: 0.5)
    }
    
    private var urgencyColor: Color {
        guard let arrivalTime = status.currentFlightArrivalTime else {
            return colorScheme == .dark ? .yellow : Color(red: 0.1, green: 0.2, blue: 0.5)
        }
        
        let timeRemaining = arrivalTime.timeIntervalSince(Date())
        
        if colorScheme == .light {
            if timeRemaining <= 0 {
                return Color(red: 0.4, green: 0.4, blue: 0.4)
            } else if timeRemaining <= 900 {
                return Color(red: 0.0, green: 0.6, blue: 0.0)
            } else if timeRemaining <= 3600 {
                return Color(red: 0.8, green: 0.0, blue: 0.0)
            } else if timeRemaining <= 7200 {
                return Color(red: 0.9, green: 0.5, blue: 0.0)
            } else {
                return Color(red: 0.1, green: 0.2, blue: 0.5)
            }
        } else {
            if timeRemaining <= 0 {
                return .gray
            } else if timeRemaining <= 900 {
                return .green
            } else if timeRemaining <= 3600 {
                return .red
            } else if timeRemaining <= 7200 {
                return .orange
            } else {
                return .yellow
            }
        }
    }
    
    private var flightGradient: LinearGradient {
        let dayColors: [Color] = colorScheme == .dark ? [
            Color(red: 0.12, green: 0.20, blue: 0.35),
            Color(red: 0.08, green: 0.14, blue: 0.28)
        ] : [
            Color(red: 0.80, green: 0.90, blue: 0.98),
            Color(red: 0.70, green: 0.84, blue: 0.96)
        ]
        
        return LinearGradient(colors: dayColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private var infoBarBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.08, green: 0.12, blue: 0.25).opacity(0.6)
            : Color(red: 0.65, green: 0.78, blue: 0.90).opacity(0.6)
    }
    
    // MARK: - Helper Methods
    
    private func formatFlightTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        if let timezone = status.currentTimezone,
           let tz = TimeZone(identifier: timezone) {
            formatter.timeZone = tz
        }
        return formatter.string(from: date) + "L"
    }
    
    private func updateLiveLocalTime() {
        guard let timezoneIdentifier = status.currentTimezone,
              let timezone = TimeZone(identifier: timezoneIdentifier) else {
            liveLocalTime = status.localTimeAtPilot ?? ""
            return
        }
        
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        liveLocalTime = formatter.string(from: Date())
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
        displayStatus: "In Flight",
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
