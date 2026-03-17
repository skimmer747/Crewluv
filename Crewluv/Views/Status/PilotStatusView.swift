//
//  PilotStatusView.swift
//  CrewLuve
//
//  Displays pilot status with countdown, location, and trip progress
//

import SwiftUI
import Combine

private struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

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
    var isCompanionLayout: Bool = false
    var onPasteShareLink: (() -> Void)? = nil
    var onRefresh: (() -> Void)? = nil

    @State private var showSchedule = false

    /// Derive upcoming trip info once from trip legs (single source of truth)
    private var upcomingTrip: UpcomingTripInfo? {
        guard status.displayStatus == "Home" else { return nil }
        return UpcomingTripInfo.from(tripLegs: status.tripLegs, at: Date())
    }

    /// Days home since last trip ended
    private var daysAtHome: Int? {
        guard let lastEnd = status.lastTripEndDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: lastEnd, to: Date()).day ?? 0
        return days > 0 ? days : nil
    }

    /// True when the pilot has an active delay on the last flight of the trip — shifts homeArrivalTime.
    /// Covers both in-flight on last leg AND layover/turn before last leg.
    private var isDelayedLastFlight: Bool {
        guard status.hasFlightDelay else { return false }
        let sortedLegs = status.tripLegs.sorted { $0.startTime < $1.startTime }
        // Find the specifically-delayed flight (has delayMinutes > 0)
        let delayedFlight = sortedLegs.first(where: { ($0.delayMinutes ?? 0) > 0 && $0.type == .flight })
        guard let flight = delayedFlight else { return false }
        let hasMoreFlights = sortedLegs.contains { $0.type == .flight && $0.startTime > flight.endTime }
        return !hasMoreFlights
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 20) {
                VStack(spacing: 24) {
                    // Narrative Card - "What's happening now"
                    NarrativeCardView(status: status, upcomingTrip: upcomingTrip)

                    // Next Departure (if at home) — taps open schedule
                    if status.displayStatus == "Home", let departureTime = status.nextDepartureTime {
                        scheduleLink {
                            CountdownCardView(
                                title: status.nextDepartureLabel ?? "Leaves In",
                                targetDate: departureTime,
                                icon: "airplane.departure",
                                color: .blue,
                                showChevron: !isCompanionLayout
                            )
                            .contentShape(.rect)
                        }
                    }

                    // Days home counter (only when home with last trip data)
                    if status.displayStatus == "Home", let days = daysAtHome {
                        HStack(spacing: 8) {
                            Image(systemName: "house.fill")
                                .font(.subheadline)
                                .foregroundColor(.green)
                            Text(days == 1 ? "1 day home" : "\(days) days home")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    }

                    // Countdown Timer (if not home) — taps open schedule
                    if let homeTime = status.homeArrivalTime, status.displayStatus != "Home" {
                        let label = status.homeArrivalLabel ?? "Back Home In"
                        let isGoingHome = label.contains("Home")
                        let shiftHomeTime = isDelayedLastFlight
                        let shiftedHomeTime = shiftHomeTime
                            ? homeTime.addingTimeInterval(TimeInterval((status.flightDelayMinutes ?? 0) * 60))
                            : homeTime
                        let dateStr = shiftedHomeTime.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                        let delayNote = shiftHomeTime ? " (delayed)" : ""
                        let arrivalSubtitle = [dateStr + delayNote, status.homeArrivalCity].compactMap { $0 }.joined(separator: " \u{00B7} ")

                        scheduleLink {
                            CountdownCardView(
                                title: label,
                                targetDate: shiftedHomeTime,
                                icon: isGoingHome ? "house.fill" : "airplane.arrival",
                                color: shiftHomeTime ? .red : .green,
                                subtitle: arrivalSubtitle,
                                showChevron: !isCompanionLayout
                            )
                            .anchorPreference(key: HomeCardBoundsKey.self, value: .bounds) { $0 }
                            .contentShape(.rect)
                        }
                    } else if status.displayStatus != "Home",
                              let dayNumber = status.tripDayNumber,
                              let totalDays = status.tripTotalDays {
                        scheduleLink {
                            EstimatedReturnCardView(
                                tripDayNumber: dayNumber,
                                tripTotalDays: totalDays,
                                homeArrivalLabel: status.homeArrivalLabel,
                                showChevron: !isCompanionLayout
                            )
                            .contentShape(.rect)
                        }
                    }

                    // Schedule card when home with no departure time (hidden on iPad)
                    if !isCompanionLayout, status.displayStatus == "Home", status.nextDepartureTime == nil {
                        Button { showSchedule = true } label: {
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
                            .contentShape(.rect)
                        }
                        .buttonStyle(CardButtonStyle())
                    }

                    // Location Card
                    LocationCardView(status: status)

                    // Upcoming trip card (when home with trip data)
                    if status.displayStatus == "Home", let trip = upcomingTrip {
                        scheduleLink {
                            UpcomingTripCard(
                                trip: trip,
                                showChevron: !isCompanionLayout
                            )
                            .contentShape(.rect)
                        }
                    }

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
        .navigationDestination(isPresented: $showSchedule) {
            EventTimelineView(status: status)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .overlayPreferenceValue(HomeCardBoundsKey.self) { anchor in
            if let anchor,
               let homeTime = status.homeArrivalTime,
               status.displayStatus != "Home" {
                // Use same shifted home time as CountdownCardView so celebration doesn't show early when delayed
                let shiftHomeTime = isDelayedLastFlight
                let shiftedHomeTime = shiftHomeTime
                    ? homeTime.addingTimeInterval(TimeInterval((status.flightDelayMinutes ?? 0) * 60))
                    : homeTime
                if shiftedHomeTime.timeIntervalSinceNow < 86400 && shiftedHomeTime.timeIntervalSinceNow > 0 {
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

    @ViewBuilder
    private func scheduleLink<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if isCompanionLayout {
            content()
        } else {
            Button { showSchedule = true } label: {
                content()
            }
            .buttonStyle(CardButtonStyle())
        }
    }
}

// MARK: - Countdown Card View

struct CountdownCardView: View {
    let title: String
    let targetDate: Date
    let icon: String
    let color: Color
    var subtitle: String? = nil
    var showChevron: Bool = true

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
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)

            formattedTimeText
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var liveLocalTime: String = ""
    @State private var currentWeather: WeatherSnapshot? = nil
    @State private var homeWeather: WeatherSnapshot? = nil
    @State private var timeDiffStyle: TimeDiffStyle = .odometer
    @State private var timeDiffAnimationID = UUID()
    @State private var showSunDetail = false
    @State private var showFlightTracking = false
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

            // Delay banner
            if status.hasFlightDelay, let delayMinutes = status.flightDelayMinutes {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text("DELAYED \(Self.formatDelayDuration(delayMinutes))")
                        .font(.caption.weight(.bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.orange)
            }

            // Info bar (matching widget style)
            HStack(spacing: 0) {
                // Left: Flight info
                VStack(alignment: .leading, spacing: 2) {
                    if let flightNumber = status.currentFlightNumber {
                        Text(flightNumber)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(primaryTextColor)
                            .underline(color: primaryTextColor.opacity(0.3))
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showFlightTracking = true
                            }
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
        .fullScreenCover(isPresented: $showFlightTracking) {
            if let flightNumber = status.currentFlightNumber {
                FlightTrackingPopupView(flightNumber: flightNumber)
            }
        }
    }

    // MARK: - Standard Location View (Not In Flight)
    
    private var standardLocationView: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    Text(status.currentCity ?? "Unknown Location")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                    if let flag = countryFlagEmoji {
                        Text(flag)
                            .font(.title)
                    }
                }

                if let weather = currentWeather {
                    HStack(spacing: 8) {
                        Image(systemName: weather.conditionSymbol)
                            .symbolRenderingMode(.multicolor)
                            .font(.title2)
                        Text(weather.temperature)
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(weather.conditionDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if let airport = status.currentAirport {
                    HStack {
                        Image(systemName: "airplane")
                            .foregroundColor(.secondary)
                        Text(airport)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Quick status / sleeping indicator
                if let qs = status.quickStatus, !qs.isEmpty,
                   status.quickStatusExpiry.map({ $0 > Date() }) ?? true {
                    QuickStatusIndicatorView(
                        label: qs,
                        icon: status.quickStatusIcon ?? "bubble.left.fill",
                        expiry: status.quickStatusExpiry,
                        accentColor: qs == "Flight Delayed" ? .orange : .blue
                    )
                    .padding(.top, 4)
                } else if status.isSleeping,
                          !(status.quickStatus == "Sleeping" && status.quickStatusExpiry.map({ $0 <= Date() }) ?? false) {
                    SleepingIndicatorView()
                        .padding(.top, 4)
                }

                if status.currentTimezone != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.blue)
                            Text("Current time:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(liveLocalTime)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .monospacedDigit()
                        }
                        if let diff = timeDifference {
                            TimeDiffAnimatedView(diff: diff, style: timeDiffStyle)
                                .id(timeDiffAnimationID)
                                .padding(.leading, 24)
                                .onTapGesture {
                                    let all = TimeDiffStyle.allCases
                                    let idx = all.firstIndex(of: timeDiffStyle)!
                                    timeDiffStyle = all[(idx + 1) % all.count]
                                    timeDiffAnimationID = UUID()
                                }
                        }
                    }
                }
            }

            // Sun circle clock in upper right
            if let weather = currentWeather,
               let sunrise = weather.sunrise,
               let sunset = weather.sunset {
                SunCircleView(
                    sunrise: sunrise,
                    sunset: sunset,
                    isDaylight: weather.isDaylight,
                    timezone: status.currentTimezone,
                    nextDepartureTime: status.nextDepartureTime,
                    flightDelayMinutes: status.flightDelayMinutes,
                    homeSunrise: homeWeather?.sunrise,
                    homeSunset: homeWeather?.sunset
                )
                .offset(x: 0, y: -6)
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showSunDetail = true
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
        .task(id: status.currentAirport) {
            await loadWeather()
            await loadHomeWeather()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await loadWeather()
                    await loadHomeWeather()
                }
            }
        }
        .fullScreenCover(isPresented: $showSunDetail) {
            if let weather = currentWeather,
               let sunrise = weather.sunrise,
               let sunset = weather.sunset {
                SunCircleDetailView(
                    sunrise: sunrise,
                    sunset: sunset,
                    isDaylight: weather.isDaylight,
                    timezone: status.currentTimezone,
                    cityName: status.currentCity ?? "Unknown",
                    weather: weather,
                    nextDepartureTime: status.nextDepartureTime,
                    flightDelayMinutes: status.flightDelayMinutes,
                    homeSunrise: homeWeather?.sunrise,
                    homeSunset: homeWeather?.sunset
                )
            }
        }
    }
    
    // MARK: - Helper Properties

    /// Format delay minutes as "1h 30m", "45m", etc.
    static func formatDelayDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

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

    private var countryFlagEmoji: String? {
        guard let iata = status.currentAirport else { return nil }
        return AirportDataProvider.shared.airportInfo(forIataCode: iata)?.countryFlagEmoji
    }

    private var timeDifference: TimeDifference? {
        guard let id = status.currentTimezone,
              let pilotTZ = TimeZone(identifier: id) else { return nil }
        let now = Date()
        let pilotOffset = pilotTZ.secondsFromGMT(for: now)
        let localOffset = TimeZone.current.secondsFromGMT(for: now)
        let diffSeconds = pilotOffset - localOffset

        let absDiff = abs(diffSeconds)
        let hours = absDiff / 3600
        let minutes = (absDiff % 3600) / 60
        let direction = diffSeconds > 0 ? "ahead of you" : "behind you"

        return TimeDifference(
            hours: hours,
            minutes: minutes,
            totalSeconds: diffSeconds,
            direction: direction,
            isSameTime: diffSeconds == 0
        )
    }

    // MARK: - Helper Methods

    private func loadWeather() async {
        guard let iata = status.currentAirport,
              let airport = AirportDataProvider.shared.airportInfo(forIataCode: iata) else {
            currentWeather = nil
            return
        }
        currentWeather = await WeatherService.shared.currentWeather(
            forAirport: iata,
            latitude: airport.latitude,
            longitude: airport.longitude
        )
    }

    private func loadHomeWeather() async {
        guard let homeIata = status.homeAirportCode,
              let airport = AirportDataProvider.shared.airportInfo(forIataCode: homeIata) else {
            homeWeather = nil
            return
        }
        homeWeather = await WeatherService.shared.currentWeather(
            forAirport: homeIata,
            latitude: airport.latitude,
            longitude: airport.longitude
        )
    }

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

// MARK: - Time Difference Model & Animations

private struct TimeDifference {
    let hours: Int
    let minutes: Int
    let totalSeconds: Int   // positive = ahead, negative = behind
    let direction: String   // "ahead of you" / "behind you"
    let isSameTime: Bool
    var isAhead: Bool { totalSeconds > 0 }
    var color: Color { isSameTime ? .secondary : (isAhead ? .blue : .orange) }

    var formattedText: String {
        if isSameTime { return "same time as you" }
        if hours == 0 {
            return "\(minutes)m \(direction)"
        } else if minutes == 0 {
            return "\(hours)h \(direction)"
        } else {
            return "\(hours)h \(minutes)m \(direction)"
        }
    }
}

private enum TimeDiffStyle: CaseIterable {
    case odometer, clockIcon, rubberBand
}

private struct TimeDiffAnimatedView: View {
    let diff: TimeDifference
    let style: TimeDiffStyle

    var body: some View {
        if diff.isSameTime {
            Text("same time as you")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            switch style {
            case .odometer:
                OdometerTimeDiffView(diff: diff)
            case .clockIcon:
                SpinningClockTimeDiffView(diff: diff)
            case .rubberBand:
                RubberBandTimeDiffView(diff: diff)
            }
        }
    }
}

// MARK: Style 1 — Counting Odometer

private struct OdometerTimeDiffView: View {
    let diff: TimeDifference

    @State private var displayedHours: Int = 0
    @State private var showMinutes: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            Text("\(displayedHours)")
                .foregroundColor(diff.color)
                .fontWeight(.semibold)
                .contentTransition(.numericText())
                .monospacedDigit()
            Text("h")
                .foregroundColor(.secondary)
            if diff.minutes > 0 {
                Text(" \(diff.minutes)")
                    .foregroundColor(diff.color)
                    .fontWeight(.semibold)
                    .contentTransition(.numericText())
                    .monospacedDigit()
                    .opacity(showMinutes ? 1 : 0)
                Text("m")
                    .foregroundColor(.secondary)
                    .opacity(showMinutes ? 1 : 0)
            }
            Text(" \(diff.direction)")
                .foregroundColor(.secondary)
        }
        .font(.caption)
        .onAppear {
            guard diff.hours > 0 else {
                displayedHours = 0
                showMinutes = true
                return
            }
            var step = 0
            func tick() {
                step += 1
                if step <= diff.hours {
                    withAnimation(.easeOut(duration: 0.12)) {
                        displayedHours = step
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { tick() }
                } else {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showMinutes = true
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { tick() }
        }
    }
}

// MARK: Style 2 — Spinning Clock Icon

private struct SpinningClockTimeDiffView: View {
    let diff: TimeDifference

    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .foregroundColor(diff.color)
                .rotationEffect(.degrees(rotation))
            Text(diff.formattedText)
                .foregroundColor(.secondary)
        }
        .font(.caption)
        .onAppear {
            let target: Double = diff.isAhead ? 360 : -360
            withAnimation(.spring(response: 0.8, dampingFraction: 0.5)) {
                rotation = target
            }
        }
    }
}

// MARK: Style 3 — Rubber-band Snap

private struct RubberBandTimeDiffView: View {
    let diff: TimeDifference

    @State private var appeared: Bool = false

    var body: some View {
        Text(diff.formattedText)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(diff.color)
            .offset(x: appeared ? 0 : (diff.isAhead ? 80 : -80))
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) {
                    appeared = true
                }
            }
    }
}

// MARK: - Sun Circle View (24-Hour Clock)

struct SunCircleView: View {
    let sunrise: Date
    let sunset: Date
    let isDaylight: Bool
    let timezone: String?
    var nextDepartureTime: Date? = nil
    var flightDelayMinutes: Int? = nil
    var homeSunrise: Date? = nil
    var homeSunset: Date? = nil
    var size: CGFloat = 160

    @State private var arcProgress: CGFloat = 0
    @State private var arcOpacity: CGFloat = 1
    @State private var departureArcProgress: CGFloat = 0
    @State private var departureArcOpacity: CGFloat = 1

    // All dimensions derived proportionally from size (base = 160)
    private var scale: CGFloat { size / 160 }
    private var radius: CGFloat { 42 * scale }
    private var iconSize: CGFloat { 14 * scale }
    private var moonIconSize: CGFloat { 12 * scale }
    private var tickLen: CGFloat { 6 * scale }
    private var noonTriangleSize: CGFloat { 6 * scale }
    private var noonTriangleHalfWidth: CGFloat { 3.5 * scale }
    private var noonFontSize: CGFloat { 8 * scale }
    private var timeLabelFontSize: CGFloat { 9 * scale }
    private var timeLabelOffset: CGFloat { 38 * scale }
    private var timeLabelPadding: CGFloat { 22 * scale }
    private var timeLabelEdge: CGFloat { 8 * scale }
    private var noonLabelOffset: CGFloat { 14 * scale }
    private var dayArcWidth: CGFloat { 2.5 * scale }
    private var nightArcWidth: CGFloat { 2 * scale }
    private var nightDash: [CGFloat] { [4 * scale, 3 * scale] }
    private var handWidth: CGFloat { max(1, 1 * scale) }
    private var homeHandDash: [CGFloat] { [4 * scale, 3 * scale] }
    private var homeIconSize: CGFloat { 10 * scale }
    private var arcLineWidth: CGFloat { 2 * scale }
    private var arrowheadSize: CGFloat { 5 * scale }

    private var hasDifferentTimezone: Bool {
        guard let tzId = timezone, let pilotTZ = TimeZone(identifier: tzId) else { return false }
        let now = Date()
        return pilotTZ.secondsFromGMT(for: now) != TimeZone.current.secondsFromGMT(for: now)
    }

    private var hasFlightDelay: Bool { (flightDelayMinutes ?? 0) > 0 }

    private var delayedDepartureTime: Date? {
        guard let dep = nextDepartureTime, hasFlightDelay,
              let minutes = flightDelayMinutes else { return nil }
        return dep.addingTimeInterval(TimeInterval(minutes * 60))
    }

    private var effectiveDepartureTime: Date? {
        delayedDepartureTime ?? nextDepartureTime
    }

    private func shouldShowDepartureArc(at date: Date) -> Bool {
        guard let dep = effectiveDepartureTime else { return false }
        return dep.timeIntervalSince(date) > 0
    }

    private func isDepartureOver24h(at date: Date) -> Bool {
        guard let dep = effectiveDepartureTime else { return false }
        return dep.timeIntervalSince(date) > 24 * 3600
    }

    private func departureCountdownText(at date: Date) -> String {
        guard let dep = effectiveDepartureTime else { return "" }
        let remaining = max(0, dep.timeIntervalSince(date))
        let totalHours = Int(remaining) / 3600
        let days = totalHours / 24
        let hours = totalHours % 24
        let minutes = (Int(remaining) % 3600) / 60
        if days > 0 && hours > 0 {
            return "\(days)d \(hours)h"
        } else if days > 0 {
            return "\(days)d"
        } else if hours > 0 && minutes > 0 {
            return "\(hours)h\(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    private var departureArcRadius: CGFloat { 42 * scale * 0.85 }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let center = CGPoint(x: size / 2, y: size / 2 + 2 * scale)
            let sunriseAngle = angleForTime(sunrise)
            let sunsetAngle = angleForTime(sunset)
            let currentAngle = angleForTime(timeline.date)
            let homeAngle = hasDifferentTimezone ? angleForHomeTime(timeline.date) : currentAngle
            let pilotIsAhead = isPilotAhead(at: timeline.date)

            ZStack {
                Canvas { context, _ in
                    // Sky gradient circle fill
                    let circle = Path(ellipseIn: CGRect(
                        x: center.x - radius, y: center.y - radius,
                        width: radius * 2, height: radius * 2
                    ))
                    context.drawLayer { ctx in
                        ctx.opacity = 0.25
                        let stops = skyGradientStops(
                            sunriseAngle: sunriseAngle, sunsetAngle: sunsetAngle
                        )
                        ctx.fill(circle, with: .conicGradient(
                            Gradient(stops: stops),
                            center: center,
                            angle: .degrees(0)
                        ))
                    }

                    // Shared daylight overlap wedge fill (detail view only)
                    if size > 160,
                       let oStart = overlapStart(sunriseAngle: sunriseAngle, sunsetAngle: sunsetAngle),
                       let oEnd = overlapEnd(sunriseAngle: sunriseAngle, sunsetAngle: sunsetAngle),
                       oStart < oEnd {
                        let oStartAngle = angleForTime(oStart)
                        let oEndAngle = angleForTime(oEnd)
                        let overlapWedge = Path { p in
                            p.move(to: center)
                            p.addArc(center: center, radius: radius,
                                     startAngle: oStartAngle, endAngle: oEndAngle,
                                     clockwise: false)
                            p.closeSubpath()
                        }
                        context.fill(overlapWedge, with: .color(.yellow.opacity(0.15)))
                    }

                    // Daytime arc stroke (orange/yellow gradient)
                    let dayArc = Path { p in
                        p.addArc(center: center, radius: radius,
                                 startAngle: sunriseAngle, endAngle: sunsetAngle,
                                 clockwise: false)
                    }
                    context.stroke(dayArc, with: .linearGradient(
                        Gradient(colors: [.orange, .yellow, .orange]),
                        startPoint: pointOnCircle(angle: sunriseAngle, radius: radius, center: center),
                        endPoint: pointOnCircle(angle: sunsetAngle, radius: radius, center: center)
                    ), style: StrokeStyle(lineWidth: dayArcWidth))

                    // Nighttime arc stroke (blue/gray, dashed)
                    let nightArc = Path { p in
                        p.addArc(center: center, radius: radius,
                                 startAngle: sunsetAngle, endAngle: sunriseAngle,
                                 clockwise: false)
                    }
                    context.stroke(nightArc, with: .linearGradient(
                        Gradient(colors: [.blue.opacity(0.5), .gray.opacity(0.4), .blue.opacity(0.5)]),
                        startPoint: pointOnCircle(angle: sunsetAngle, radius: radius, center: center),
                        endPoint: pointOnCircle(angle: sunriseAngle, radius: radius, center: center)
                    ), style: StrokeStyle(lineWidth: nightArcWidth, dash: nightDash))

                    // Twilight / golden hour glow bands
                    let twilightMinutes: Double = 30
                    let twilightDegrees = (twilightMinutes / (24 * 60)) * 360
                    let glowWidth = dayArcWidth * 2.5

                    // Clamp golden hour bands so they don't cross midday
                    let daylightSpanDeg = {
                        let raw = (sunsetAngle.degrees - sunriseAngle.degrees).truncatingRemainder(dividingBy: 360)
                        return raw <= 0 ? raw + 360 : raw
                    }()
                    let halfDaylight = daylightSpanDeg / 2
                    let clampedGoldenDeg = min(twilightDegrees, halfDaylight)

                    // Morning golden hour: sunrise → sunrise + clampedGolden (amber)
                    let morningGoldenEnd = Angle.degrees(sunriseAngle.degrees + clampedGoldenDeg)
                    let morningGolden = Path { p in
                        p.addArc(center: center, radius: radius,
                                 startAngle: sunriseAngle, endAngle: morningGoldenEnd,
                                 clockwise: false)
                    }
                    context.drawLayer { ctx in
                        ctx.opacity = 0.35
                        ctx.stroke(morningGolden, with: .color(.orange), style: StrokeStyle(lineWidth: glowWidth, lineCap: .round))
                    }

                    // Evening golden hour: sunset - clampedGolden → sunset (amber)
                    let eveningGoldenStart = Angle.degrees(sunsetAngle.degrees - clampedGoldenDeg)
                    let eveningGolden = Path { p in
                        p.addArc(center: center, radius: radius,
                                 startAngle: eveningGoldenStart, endAngle: sunsetAngle,
                                 clockwise: false)
                    }
                    context.drawLayer { ctx in
                        ctx.opacity = 0.35
                        ctx.stroke(eveningGolden, with: .color(.orange), style: StrokeStyle(lineWidth: glowWidth, lineCap: .round))
                    }

                    // Morning blue hour: sunrise - twilight → sunrise (blue)
                    let morningBlueStart = Angle.degrees(sunriseAngle.degrees - twilightDegrees)
                    let morningBlue = Path { p in
                        p.addArc(center: center, radius: radius,
                                 startAngle: morningBlueStart, endAngle: sunriseAngle,
                                 clockwise: false)
                    }
                    context.drawLayer { ctx in
                        ctx.opacity = 0.25
                        ctx.stroke(morningBlue, with: .color(.blue), style: StrokeStyle(lineWidth: glowWidth, lineCap: .round))
                    }

                    // Evening blue hour: sunset → sunset + twilight (blue)
                    let eveningBlueEnd = Angle.degrees(sunsetAngle.degrees + twilightDegrees)
                    let eveningBlue = Path { p in
                        p.addArc(center: center, radius: radius,
                                 startAngle: sunsetAngle, endAngle: eveningBlueEnd,
                                 clockwise: false)
                    }
                    context.drawLayer { ctx in
                        ctx.opacity = 0.25
                        ctx.stroke(eveningBlue, with: .color(.blue), style: StrokeStyle(lineWidth: glowWidth, lineCap: .round))
                    }

                    // Shared daylight overlap arc stroke (detail view only)
                    if size > 160,
                       let oStart = overlapStart(sunriseAngle: sunriseAngle, sunsetAngle: sunsetAngle),
                       let oEnd = overlapEnd(sunriseAngle: sunriseAngle, sunsetAngle: sunsetAngle),
                       oStart < oEnd {
                        let oStartAngle = angleForTime(oStart)
                        let oEndAngle = angleForTime(oEnd)
                        let overlapArc = Path { p in
                            p.addArc(center: center, radius: radius,
                                     startAngle: oStartAngle, endAngle: oEndAngle,
                                     clockwise: false)
                        }
                        context.stroke(overlapArc, with: .color(.white.opacity(0.8)),
                                       style: StrokeStyle(lineWidth: dayArcWidth * 1.5, lineCap: .round))
                    }

                    // Tick marks at sunrise and sunset
                    for angle in [sunriseAngle, sunsetAngle] {
                        let inner = pointOnCircle(angle: angle, radius: radius - tickLen / 2, center: center)
                        let outer = pointOnCircle(angle: angle, radius: radius + tickLen / 2, center: center)
                        var tick = Path()
                        tick.move(to: inner)
                        tick.addLine(to: outer)
                        context.stroke(tick, with: .color(.primary.opacity(0.5)), lineWidth: 1.5 * scale)
                    }

                    // Noon marker triangle at top of circle (270 degrees)
                    let noonAngle = Angle.degrees(270)
                    let noonTip = pointOnCircle(angle: noonAngle, radius: radius, center: center)
                    let noonBase = pointOnCircle(angle: noonAngle, radius: radius + noonTriangleSize, center: center)
                    let noonTriangle = Path { p in
                        p.move(to: noonTip)
                        p.addLine(to: CGPoint(x: noonBase.x - noonTriangleHalfWidth, y: noonBase.y))
                        p.addLine(to: CGPoint(x: noonBase.x + noonTriangleHalfWidth, y: noonBase.y))
                        p.closeSubpath()
                    }
                    context.fill(noonTriangle, with: .color(.primary.opacity(0.4)))

                    // Midnight marker triangle at bottom of circle (90 degrees)
                    let midnightAngle = Angle.degrees(90)
                    let midnightTip = pointOnCircle(angle: midnightAngle, radius: radius, center: center)
                    let midnightBase = pointOnCircle(angle: midnightAngle, radius: radius + noonTriangleSize, center: center)
                    let midnightTriangle = Path { p in
                        p.move(to: midnightTip)
                        p.addLine(to: CGPoint(x: midnightBase.x - noonTriangleHalfWidth, y: midnightBase.y))
                        p.addLine(to: CGPoint(x: midnightBase.x + noonTriangleHalfWidth, y: midnightBase.y))
                        p.closeSubpath()
                    }
                    context.fill(midnightTriangle, with: .color(.primary.opacity(0.4)))

                    // Clock hand from center to current time
                    let handEnd = pointOnCircle(angle: currentAngle, radius: radius, center: center)
                    var hand = Path()
                    hand.move(to: center)
                    hand.addLine(to: handEnd)
                    context.stroke(hand, with: .color(.primary.opacity(0.2)), lineWidth: handWidth)

                    // Clock hand from center to scheduled departure (detail view only)
                    if shouldShowDepartureArc(at: timeline.date), size > 160,
                       let dep = nextDepartureTime {
                        let depHandEnd = pointOnCircle(angle: angleForTime(dep), radius: radius, center: center)
                        var depHand = Path()
                        depHand.move(to: center)
                        depHand.addLine(to: depHandEnd)
                        context.stroke(depHand, with: .color(.cyan.opacity(0.4)), lineWidth: handWidth)
                    }

                    // Clock hand from center to delayed departure (detail view only)
                    if shouldShowDepartureArc(at: timeline.date), size > 160, hasFlightDelay,
                       let delayedDep = delayedDepartureTime {
                        let delayHandEnd = pointOnCircle(angle: angleForTime(delayedDep), radius: radius, center: center)
                        var delayHand = Path()
                        delayHand.move(to: center)
                        delayHand.addLine(to: delayHandEnd)
                        context.stroke(delayHand, with: .color(.red.opacity(0.4)), lineWidth: handWidth)
                    }

                    // Home time indicators
                    if hasDifferentTimezone {
                        // Dashed green line (detail view only)
                        if size > 160 {
                            let homeEnd = pointOnCircle(angle: homeAngle, radius: radius, center: center)
                            var homeLine = Path()
                            homeLine.move(to: center)
                            homeLine.addLine(to: homeEnd)
                            context.stroke(homeLine, with: .color(.green.opacity(0.6)),
                                         style: StrokeStyle(lineWidth: max(1, 0.8 * scale), dash: homeHandDash))
                        }

                        // (Arc arrow drawn as Shape overlay below for proper animation)
                    }

                    // Departure triangle marker outside circle (like noon marker)
                    if shouldShowDepartureArc(at: timeline.date) && size > 160,
                       let dep = nextDepartureTime {
                        let depAngle = angleForTime(dep)
                        let depTip = pointOnCircle(angle: depAngle, radius: radius, center: center)
                        let depBase = pointOnCircle(angle: depAngle, radius: radius + noonTriangleSize, center: center)
                        let perpX = -sin(CGFloat(depAngle.radians))
                        let perpY = cos(CGFloat(depAngle.radians))
                        let depTriangle = Path { p in
                            p.move(to: depTip)
                            p.addLine(to: CGPoint(x: depBase.x + noonTriangleHalfWidth * perpX,
                                                  y: depBase.y + noonTriangleHalfWidth * perpY))
                            p.addLine(to: CGPoint(x: depBase.x - noonTriangleHalfWidth * perpX,
                                                  y: depBase.y - noonTriangleHalfWidth * perpY))
                            p.closeSubpath()
                        }
                        context.fill(depTriangle, with: .color(.cyan.opacity(0.4)))
                    }
                }

                // Sun or moon icon at current time position
                if isDaylight {
                    Image(systemName: "sun.max.fill")
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: iconSize))
                        .shadow(color: .orange.opacity(0.5), radius: 4 * scale)
                        .position(pointOnCircle(angle: currentAngle, radius: radius, center: center))
                } else {
                    Image(systemName: "moon.fill")
                        .font(.system(size: moonIconSize))
                        .foregroundStyle(.secondary)
                        .position(pointOnCircle(angle: currentAngle, radius: radius, center: center))
                }

                // House icon at home time position (detail view only)
                if hasDifferentTimezone && size > 160 {
                    Image(systemName: "house.fill")
                        .font(.system(size: homeIconSize))
                        .foregroundColor(.green)
                        .position(pointOnCircle(angle: homeAngle, radius: radius, center: center))
                }

                // Departure jet icon outside circle + time label (detail view only)
                if shouldShowDepartureArc(at: timeline.date) && size > 160,
                   let dep = nextDepartureTime {
                    let depAngle = angleForTime(dep)
                    let jetPos = pointOnCircle(angle: depAngle, radius: radius + noonTriangleSize + 2 * scale, center: center)

                    Image(systemName: "airplane")
                        .font(.system(size: homeIconSize, weight: .semibold))
                        .foregroundColor(.cyan)
                        .rotationEffect(.degrees(depAngle.degrees + 90))
                        .position(jetPos)

                    let labelPos = pointOnCircle(angle: depAngle, radius: radius + timeLabelOffset, center: center)
                    Text(formatTime(dep))
                        .font(.system(size: timeLabelFontSize, weight: .medium))
                        .foregroundColor(.cyan)
                        .position(x: max(timeLabelPadding, min(size - timeLabelPadding, labelPos.x)),
                                  y: max(timeLabelEdge, min(size - timeLabelEdge, labelPos.y)))

                    // Red delayed departure marker
                    if let delayedDep = delayedDepartureTime {
                        let delayAngle = angleForTime(delayedDep)
                        let delayJetPos = pointOnCircle(angle: delayAngle, radius: radius + noonTriangleSize + 2 * scale, center: center)

                        Image(systemName: "airplane")
                            .font(.system(size: homeIconSize, weight: .semibold))
                            .foregroundColor(.red)
                            .rotationEffect(.degrees(delayAngle.degrees + 90))
                            .position(delayJetPos)

                        let delayLabelPos = pointOnCircle(angle: delayAngle, radius: radius + timeLabelOffset, center: center)
                        Text(formatTime(delayedDep))
                            .font(.system(size: timeLabelFontSize, weight: .medium))
                            .foregroundColor(.red)
                            .position(x: max(timeLabelPadding, min(size - timeLabelPadding, delayLabelPos.x)),
                                      y: max(timeLabelEdge, min(size - timeLabelEdge, delayLabelPos.y)))
                    }
                }

                // Animated arc arrow (Shape-based for proper animation, detail view only)
                if hasDifferentTimezone && size > 160 {
                    let arcColor: Color = pilotIsAhead ? .blue : .orange

                    HomeTimeArcShape(
                        progress: arcProgress,
                        homeAngle: homeAngle,
                        pilotAngle: currentAngle,
                        isAhead: pilotIsAhead,
                        centerYOffset: 2 * scale
                    )
                    .stroke(arcColor.opacity(0.7), style: StrokeStyle(lineWidth: arcLineWidth, lineCap: .round))
                    .opacity(arcOpacity)

                    HomeTimeArrowheadShape(
                        progress: arcProgress,
                        homeAngle: homeAngle,
                        pilotAngle: currentAngle,
                        isAhead: pilotIsAhead,
                        centerYOffset: 2 * scale
                    )
                    .fill(arcColor.opacity(0.7))
                    .opacity(arcOpacity)
                }

                // Hour difference in center, synced with arrow animation
                if hasDifferentTimezone && size > 160 {
                    VStack(spacing: 0) {
                        Text(hourDifferenceText(at: timeline.date))
                            .font(.system(size: 10 * scale, weight: .semibold, design: .rounded))
                        Text(pilotIsAhead ? "ahead" : "behind")
                            .font(.system(size: 7 * scale, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(pilotIsAhead ? .blue : .orange)
                    .position(center)
                    .opacity(arcProgress * arcOpacity)
                }

                // Departure arc (detail view only)
                if shouldShowDepartureArc(at: timeline.date) && size > 160 {
                    let effectiveDep = effectiveDepartureTime!
                    let scheduledDep = nextDepartureTime!
                    let hoursToEffective = effectiveDep.timeIntervalSince(timeline.date) / 3600
                    let effectiveDepAngle = angleForTime(effectiveDep)

                    // Sweep from current angle to scheduled departure
                    let scheduledDepAngle = angleForTime(scheduledDep)
                    let scheduledClockDist = (scheduledDepAngle.degrees - currentAngle.degrees + 360)
                        .truncatingRemainder(dividingBy: 360)
                    let hoursToScheduled = scheduledDep.timeIntervalSince(timeline.date) / 3600
                    let scheduledFullRevs = floor(max(0, hoursToScheduled) / 24)
                    let scheduledSweep = scheduledFullRevs * 360 + scheduledClockDist

                    let departureOver24h = isDepartureOver24h(at: timeline.date)

                    if departureOver24h {
                        // Dashed cyan: full revolution(s) up to scheduled
                        DepartureArcShape(
                            progress: departureArcProgress,
                            currentAngle: currentAngle,
                            departureAngle: effectiveDepAngle,
                            centerYOffset: 2 * scale,
                            hoursUntilDeparture: hoursToEffective,
                            sweepCap: scheduledFullRevs * 360
                        )
                        .stroke(Color.cyan.opacity(0.7), style: StrokeStyle(
                            lineWidth: arcLineWidth,
                            lineCap: .round,
                            dash: homeHandDash
                        ))
                        .opacity(departureArcOpacity)

                        // Solid cyan: remainder after full revolutions, capped at scheduled
                        DepartureArcShape(
                            progress: departureArcProgress,
                            currentAngle: currentAngle,
                            departureAngle: effectiveDepAngle,
                            centerYOffset: 2 * scale,
                            hoursUntilDeparture: hoursToEffective,
                            sweepOffset: scheduledFullRevs * 360,
                            sweepCap: scheduledSweep - scheduledFullRevs * 360
                        )
                        .stroke(Color.cyan.opacity(0.7), style: StrokeStyle(
                            lineWidth: arcLineWidth,
                            lineCap: .round
                        ))
                        .opacity(departureArcOpacity)
                    } else {
                        // ≤24h: single solid cyan arc capped at scheduled sweep
                        DepartureArcShape(
                            progress: departureArcProgress,
                            currentAngle: currentAngle,
                            departureAngle: effectiveDepAngle,
                            centerYOffset: 2 * scale,
                            hoursUntilDeparture: hoursToEffective,
                            sweepCap: scheduledSweep
                        )
                        .stroke(Color.cyan.opacity(0.7), style: StrokeStyle(
                            lineWidth: arcLineWidth,
                            lineCap: .round
                        ))
                        .opacity(departureArcOpacity)
                    }

                    // Red delay extension (from scheduled to effective departure)
                    if hasFlightDelay {
                        DepartureArcShape(
                            progress: departureArcProgress,
                            currentAngle: currentAngle,
                            departureAngle: effectiveDepAngle,
                            centerYOffset: 2 * scale,
                            hoursUntilDeparture: hoursToEffective,
                            sweepOffset: scheduledSweep
                        )
                        .stroke(Color.red.opacity(0.8), style: StrokeStyle(
                            lineWidth: arcLineWidth,
                            lineCap: .round
                        ))
                        .opacity(departureArcOpacity)
                    }

                    // Jet icon tracking arc endpoint (animatable per-frame)
                    let currentDeg = currentAngle.degrees
                    let effectiveDepDeg = effectiveDepAngle.degrees
                    let clockDist = (effectiveDepDeg - currentDeg + 360).truncatingRemainder(dividingBy: 360)
                    let fullRevolutions = floor(hoursToEffective / 24)
                    let totalSweep = fullRevolutions * 360 + clockDist

                    Image(systemName: "airplane")
                        .font(.system(size: 8 * scale, weight: .semibold))
                        .foregroundColor(hasFlightDelay ? .red : .cyan)
                        .modifier(ArcEndpointModifier(
                            progress: departureArcProgress,
                            startAngleDeg: currentDeg,
                            totalSweep: totalSweep,
                            radius: departureArcRadius,
                            center: center
                        ))
                        .opacity(departureArcProgress * departureArcOpacity)

                    // Departure countdown in center
                    VStack(spacing: 0) {
                        Text(departureCountdownText(at: timeline.date))
                            .font(.system(size: 10 * scale, weight: .semibold, design: .rounded))
                        Text("to go")
                            .font(.system(size: 7 * scale, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(hasFlightDelay ? .red : .cyan)
                    .position(center)
                    .opacity(departureArcProgress * departureArcOpacity)
                }

                // Noon label above triangle
                Text("Noon")
                    .font(.system(size: noonFontSize))
                    .foregroundColor(.secondary)
                    .position(x: center.x, y: center.y - radius - noonLabelOffset)

                // Sunrise time label
                let sunriseLabelPos = pointOnCircle(angle: sunriseAngle, radius: radius + timeLabelOffset, center: center)
                Text(formatTime(sunrise))
                    .font(.system(size: timeLabelFontSize, weight: .medium))
                    .foregroundColor(.primary)
                    .position(x: max(timeLabelPadding, min(size - timeLabelPadding, sunriseLabelPos.x)),
                              y: max(timeLabelEdge, min(size - timeLabelEdge, sunriseLabelPos.y)))

                // Sunset time label
                let sunsetLabelPos = pointOnCircle(angle: sunsetAngle, radius: radius + timeLabelOffset, center: center)
                Text(formatTime(sunset))
                    .font(.system(size: timeLabelFontSize, weight: .medium))
                    .foregroundColor(.primary)
                    .position(x: max(timeLabelPadding, min(size - timeLabelPadding, sunsetLabelPos.x)),
                              y: max(timeLabelEdge, min(size - timeLabelEdge, sunsetLabelPos.y)))
            }
            .frame(width: size, height: size)
        }
        .task {
            while !Task.isCancelled {
                var didAnimate = false

                // Phase 1: Timezone arc (if visible)
                if hasDifferentTimezone && size > 160 {
                    didAnimate = true
                    withAnimation(.easeOut(duration: 0.8)) {
                        arcProgress = 1
                    }
                    try? await Task.sleep(for: .seconds(2.0))

                    withAnimation(.easeOut(duration: 0.6)) {
                        arcOpacity = 0
                    }
                    try? await Task.sleep(for: .seconds(0.8))

                    arcProgress = 0
                    arcOpacity = 1
                    try? await Task.sleep(for: .seconds(0.3))
                }

                // Phase 2: Departure arc (if visible)
                if shouldShowDepartureArc(at: Date()) && size > 160 {
                    didAnimate = true
                    let depHours = effectiveDepartureTime.map {
                        $0.timeIntervalSince(Date()) / 3600
                    } ?? 0
                    let revolutions = max(1, depHours / 24)
                    let arcDuration = 0.8 * revolutions

                    withAnimation(.easeOut(duration: arcDuration)) {
                        departureArcProgress = 1
                    }
                    try? await Task.sleep(for: .seconds(2.0))

                    withAnimation(.easeOut(duration: 0.6)) {
                        departureArcOpacity = 0
                    }
                    try? await Task.sleep(for: .seconds(0.8))

                    departureArcProgress = 0
                    departureArcOpacity = 1
                    try? await Task.sleep(for: .seconds(0.3))
                }

                // Avoid tight loop when neither arc is visible
                if !didAnimate {
                    try? await Task.sleep(for: .seconds(1.0))
                }
            }
        }
    }

    /// Convert a Date to a circle angle: midnight=bottom, 6am=left, noon=top, 6pm=right
    private func angleForTime(_ date: Date) -> Angle {
        var cal = Calendar.current
        if let tzId = timezone, let tz = TimeZone(identifier: tzId) {
            cal.timeZone = tz
        }
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        let hoursFromMidnight = Double(hour) + Double(minute) / 60.0
        let degrees = 90.0 + (hoursFromMidnight / 24.0) * 360.0
        return .degrees(degrees)
    }

    /// Same as angleForTime but uses the device's local timezone (home time)
    private func angleForHomeTime(_ date: Date) -> Angle {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        let hoursFromMidnight = Double(hour) + Double(minute) / 60.0
        let degrees = 90.0 + (hoursFromMidnight / 24.0) * 360.0
        return .degrees(degrees)
    }

    /// Whether the pilot's timezone is ahead of home (east of home)
    private func isPilotAhead(at date: Date) -> Bool {
        guard let tzId = timezone, let pilotTZ = TimeZone(identifier: tzId) else { return false }
        return pilotTZ.secondsFromGMT(for: date) > TimeZone.current.secondsFromGMT(for: date)
    }

    /// Signed hour offset string between pilot timezone and device timezone
    private func hourDifferenceText(at date: Date) -> String {
        guard let tzId = timezone, let pilotTZ = TimeZone(identifier: tzId) else { return "" }
        let diffSeconds = pilotTZ.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)
        let hours = diffSeconds / 3600
        let minutes = abs(diffSeconds % 3600) / 60
        let sign = diffSeconds >= 0 ? "+" : "-"
        if minutes == 0 {
            return "\(sign)\(abs(hours))h"
        } else {
            return "\(sign)\(abs(hours)):\(String(format: "%02d", minutes))"
        }
    }

    // MARK: - Sky Gradient & Overlap Helpers

    private func skyGradientStops(sunriseAngle: Angle, sunsetAngle: Angle) -> [Gradient.Stop] {
        // Convert circle angles to conic gradient fractions (0 = 3 o'clock / east)
        // Our circle: midnight=90°, 6am=180°, noon=270°, 6pm=0°
        // Conic gradient: 0° = 3 o'clock (east), goes clockwise
        let sunriseFrac = clampFraction(sunriseAngle.degrees / 360)
        let sunsetFrac = clampFraction(sunsetAngle.degrees / 360)
        let noonFrac = clampFraction(270.0 / 360)
        let midnightFrac = clampFraction(90.0 / 360)

        // Pre-dawn and post-dusk transition points
        let preDawnFrac = clampFraction(sunriseFrac - 0.02)
        let postDuskFrac = clampFraction(sunsetFrac + 0.02)

        let navy = Color(red: 0.05, green: 0.05, blue: 0.2)
        let amber = Color(red: 0.9, green: 0.6, blue: 0.2)
        let skyBlue = Color(red: 0.4, green: 0.7, blue: 1.0)

        return [
            .init(color: navy, location: midnightFrac),
            .init(color: navy, location: preDawnFrac),
            .init(color: amber, location: sunriseFrac),
            .init(color: skyBlue, location: noonFrac),
            .init(color: amber, location: sunsetFrac),
            .init(color: navy, location: postDuskFrac),
            .init(color: navy, location: clampFraction(midnightFrac + 1.0)),
        ].sorted { $0.location < $1.location }
    }

    private func clampFraction(_ value: Double) -> Double {
        let v = value.truncatingRemainder(dividingBy: 1.0)
        return v < 0 ? v + 1.0 : v
    }

    /// Overlap start: max(pilotSunrise, homeSunrise) — both are absolute UTC dates
    private func overlapStart(sunriseAngle: Angle, sunsetAngle: Angle) -> Date? {
        guard let hSunrise = homeSunrise else { return nil }
        return max(sunrise, hSunrise)
    }

    /// Overlap end: min(pilotSunset, homeSunset) — both are absolute UTC dates
    private func overlapEnd(sunriseAngle: Angle, sunsetAngle: Angle) -> Date? {
        guard let hSunset = homeSunset else { return nil }
        return min(sunset, hSunset)
    }

    private func pointOnCircle(angle: Angle, radius: CGFloat, center: CGPoint) -> CGPoint {
        let rad = CGFloat(angle.radians)
        return CGPoint(
            x: center.x + radius * cos(rad),
            y: center.y + radius * sin(rad)
        )
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        formatter.amSymbol = "a"
        formatter.pmSymbol = "p"
        if let tzId = timezone, let tz = TimeZone(identifier: tzId) {
            formatter.timeZone = tz
        }
        return formatter.string(from: date)
    }
}

// MARK: - Departure Arc Shape

/// Arc stroke from current time angle clockwise to departure time angle, with animatable progress.
private struct DepartureArcShape: Shape {
    var progress: CGFloat
    let currentAngle: Angle
    let departureAngle: Angle
    let centerYOffset: CGFloat
    let hoursUntilDeparture: Double
    var sweepOffset: Double = 0
    var sweepCap: Double = .infinity

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }

        let scale = rect.width / 160
        let center = CGPoint(x: rect.midX, y: rect.midY + centerYOffset)
        let arcRadius = 42 * scale * 0.85

        let currentDeg = currentAngle.degrees
        let depDeg = departureAngle.degrees
        let clockDist = (depDeg - currentDeg + 360).truncatingRemainder(dividingBy: 360)
        let fullRevolutions = floor(hoursUntilDeparture / 24)
        let totalSweep = fullRevolutions * 360 + clockDist
        let animatedSweep = totalSweep * Double(progress)

        // Clamp to this instance's offset/cap range
        let drawStart = min(animatedSweep, sweepOffset)
        let drawableSweep = min(animatedSweep - drawStart, sweepCap)
        guard drawableSweep > 0.001 else { return Path() }

        // Segment into <360° arcs so Core Graphics draws overlapping laps
        var path = Path()
        var remaining = drawableSweep
        var segStart = currentDeg + drawStart

        while remaining > 0.001 {
            let segSweep = min(remaining, 359.99)
            let segEnd = segStart + segSweep
            path.addArc(center: center, radius: arcRadius,
                        startAngle: .degrees(segStart), endAngle: .degrees(segEnd),
                        clockwise: false)
            segStart = segEnd
            remaining -= segSweep
        }

        return path
    }
}

// MARK: - Arc Endpoint Modifier

/// Positions and rotates a view at the animated endpoint of a departure arc.
/// Conforms to Animatable so SwiftUI interpolates progress per-frame,
/// keeping the view on the arc path instead of moving in a straight line.
private struct ArcEndpointModifier: ViewModifier, Animatable {
    var progress: CGFloat
    let startAngleDeg: Double
    let totalSweep: Double
    let radius: CGFloat
    let center: CGPoint

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let angleDeg = startAngleDeg + totalSweep * Double(progress)
        let rad = CGFloat(Angle.degrees(angleDeg).radians)
        let pos = CGPoint(
            x: center.x + radius * cos(rad),
            y: center.y + radius * sin(rad)
        )

        content
            .rotationEffect(.degrees(angleDeg + 90))
            .position(pos)
    }
}

// MARK: - Home Time Arc Shapes

/// Arc stroke from home angle toward pilot angle, with animatable progress.
private struct HomeTimeArcShape: Shape {
    var progress: CGFloat
    let homeAngle: Angle
    let pilotAngle: Angle
    let isAhead: Bool
    let centerYOffset: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }

        let scale = rect.width / 160
        let center = CGPoint(x: rect.midX, y: rect.midY + centerYOffset)
        let arcRadius = 42 * scale * 0.70

        let homeDeg = homeAngle.degrees
        let pilotDeg = pilotAngle.degrees

        let endAngle: Angle
        if isAhead {
            let cwDist = (pilotDeg - homeDeg + 360).truncatingRemainder(dividingBy: 360)
            endAngle = .degrees(homeDeg + cwDist * Double(progress))
        } else {
            let ccwDist = (homeDeg - pilotDeg + 360).truncatingRemainder(dividingBy: 360)
            endAngle = .degrees(homeDeg - ccwDist * Double(progress))
        }

        var path = Path()
        path.addArc(center: center, radius: arcRadius,
                    startAngle: homeAngle, endAngle: endAngle,
                    clockwise: isAhead ? false : true)
        return path
    }
}

