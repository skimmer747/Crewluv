//
//  PilotStatusView.swift
//  CrewLuv
//
//  Displays pilot status with countdown, location, and trip progress
//

import SwiftUI
import Combine

struct HomeCardBoundsKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

struct PilotStatusView: View {
    let status: SharedPilotStatus
    var lastSyncTime: Date? = nil
    var lastSyncError: String? = nil
    var isSyncing: Bool = false
    var onPasteShareLink: (() -> Void)? = nil
    var onRefresh: (() -> Void)? = nil

    private var scheduleChevron: some View {
        HStack(spacing: 2) {
            Text("Schedule")
                .font(.caption2)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundColor(.secondary)
        .padding(.trailing, 12)
        .padding(.top, 12)
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 20) {
                VStack(spacing: 24) {
                    // Narrative Card - "What's happening now"
                    NarrativeCardView(status: status)

                    // Countdown Timer (if not home) — taps open schedule
                    if let homeTime = status.homeArrivalTime, status.displayStatus != "Home" {
                        NavigationLink(destination: EventTimelineView(status: status)) {
                            CountdownCardView(
                                title: "Home In",
                                targetDate: homeTime,
                                icon: "house.fill",
                                color: .green
                            )
                            .anchorPreference(key: HomeCardBoundsKey.self, value: .bounds) { $0 }
                            .overlay(alignment: .topTrailing) {
                                scheduleChevron
                            }
                        }
                        .buttonStyle(.plain)
                    } else if status.displayStatus != "Home",
                              let dayNumber = status.tripDayNumber,
                              let totalDays = status.tripTotalDays {
                        NavigationLink(destination: EventTimelineView(status: status)) {
                            EstimatedReturnCardView(
                                tripDayNumber: dayNumber,
                                tripTotalDays: totalDays
                            )
                            .overlay(alignment: .topTrailing) {
                                scheduleChevron
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Next Departure (if at home) — taps open schedule
                    if status.displayStatus == "Home", let departureTime = status.nextDepartureTime {
                        NavigationLink(destination: EventTimelineView(status: status)) {
                            CountdownCardView(
                                title: "Leaves In",
                                targetDate: departureTime,
                                icon: "airplane.departure",
                                color: .blue
                            )
                            .overlay(alignment: .topTrailing) {
                                scheduleChevron
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Schedule card when home with no departure time
                    if status.displayStatus == "Home" && status.nextDepartureTime == nil {
                        NavigationLink(destination: EventTimelineView(status: status)) {
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text("View Schedule")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                        }
                        .buttonStyle(.plain)
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

                    // Sync explanation with action buttons
                    HStack {
                        if let onPasteShareLink {
                            Button(action: onPasteShareLink) {
                                Image(systemName: "link.badge.plus")
                                    .font(.caption)
                            }
                            .buttonStyle(.glass)
                        }

                        Spacer()

                        SyncExplanationView(
                            pilotName: status.pilotFirstName,
                            pilotUpdatedAt: status.lastUpdated,
                            lastSyncTime: lastSyncTime,
                            lastSyncError: lastSyncError
                        )

                        Spacer()

                        if let onRefresh {
                            Button(action: onRefresh) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.glass)
                            .disabled(isSyncing)
                        }
                    }
                }
                .padding()
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .overlayPreferenceValue(HomeCardBoundsKey.self) { anchor in
            if let anchor,
               let homeTime = status.homeArrivalTime,
               homeTime.timeIntervalSinceNow < 86400 && homeTime.timeIntervalSinceNow > 0 {
                GeometryReader { proxy in
                    let rect = proxy[anchor]
                    CelebrationFigureView()
                        .position(x: rect.maxX - 24, y: rect.minY + 12)
                }
                .allowsHitTesting(false)
            }
        }
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
            // Flight route map visualization
            FlightRouteMapView(status: status)
            
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
                
                // Right: Local time at arrival airport
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                        Text(liveLocalTime)
                            .font(.system(size: 16, weight: .semibold))
                            .monospacedDigit()
                    }
                    .foregroundColor(primaryTextColor)

                    if let airport = status.currentFlightArrival {
                        Text(airport)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(infoBarBackground)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: 0))
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
                    Text("Local time: \(liveLocalTime) \(timezoneAbbreviation)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
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
    
    private var infoBarBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.08, green: 0.12, blue: 0.25).opacity(0.6)
            : Color(red: 0.65, green: 0.78, blue: 0.90).opacity(0.6)
    }
    
    private var timezoneAbbreviation: String {
        guard let id = status.currentTimezone,
              let tz = TimeZone(identifier: id) else { return "" }
        return tz.abbreviation(for: Date())?.lowercased() ?? ""
    }

    // MARK: - Helper Methods

    private func updateLiveLocalTime() {
        // When in-flight, show arrival airport's local time; otherwise departure/current
        let tzId = status.isInFlight
            ? (status.currentFlightArrivalTimezone ?? status.currentTimezone)
            : status.currentTimezone

        guard let timezoneIdentifier = tzId,
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

    enum CityStyle: CaseIterable {
        case gradientPills, flagCards, numberedSequence,
             boardingPass, airportTags, postcardStack, animatedPlanePath
    }

    @State private var cityStyle: CityStyle = .gradientPills

    private static let cityFlags: [String: String] = [
        // US cities — landmark/vibe emoji instead of repeated flags
        "New York": "🗽", "Los Angeles": "🎬", "Chicago": "🌬️", "Houston": "🚀",
        "Phoenix": "🌵", "San Francisco": "🌁", "Seattle": "☕", "Denver": "🏔️",
        "Atlanta": "🍑", "Miami": "🌴", "Dallas": "🤠", "Boston": "🦞",
        "Minneapolis": "❄️", "Detroit": "🏭", "Orlando": "🏰", "Las Vegas": "🎰",
        "Honolulu": "🌺", "Anchorage": "🐻", "Portland": "🌲", "San Diego": "🏖️",
        "Charlotte": "🏁", "Newark": "🗽", "Fort Lauderdale": "⛵",
        "Salt Lake City": "🏔️", "Nashville": "🎸", "Austin": "🎵",
        "San Juan": "🏝️", "Washington": "🏛️", "Philadelphia": "🔔",
        // International
        "London": "🇬🇧", "Paris": "🇫🇷", "Tokyo": "🇯🇵", "Toronto": "🇨🇦",
        "Vancouver": "🇨🇦", "Montreal": "🇨🇦", "Calgary": "🇨🇦",
        "Mexico City": "🇲🇽", "Cancun": "🇲🇽", "Guadalajara": "🇲🇽",
        "Frankfurt": "🇩🇪", "Munich": "🇩🇪", "Berlin": "🇩🇪",
        "Amsterdam": "🇳🇱", "Seoul": "🇰🇷", "Shanghai": "🇨🇳", "Beijing": "🇨🇳",
        "Shenzhen": "🇨🇳", "Hong Kong": "🇭🇰", "Taipei": "🇹🇼",
        "Sydney": "🇦🇺", "Melbourne": "🇦🇺", "Singapore": "🇸🇬",
        "Dubai": "🇦🇪", "Delhi": "🇮🇳", "Mumbai": "🇮🇳",
        "São Paulo": "🇧🇷", "Rio de Janeiro": "🇧🇷", "Bogota": "🇨🇴",
        "Lima": "🇵🇪", "Buenos Aires": "🇦🇷", "Santiago": "🇨🇱",
        "Rome": "🇮🇹", "Milan": "🇮🇹", "Madrid": "🇪🇸", "Barcelona": "🇪🇸",
        "Lisbon": "🇵🇹", "Dublin": "🇮🇪", "Zurich": "🇨🇭", "Brussels": "🇧🇪",
        "Vienna": "🇦🇹", "Stockholm": "🇸🇪", "Copenhagen": "🇩🇰", "Oslo": "🇳🇴",
        "Helsinki": "🇫🇮", "Reykjavik": "🇮🇸", "Istanbul": "🇹🇷",
        "Bangkok": "🇹🇭", "Manila": "🇵🇭", "Jakarta": "🇮🇩",
        "Nairobi": "🇰🇪", "Cairo": "🇪🇬", "Johannesburg": "🇿🇦",
        "Auckland": "🇳🇿", "Doha": "🇶🇦",
    ]

    private static let pillGradients: [LinearGradient] = [
        LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing),
        LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing),
        LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing),
        LinearGradient(colors: [.teal, .green], startPoint: .leading, endPoint: .trailing),
        LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing),
    ]

    private static let cityIATACodes: [String: String] = [
        "New York": "JFK", "Los Angeles": "LAX", "Chicago": "ORD", "Houston": "IAH",
        "Phoenix": "PHX", "San Francisco": "SFO", "Seattle": "SEA", "Denver": "DEN",
        "Atlanta": "ATL", "Miami": "MIA", "Dallas": "DFW", "Boston": "BOS",
        "Minneapolis": "MSP", "Detroit": "DTW", "Orlando": "MCO", "Las Vegas": "LAS",
        "Honolulu": "HNL", "Anchorage": "ANC", "Portland": "PDX", "San Diego": "SAN",
        "Charlotte": "CLT", "Newark": "EWR", "Fort Lauderdale": "FLL",
        "Salt Lake City": "SLC", "Nashville": "BNA", "Austin": "AUS",
        "San Juan": "SJU", "Washington": "DCA", "Philadelphia": "PHL",
        "London": "LHR", "Paris": "CDG", "Tokyo": "NRT", "Toronto": "YYZ",
        "Vancouver": "YVR", "Montreal": "YUL", "Calgary": "YYC",
        "Mexico City": "MEX", "Cancun": "CUN", "Guadalajara": "GDL",
        "Frankfurt": "FRA", "Munich": "MUC", "Berlin": "BER",
        "Amsterdam": "AMS", "Seoul": "ICN", "Shanghai": "PVG", "Beijing": "PEK",
        "Shenzhen": "SZX", "Hong Kong": "HKG", "Taipei": "TPE",
        "Sydney": "SYD", "Melbourne": "MEL", "Singapore": "SIN",
        "Dubai": "DXB", "Delhi": "DEL", "Mumbai": "BOM",
        "São Paulo": "GRU", "Rio de Janeiro": "GIG", "Bogota": "BOG",
        "Lima": "LIM", "Buenos Aires": "EZE", "Santiago": "SCL",
        "Rome": "FCO", "Milan": "MXP", "Madrid": "MAD", "Barcelona": "BCN",
        "Lisbon": "LIS", "Dublin": "DUB", "Zurich": "ZRH", "Brussels": "BRU",
        "Vienna": "VIE", "Stockholm": "ARN", "Copenhagen": "CPH", "Oslo": "OSL",
        "Helsinki": "HEL", "Reykjavik": "KEF", "Istanbul": "IST",
        "Bangkok": "BKK", "Manila": "MNL", "Jakarta": "CGK",
        "Nairobi": "NBO", "Cairo": "CAI", "Johannesburg": "JNB",
        "Auckland": "AKL", "Doha": "DOH",
    ]

    private static let cityGreetings: [String: String] = [
        // US — regional flair
        "New York": "Hey!", "Los Angeles": "Hey!", "Chicago": "Hey!",
        "Houston": "Howdy!", "Phoenix": "Hello!", "San Francisco": "Hey!",
        "Seattle": "Hey!", "Denver": "Hello!", "Atlanta": "Hey y'all!",
        "Miami": "¡Hola!", "Dallas": "Howdy!", "Boston": "Hello!",
        "Minneapolis": "Hello!", "Detroit": "Hello!", "Orlando": "Hello!",
        "Las Vegas": "Hello!", "Honolulu": "Aloha!", "Anchorage": "Hello!",
        "Portland": "Hello!", "San Diego": "Hey!", "Charlotte": "Hello!",
        "Newark": "Hey!", "Fort Lauderdale": "Hello!",
        "Salt Lake City": "Hello!", "Nashville": "Howdy!",
        "Austin": "Howdy!", "San Juan": "¡Hola!",
        "Washington": "Hello!", "Philadelphia": "Hey!",
        // International
        "London": "Cheerio!", "Paris": "Bonjour!", "Tokyo": "Konnichiwa!",
        "Toronto": "Hello!", "Vancouver": "Hello!", "Montreal": "Bonjour!",
        "Calgary": "Hello!",
        "Mexico City": "Hola!", "Cancun": "Hola!", "Guadalajara": "Hola!",
        "Frankfurt": "Hallo!", "Munich": "Servus!", "Berlin": "Hallo!",
        "Amsterdam": "Hallo!", "Seoul": "Annyeonghaseyo!", "Shanghai": "Ni hao!",
        "Beijing": "Ni hao!", "Shenzhen": "Ni hao!", "Hong Kong": "Ni hao!",
        "Taipei": "Ni hao!",
        "Sydney": "G'day!", "Melbourne": "G'day!", "Singapore": "Hello!",
        "Dubai": "Marhaba!", "Delhi": "Namaste!", "Mumbai": "Namaste!",
        "São Paulo": "Ola!", "Rio de Janeiro": "Ola!", "Bogota": "Hola!",
        "Lima": "Hola!", "Buenos Aires": "Hola!", "Santiago": "Hola!",
        "Rome": "Ciao!", "Milan": "Ciao!", "Madrid": "Hola!",
        "Barcelona": "Hola!", "Lisbon": "Ola!", "Dublin": "Dia duit!",
        "Zurich": "Gruezi!", "Brussels": "Bonjour!", "Vienna": "Servus!",
        "Stockholm": "Hej!", "Copenhagen": "Hej!", "Oslo": "Hei!",
        "Helsinki": "Moi!", "Reykjavik": "Hallo!", "Istanbul": "Merhaba!",
        "Bangkok": "Sawasdee!", "Manila": "Kumusta!", "Jakarta": "Halo!",
        "Nairobi": "Jambo!", "Cairo": "Marhaba!", "Johannesburg": "Sawubona!",
        "Auckland": "Kia ora!", "Doha": "Marhaba!",
    ]

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
                VStack(alignment: .leading, spacing: 14) {
                    Text("Upcoming Cities")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                let all = CityStyle.allCases
                                let idx = all.firstIndex(of: cityStyle)!
                                cityStyle = all[(idx + 1) % all.count]
                            }
                        }

                    switch cityStyle {
                    case .gradientPills:
                        gradientPillsStyle
                    case .flagCards:
                        flagCardsStyle
                    case .numberedSequence:
                        numberedSequenceStyle
                    case .boardingPass:
                        boardingPassStyle
                    case .airportTags:
                        airportTagsStyle
                    case .postcardStack:
                        postcardStackStyle
                    case .animatedPlanePath:
                        animatedPlanePathStyle
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    // MARK: - Style A: Gradient Pills

    private var gradientPillsStyle: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(upcomingCities.enumerated()), id: \.offset) { index, city in
                    Text(city)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .fixedSize()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Self.pillGradients[index % Self.pillGradients.count]
                        )
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Style C: Flag + City Cards

    private var flagCardsStyle: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(upcomingCities, id: \.self) { city in
                    VStack(spacing: 6) {
                        Text(flagForCity(city))
                            .font(.title)
                        Text(city)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .fixedSize()
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Style D: Numbered Sequence

    private var numberedSequenceStyle: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(upcomingCities.enumerated()), id: \.offset) { index, city in
                    HStack(spacing: 0) {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 22, height: 22)
                                Text("\(index + 1)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            Text(city)
                                .font(.caption)
                                .fontWeight(.medium)
                                .fixedSize()
                        }

                        if index < upcomingCities.count - 1 {
                            Rectangle()
                                .fill(Color.blue.opacity(0.25))
                                .frame(width: 24, height: 2)
                                .padding(.bottom, 18)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func flagForCity(_ city: String) -> String {
        Self.cityFlags[city] ?? "🌍"
    }

    private func iataCode(_ city: String) -> String {
        Self.cityIATACodes[city] ?? String(city.prefix(3)).uppercased()
    }

    private func greeting(_ city: String) -> String {
        Self.cityGreetings[city] ?? "Hello!"
    }

    private static let tagColors: [Color] = [.blue, .purple, .orange, .teal, .indigo]

    // MARK: - Style E: Boarding Pass Stubs

    private var boardingPassStyle: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(upcomingCities.enumerated()), id: \.offset) { index, city in
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BOARDING PASS")
                                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text(city)
                                .font(.caption)
                                .fontWeight(.bold)
                                .fixedSize()
                            Text(iataCode(city))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                            HStack(spacing: 1.5) {
                                ForEach(0..<8, id: \.self) { i in
                                    let seed = city.hashValue &+ i
                                    let width = CGFloat(2 + abs(seed) % 5)
                                    Rectangle()
                                        .fill(Color.primary.opacity(0.4))
                                        .frame(width: width, height: 10)
                                }
                            }
                            .padding(.top, 2)
                        }
                        .padding(.leading, 10)
                        .padding(.vertical, 8)

                        DashedTearLine()
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .foregroundColor(.secondary.opacity(0.5))
                            .frame(width: 1)
                            .padding(.horizontal, 8)

                        Text(iataCode(city))
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                            .foregroundColor(.blue)
                            .padding(.trailing, 10)
                    }
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: .rect(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Style F: Airport Tags

    private var airportTagsStyle: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(upcomingCities.enumerated()), id: \.offset) { index, city in
                    let color = Self.tagColors[index % Self.tagColors.count]
                    VStack(spacing: 6) {
                        Circle()
                            .stroke(color.opacity(0.5), lineWidth: 1.5)
                            .frame(width: 10, height: 10)
                        Text(iataCode(city))
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(color)
                        Text(city)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .fixedSize()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.3), lineWidth: 1.5)
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Style G: Postcard Stack

    private var postcardStackStyle: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -6) {
                ForEach(Array(upcomingCities.enumerated()), id: \.offset) { index, city in
                    VStack(spacing: 0) {
                        ZStack(alignment: .topTrailing) {
                            Self.pillGradients[index % Self.pillGradients.count]
                                .frame(height: 30)

                            Text(flagForCity(city))
                                .font(.title3)
                                .rotationEffect(.degrees(-12))
                                .padding(.top, 2)
                                .padding(.trailing, 4)
                        }

                        Text(city)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .fixedSize()
                            .padding(.vertical, 8)
                            .padding(.horizontal, 6)
                    }
                    .frame(width: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -2 : 2))
                    .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Style H: Animated Plane Path

    private var animatedPlanePathStyle: some View {
        GeometryReader { geo in
            let count = upcomingCities.count
            let spacing = count > 1 ? (geo.size.width - 32) / CGFloat(count - 1) : 0
            let totalWidth = count > 1 ? geo.size.width - 32 : 0
            let arcHeight: CGFloat = 24
            let flightTime: Double = 0.8
            let pauseTime: Double = 0.5
            let legTime = flightTime + pauseTime
            let cycleTime = legTime * Double(max(count - 1, 1))

            ZStack(alignment: .topLeading) {
                // City dots, labels, plane, and greetings — all in one TimelineView
                if count > 1 {
                    TimelineView(.animation) { context in
                        let time = context.date.timeIntervalSinceReferenceDate
                        let cycleProgress = time.truncatingRemainder(dividingBy: cycleTime)
                        let leg = min(Int(cycleProgress / legTime), count - 2)
                        let legProgress = (cycleProgress - Double(leg) * legTime)

                        let t = min(legProgress / flightTime, 1.0)
                        let fromX = spacing * CGFloat(leg)
                        let toX = spacing * CGFloat(leg + 1)
                        let x = fromX + (toX - fromX) * CGFloat(t)
                        let y = t < 1.0 ? -arcHeight * 4 * CGFloat(t) * CGFloat(1 - t) : 0

                        let isLanded = legProgress >= flightTime
                        // The most recently landed city index
                        let landedCity = isLanded ? leg + 1 : leg

                        ZStack(alignment: .topLeading) {
                            // Horizontal line through dots
                            Rectangle()
                                .fill(Color.blue.opacity(0.25))
                                .frame(width: totalWidth, height: 2)
                                .offset(x: 16, y: 4)

                            // City dots and labels
                            ForEach(Array(upcomingCities.enumerated()), id: \.offset) { index, city in
                                let showGreeting = index > 0 && index <= landedCity
                                VStack(spacing: 3) {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 10, height: 10)
                                    Text(iataCode(city))
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .fixedSize()
                                    // Greeting below city code — stays until next landing
                                    Text(showGreeting ? greeting(city) : " ")
                                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                                        .foregroundColor(.orange)
                                        .fixedSize()
                                }
                                .offset(x: 16 + spacing * CGFloat(index) - 5)
                            }

                            // Plane
                            SideJetShape()
                                .fill(Color.blue)
                                .frame(width: 26, height: 18)
                                .offset(x: 16 + x - 13, y: y - 14)
                        }
                    }
                } else {
                    // Single city fallback
                    ForEach(Array(upcomingCities.enumerated()), id: \.offset) { index, city in
                        VStack(spacing: 3) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 10, height: 10)
                            Text(iataCode(city))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .fixedSize()
                        }
                        .offset(x: 16 + spacing * CGFloat(index) - 5)
                    }
                }
            }
        }
        .frame(height: 56)
    }
}

