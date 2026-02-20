//
//  TripCalendarView.swift
//  CrewLuve
//
//  Month calendar grid showing pilot schedule day status
//

import SwiftUI

struct TripCalendarView: View {
    let tripLegs: [TripLeg]
    @Binding var selectedDate: Date?

    @State private var displayedMonth: Date = {
        Calendar.current.startOfMonth(for: Date())
    }()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    /// Infer home periods from gaps between distinct trips
    private var homePeriods: [(start: Date, end: Date)] {
        var tripMap: [String: (start: Date, end: Date)] = [:]
        for leg in tripLegs where leg.type != .home {
            let key = leg.tripId ?? leg.id
            if let existing = tripMap[key] {
                tripMap[key] = (min(existing.start, leg.startTime), max(existing.end, leg.endTime))
            } else {
                tripMap[key] = (leg.startTime, leg.endTime)
            }
        }
        let bounds = tripMap.values.sorted { $0.start < $1.start }

        var periods: [(start: Date, end: Date)] = []
        for i in 0..<bounds.count - 1 {
            let gapStart = bounds[i].end
            let gapEnd = bounds[i + 1].start
            if gapEnd > gapStart { periods.append((gapStart, gapEnd)) }
        }
        return periods
    }

    var body: some View {
        VStack(spacing: 12) {
            // Month header
            monthHeader

            // Weekday labels
            weekdayRow

            // Day grid
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { index, date in
                    if let date {
                        CalendarDayView(
                            date: date,
                            status: dayStatus(for: date),
                            isToday: calendar.isDateInToday(date),
                            isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
        }
        .padding()
        .onChange(of: selectedDate) { _, newDate in
            guard let newDate else { return }
            let selectedMonth = calendar.startOfMonth(for: newDate)
            if selectedMonth != displayedMonth {
                displayedMonth = selectedMonth
            }
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
            }

            Spacer()

            Text(monthYearString)
                .font(.headline)

            Spacer()

            Button("Current Event") {
                withAnimation {
                    displayedMonth = calendar.startOfMonth(for: Date())
                    selectedDate = Date()
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
            }
        }
    }

    // MARK: - Weekday Row

    private var weekdayRow: some View {
        HStack {
            ForEach(calendar.veryShortWeekdaySymbols.indices, id: \.self) { index in
                Text(calendar.veryShortWeekdaySymbols[index])
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Day Computation

    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        let weekdayOffset = (calendar.component(.weekday, from: firstDay) - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: weekdayOffset)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }

    private var monthYearString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: displayedMonth)
    }

    private func moveMonth(by value: Int) {
        withAnimation {
            if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
                displayedMonth = calendar.startOfMonth(for: newMonth)
            }
        }
    }

    // MARK: - Day Status

    enum DayStatus {
        case flying, away, home, none
    }

    private func dayStatus(for date: Date) -> DayStatus {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return .none }

        var result: DayStatus = .none
        for leg in tripLegs {
            let overlaps = leg.startTime < dayEnd && leg.endTime > dayStart
            guard overlaps else { continue }

            switch leg.type {
            case .flight:
                return .flying  // Highest priority, return immediately
            case .turn, .layover:
                result = .away
            case .home:
                if result == .none { result = .home }
            default:
                result = .away
            }
        }

        // If no leg covered this day, check inferred home periods (gaps between trips)
        if result == .none {
            for period in homePeriods {
                if period.start < dayEnd && period.end > dayStart {
                    return .home
                }
            }
        }

        return result
    }
}

// MARK: - Calendar Day View

struct CalendarDayView: View {
    let date: Date
    let status: TripCalendarView.DayStatus
    let isToday: Bool
    let isSelected: Bool

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: date))"
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(dayNumber)
                .font(.caption)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(isSelected ? .white.opacity(0.8) : .primary)

            statusIcon
                .font(.system(size: 10))
                .frame(height: 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background {
            if isSelected {
                Circle()
                    .fill(.blue)
                    .frame(width: 36, height: 36)
            } else if isToday {
                Circle()
                    .stroke(.blue, lineWidth: 1.5)
                    .frame(width: 36, height: 36)
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .flying:
            Image(systemName: "airplane")
                .foregroundColor(isSelected ? .white.opacity(0.8) : .green)
        case .away:
            Circle()
                .fill(isSelected ? .white.opacity(0.8) : .orange)
                .frame(width: 6, height: 6)
        case .home:
            Image(systemName: "house.fill")
                .foregroundColor(isSelected ? .white.opacity(0.8) : .green)
        case .none:
            EmptyView()
        }
    }
}

// MARK: - Calendar Extension

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
