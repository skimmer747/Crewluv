//
//  SunCircleDetailView.swift
//  CrewLuve
//
//  Expanded sun circle detail with weather info, daylight duration, and pilot location
//

import SwiftUI
import Combine

struct SunCircleDetailView: View {
    let sunrise: Date
    let sunset: Date
    let isDaylight: Bool
    let timezone: String?
    let cityName: String
    let weather: WeatherSnapshot
    var nextDepartureTime: Date? = nil
    var flightDelayMinutes: Int? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var deviceColorScheme
    @State private var appeared = false
    @State private var dragOffset: CGFloat = 0
    @State private var liveLocalTime: String = ""
    @State private var liveHomeTime: String = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Blurred dismissable background
            Color.black.opacity(appeared ? 0.3 : 0)
                .background(.ultraThinMaterial.opacity(appeared ? 1 : 0))
                .ignoresSafeArea()
                .onTapGesture { dismissView() }

            // Card
            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // Header: city name + close button
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                    Text(cityName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                    Button { dismissView() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

                // Local + home time (hide left pane when timezone unavailable so we don't show icon + empty text)
                HStack {
                    if !liveLocalTime.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: isDaylight ? "sun.max.fill" : "moon.fill")
                                .foregroundColor(isDaylight ? .orange : .indigo)
                                .font(.subheadline)
                            Text(liveLocalTime)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text(liveHomeTime)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Image(systemName: "house.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal, 20)
                .contentTransition(.numericText())
                .padding(.bottom, 8)
                .onReceive(timer) { _ in updateLocalTime() }
                .onAppear { updateLocalTime() }

                // Large sun circle
                SunCircleView(
                    sunrise: sunrise,
                    sunset: sunset,
                    isDaylight: isDaylight,
                    timezone: timezone,
                    nextDepartureTime: nextDepartureTime,
                    flightDelayMinutes: flightDelayMinutes,
                    size: 300
                )
                .scaleEffect(appeared ? 1.0 : 0.5)
                .opacity(appeared ? 1.0 : 0)

                // Weather summary row
                HStack(spacing: 12) {
                    Image(systemName: weather.conditionSymbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.title)
                    Text(weather.temperature)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(weather.conditionDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)

                Divider()
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)

                // Daylight info
                VStack(spacing: 12) {
                    // Daylight duration
                    HStack(spacing: 8) {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.orange)
                        Text(daylightDurationText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    // Sunrise & sunset times
                    HStack(spacing: 24) {
                        Label(formatTime(sunrise), systemImage: "sunrise.fill")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Label(formatTime(sunset), systemImage: "sunset.fill")
                            .font(.subheadline)
                            .foregroundColor(.indigo)
                    }

                    // Pilot location
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.red)
                        Text("In \(cityName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 360)
            .background {
                WeatherBackgroundView(
                    animationType: WeatherAnimationType.from(weather: weather),
                    opacity: appeared ? 1 : 0
                )
                .clipShape(.rect(cornerRadius: 28))
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .environment(\.colorScheme, (isDaylight && deviceColorScheme == .light) ? .light : .dark)
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            dismissView()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .presentationBackground(.clear)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }

    private func dismissView() {
        withAnimation(.easeOut(duration: 0.2)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
        }
    }

    // MARK: - Computed Properties

    private var daylightDurationText: String {
        // Clamp to zero so inverted sunset/sunrise (e.g. polar regions) shows "0h 0m" not negative values
        let interval = max(0, sunset.timeIntervalSince(sunrise))
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h \(minutes)m of daylight"
    }

    private func updateLocalTime() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        // Pilot's local time
        if let tzId = timezone, let tz = TimeZone(identifier: tzId) {
            formatter.timeZone = tz
            liveLocalTime = formatter.string(from: now)
        } else {
            liveLocalTime = ""
        }

        // Home (device) time
        formatter.timeZone = .current
        liveHomeTime = formatter.string(from: now)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        if let tzId = timezone, let tz = TimeZone(identifier: tzId) {
            formatter.timeZone = tz
        }
        return formatter.string(from: date)
    }
}