private struct SideJetShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        // Fuselage — pointed nose on right, rounded tail on left
        let bodyTop = h * 0.35
        let bodyBot = h * 0.65
        // Start at tail (left)
        p.move(to: CGPoint(x: w * 0.05, y: bodyTop))
        // Top of fuselage to nose
        p.addLine(to: CGPoint(x: w * 0.85, y: bodyTop))
        // Nose cone
        p.addQuadCurve(
            to: CGPoint(x: w * 0.85, y: bodyBot),
            control: CGPoint(x: w * 1.05, y: h * 0.5)
        )
        // Bottom of fuselage back to tail
        p.addLine(to: CGPoint(x: w * 0.05, y: bodyBot))
        p.closeSubpath()

        // Wing — triangle from mid-body downward
        p.move(to: CGPoint(x: w * 0.35, y: bodyBot))
        p.addLine(to: CGPoint(x: w * 0.55, y: bodyBot))
        p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.95))
        p.closeSubpath()

        // Tail fin — triangle at back pointing up
        p.move(to: CGPoint(x: w * 0.05, y: bodyTop))
        p.addLine(to: CGPoint(x: w * 0.18, y: bodyTop))
        p.addLine(to: CGPoint(x: w * 0.02, y: h * 0.05))
        p.closeSubpath()

        return p
    }
}