/// Triangular arrowhead at the leading end of the arc.
private struct HomeTimeArrowheadShape: Shape {
    var progress: CGFloat
    let homeAngle: Angle
    let pilotAngle: Angle
    let isAhead: Bool
    let centerYOffset: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }

        let scale = rect.width / 160
        let center = CGPoint(x: rect.midX, y: rect.midY + centerYOffset)
        let arcRadius = 42 * scale * 0.70
        let arrowSize = 5 * scale

        let homeDeg = homeAngle.degrees
        let pilotDeg = pilotAngle.degrees

        let endAngle: Angle
        if isAhead {
            let cwDist = (pilotDeg - homeDeg + 360).truncatingRemainder(dividingBy: 360)
            endAngle = .degrees(homeDeg + cwDist * Double(progress))
        } else {
            let ccwDist = (homeDeg - pilotDeg + 360).truncatingRemainder(dividingBy: 360)
            endAngle = .degrees(homeDeg - ccwDist * Double(progress))
        }

        let tipX = center.x + arcRadius * cos(CGFloat(endAngle.radians))
        let tipY = center.y + arcRadius * sin(CGFloat(endAngle.radians))
        let arrowTip = CGPoint(x: tipX, y: tipY)

        let tangentDeg = endAngle.degrees + (isAhead ? 90 : -90)
        let backDeg = tangentDeg + 180
        let leftPt = CGPoint(
            x: arrowTip.x + arrowSize * cos(CGFloat(Angle.degrees(backDeg + 25).radians)),
            y: arrowTip.y + arrowSize * sin(CGFloat(Angle.degrees(backDeg + 25).radians))
        )
        let rightPt = CGPoint(
            x: arrowTip.x + arrowSize * cos(CGFloat(Angle.degrees(backDeg - 25).radians)),
            y: arrowTip.y + arrowSize * sin(CGFloat(Angle.degrees(backDeg - 25).radians))
        )

        var path = Path()
        path.move(to: arrowTip)
        path.addLine(to: leftPt)
        path.addLine(to: rightPt)
        path.closeSubpath()
        return path
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
        "Atlanta": "🍑", "Miami": "🌴", "Dallas": "🤠", "Dallas/Fort Worth": "🤠",
        "Boston": "🦞", "Minneapolis": "❄️", "Detroit": "🏭", "Orlando": "🏰",
        "Las Vegas": "🎰", "Honolulu": "🌺", "Anchorage": "🐻", "Portland": "🌲",
        "San Diego": "🏖️", "Charlotte": "🏁", "Newark": "🗽", "Fort Lauderdale": "⛵",
        "Salt Lake City": "🏔️", "Nashville": "🎸", "Austin": "🎵",
        "San Juan": "🏝️", "Washington DC": "🏛️", "Philadelphia": "🔔",
        "Louisville": "🥃", "Sacramento": "⛏️", "Memphis": "🎵",
        "New Orleans": "🎺", "Kansas City": "🍖", "St. Louis": "🌉",
        "Pittsburgh": "🔩", "Cleveland": "🎸", "Cincinnati": "🌶️",
        "Indianapolis": "🏎️", "Milwaukee": "🍺", "Tampa": "🏴‍☠️",
        "San Antonio": "🤠", "Buffalo": "🦬", "Savannah": "🌳",
        "Charleston": "🌾", "Lexington": "🐴", "Raleigh": "🌳",
        "Jacksonville": "🐆", "Baltimore": "🦀", "Boise": "💎",
        "Tucson": "🌵", "El Paso": "☀️", "Omaha": "🥩",
        "Richmond": "🏛️", "Santa Fe": "🏜️", "Key West": "🐚",
        // International
        "London": "🇬🇧", "Paris": "🇫🇷", "Tokyo": "🇯🇵", "Toronto": "🇨🇦",
        "Vancouver": "🇨🇦", "Montreal": "🇨🇦", "Calgary": "🇨🇦",
        "Mexico City": "🇲🇽", "Cancun": "🇲🇽", "Guadalajara": "🇲🇽",
        "Frankfurt": "🇩🇪", "Munich": "🇩🇪", "Berlin": "🇩🇪",
        "Amsterdam": "🇳🇱", "Seoul": "🇰🇷", "Shanghai": "🇨🇳", "Beijing": "🇨🇳",
        "Shenzhen": "🇨🇳", "Hong Kong": "🇭🇰", "Taipei": "🇹🇼",
        "Sydney": "🇦🇺", "Melbourne": "🇦🇺", "Singapore": "🇸🇬",
        "Dubai": "🇦🇪", "New Delhi": "🇮🇳", "Mumbai": "🇮🇳", "Bangalore": "🇮🇳",
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
        "Atlanta": "ATL", "Miami": "MIA", "Dallas": "DFW", "Dallas/Fort Worth": "DFW",
        "Boston": "BOS", "Minneapolis": "MSP", "Detroit": "DTW", "Orlando": "MCO",
        "Las Vegas": "LAS", "Honolulu": "HNL", "Anchorage": "ANC", "Portland": "PDX",
        "San Diego": "SAN", "Charlotte": "CLT", "Newark": "EWR", "Fort Lauderdale": "FLL",
        "Salt Lake City": "SLC", "Nashville": "BNA", "Austin": "AUS",
        "San Juan": "SJU", "Washington DC": "DCA", "Philadelphia": "PHL",
        "Louisville": "SDF", "Sacramento": "SMF", "Memphis": "MEM",
        "New Orleans": "MSY", "Kansas City": "MCI", "St. Louis": "STL",
        "Pittsburgh": "PIT", "Cleveland": "CLE", "Cincinnati": "CVG",
        "Indianapolis": "IND", "Milwaukee": "MKE", "Tampa": "TPA",
        "San Antonio": "SAT", "Buffalo": "BUF", "Savannah": "SAV",
        "Charleston": "CHS", "Lexington": "LEX", "Raleigh": "RDU",
        "Jacksonville": "JAX", "Baltimore": "BWI", "Boise": "BOI",
        "Tucson": "TUS", "El Paso": "ELP", "Omaha": "OMA",
        "Richmond": "RIC", "Santa Fe": "SAF", "Key West": "EYW",
        "London": "LHR", "Paris": "CDG", "Tokyo": "NRT", "Toronto": "YYZ",
        "Vancouver": "YVR", "Montreal": "YUL", "Calgary": "YYC",
        "Mexico City": "MEX", "Cancun": "CUN", "Guadalajara": "GDL",
        "Frankfurt": "FRA", "Munich": "MUC", "Berlin": "BER",
        "Amsterdam": "AMS", "Seoul": "ICN", "Shanghai": "PVG", "Beijing": "PEK",
        "Shenzhen": "SZX", "Hong Kong": "HKG", "Taipei": "TPE",
        "Sydney": "SYD", "Melbourne": "MEL", "Singapore": "SIN",
        "Dubai": "DXB", "New Delhi": "DEL", "Mumbai": "BOM", "Bangalore": "BLR",
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
        // US — city-themed words
        "New York": "Broadway", "Los Angeles": "Showtime", "Chicago": "Deep Dish",
        "Houston": "Liftoff", "Phoenix": "Saguaro", "San Francisco": "Fog City",
        "Seattle": "Drizzle", "Denver": "Mile High", "Atlanta": "Peaches",
        "Miami": "Vice", "Dallas": "Howdy", "Dallas/Fort Worth": "Howdy",
        "Boston": "Chowdah", "Minneapolis": "Uff Da", "Detroit": "Motown",
        "Orlando": "Magic", "Las Vegas": "Jackpot", "Honolulu": "Aloha",
        "Anchorage": "Frontier", "Portland": "Roses", "San Diego": "Sunshine",
        "Charlotte": "NASCAR", "Newark": "Brick City", "Fort Lauderdale": "Yachts",
        "Salt Lake City": "Powder", "Nashville": "Twang", "Austin": "Keep Weird",
        "San Juan": "Boricua", "Washington DC": "Monumental", "Philadelphia": "Liberty",
        "Louisville": "Bourbon", "Sacramento": "Gold Rush", "Memphis": "Blues",
        "New Orleans": "Jazz", "Kansas City": "BBQ", "St. Louis": "Gateway",
        "Pittsburgh": "Steel", "Cleveland": "Rock", "Cincinnati": "Chili",
        "Indianapolis": "Speedway", "Milwaukee": "Brew City", "Tampa": "Pirate",
        "San Antonio": "Alamo", "Buffalo": "Wings", "Savannah": "Charm",
        "Charleston": "Lowcountry", "Lexington": "Horses", "Raleigh": "Oak City",
        "Jacksonville": "Jax", "Baltimore": "Crabcake", "Boise": "Gem State",
        "Tucson": "Sonoran", "El Paso": "Sun City", "Omaha": "Steaks",
        "Richmond": "RVA", "Santa Fe": "Adobe", "Key West": "Conch",
        // International
        "London": "Cheerio", "Paris": "Bonjour", "Tokyo": "Konnichiwa",
        "Toronto": "Eh", "Vancouver": "Beautiful BC", "Montreal": "Bonjour",
        "Calgary": "Stampede",
        "Mexico City": "Hola", "Cancun": "Hola", "Guadalajara": "Hola",
        "Frankfurt": "Hallo", "Munich": "Servus", "Berlin": "Hallo",
        "Amsterdam": "Hallo", "Seoul": "Annyeong", "Shanghai": "Ni hao",
        "Beijing": "Ni hao", "Shenzhen": "Ni hao", "Hong Kong": "Ni hao",
        "Taipei": "Ni hao",
        "Sydney": "G'day", "Melbourne": "G'day", "Singapore": "Lah",
        "Dubai": "Marhaba", "New Delhi": "Namaste", "Mumbai": "Namaste", "Bangalore": "Namaste",
        "São Paulo": "Olá", "Rio de Janeiro": "Olá", "Bogota": "Hola",
        "Lima": "Hola", "Buenos Aires": "Hola", "Santiago": "Hola",
        "Rome": "Ciao", "Milan": "Ciao", "Madrid": "Hola",
        "Barcelona": "Hola", "Lisbon": "Olá", "Dublin": "Dia duit",
        "Zurich": "Gruezi", "Brussels": "Bonjour", "Vienna": "Servus",
        "Stockholm": "Hej", "Copenhagen": "Hej", "Oslo": "Hei",
        "Helsinki": "Moi", "Reykjavik": "Hallo", "Istanbul": "Merhaba",
        "Bangkok": "Sawasdee", "Manila": "Kumusta", "Jakarta": "Halo",
        "Nairobi": "Jambo", "Cairo": "Marhaba", "Johannesburg": "Sawubona",
        "Auckland": "Kia ora", "Doha": "Marhaba",
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
        Self.cityGreetings[city] ?? "Hello"
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
                                let showGreeting = index <= landedCity
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
                                        .frame(width: 0)
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