private struct DashedTearLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}


// MARK: - Sync Explanation View

struct SyncExplanationView: View {
    let pilotName: String
    let pilotUpdatedAt: Date
    let lastSyncTime: Date?
    let lastSyncError: String?

    var body: some View {
        VStack(spacing: 4) {
            if let syncTime = lastSyncTime {
                if let error = lastSyncError {
                    Label(friendlyError(error), systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("Synced with iCloud at \(syncTime.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("\(pilotName)'s info was last sent \(relativeTimestamp)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(pilotUpdatedAt)
    }

    private var relativeTimestamp: String {
        let interval = Date().timeIntervalSince(pilotUpdatedAt)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if isToday {
            return "at \(pilotUpdatedAt.formatted(date: .omitted, time: .shortened))"
        } else {
            return "on \(pilotUpdatedAt.formatted(date: .abbreviated, time: .shortened))"
        }
    }

    private func friendlyError(_ error: String) -> String {
        let lowercased = error.lowercased()
        if lowercased.contains("network") || lowercased.contains("connection") || lowercased.contains("internet") {
            return "Sync failed — check your connection"
        }
        if lowercased.contains("not authenticated") || lowercased.contains("authentication") {
            return "Sync failed — sign into iCloud"
        }
        if lowercased.contains("timeout") || lowercased.contains("timed out") {
            return "Sync timed out — will retry"
        }
        return "Sync failed — will retry"
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
        currentFlightArrivalTimezone: "America/Anchorage",
        homeArrivalTime: Date().addingTimeInterval(172800),
        nextDepartureTime: nil,
        nextFlightNumber: nil,
        nextFlightDestination: nil,
        currentTripId: "test123",
        tripDayNumber: 2,
        tripTotalDays: 4,
        upcomingCities: ["Anchorage", "Hong Kong", "Shanghai"],
        tripLegsJSON: nil,
        lastUpdated: Date().addingTimeInterval(-300),
        appVersion: "1.0"
    ),
    lastSyncTime: Date(),
    lastSyncError: nil
    )
}