// MARK: - Sleeping Indicator View

struct SleepingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.zzz.fill")
                .font(.title3)
                .foregroundColor(.indigo)
                .rotationEffect(.degrees(animating ? 8 : -8))
                .symbolEffect(.pulse)

            Text("Sleeping")
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(.indigo)
                .opacity(animating ? 1.0 : 0.5)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animating = true
            }
        }
    }
}

// MARK: - Quick Status Indicator View

struct QuickStatusIndicatorView: View {
    let label: String
    let icon: String
    let expiry: Date?
    var accentColor: Color = .blue

    @State private var animating = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            if let expiry, expiry <= now {
                EmptyView()
            } else {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(accentColor)
                        .symbolEffect(.pulse)

                    Text(label)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(accentColor)

                    if let expiry {
                        Text(countdownText(from: now, to: expiry))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func countdownText(from now: Date, to expiry: Date) -> String {
        let interval = Int(expiry.timeIntervalSince(now))
        guard interval > 0 else { return "" }
        let h = interval / 3600
        let m = (interval % 3600) / 60
        let s = interval % 60
        if h > 0 {
            return String(format: "(%d:%02d:%02d left)", h, m, s)
        } else {
            return String(format: "(%d:%02d left)", m, s)
        }
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
        homeAirportCode: nil,
        displayStatus: "In Flight",
        isSleeping: true,
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
        homeArrivalLabel: "Back Home In",
        homeArrivalCity: "Orlando",
        nextDepartureTime: nil,
        nextFlightNumber: nil,
        nextFlightDestination: nil,
        nextDepartureLabel: nil,
        lastTripEndDate: Date().addingTimeInterval(-259200),  // 3 days ago
        lastTripDurationDays: 4,
        currentTripId: "test123",
        tripDayNumber: 2,
        tripTotalDays: 4,
        upcomingCities: ["Anchorage", "Hong Kong", "Shanghai"],
        tripLegsJSON: nil,
        quickStatus: nil,
        quickStatusIcon: nil,
        quickStatusExpiry: nil,
        flightDelayMinutes: nil,
        displayNameByPartnerJSON: nil,
        lastUpdated: Date().addingTimeInterval(-300),
        appVersion: "1.0"
    ),
    lastSyncTime: Date(),
    lastSyncError: nil
    )
}
