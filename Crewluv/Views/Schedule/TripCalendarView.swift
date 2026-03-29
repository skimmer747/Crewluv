//
//  TripCalendarView.swift
//  CrewLuve
//
//  Month calendar with continuous trip bars spanning across days
//

import SwiftUI

struct TripCalendarView: View {
    let tripLegs: [TripLeg]
    @Binding var selectedDate: Date?
    var onCurrentEvent: () -> Void = {}

    @State private var displayedMonth: Date = {
        Calendar.current.startOfMonth(for: Date())
    }()

    @State private var weeks: [CalendarWeekData] = []

    private static let gridLineColor = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.4)
            : UIColor.black.withAlphaComponent(0.15)
    })

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 8) {
            monthHeader
            weekdayRow

            VStack(spacing: 0) {
                ForEach(weeks) { week in
                    CalendarWeekRowView(week: week, selectedDate: $selectedDate)
                }
            }
            .overlay { calendarGridLines }
        }
        .padding()
        .onChange(of: selectedDate) { _, newDate in
            guard let newDate else { return }
            let selectedMonth = calendar.startOfMonth(for: newDate)
            if selectedMonth != displayedMonth {
                displayedMonth = selectedMonth
            }
        }
        .onChange(of: displayedMonth) {
            rebuildWeeks()
        }
        .onChange(of: tripLegs.count) {
            rebuildWeeks()
        }
        .onAppear {
            rebuildWeeks()
        }
    }

    private func rebuildWeeks() {
        weeks = CalendarDataBuilder.buildWeeks(for: displayedMonth, tripLegs: tripLegs)
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
                }
                onCurrentEvent()
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
        HStack(spacing: 0) {
            ForEach(calendar.veryShortWeekdaySymbols.indices, id: \.self) { index in
                Text(calendar.veryShortWeekdaySymbols[index])
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Grid Lines

    private var calendarGridLines: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let rowCount = CGFloat(weeks.count)

            // Vertical lines between columns 1–6
            ForEach(1..<7, id: \.self) { col in
                Rectangle()
                    .fill(Self.gridLineColor)
                    .frame(width: 0.5)
                    .position(x: CGFloat(col) * width / 7, y: height / 2)
            }

            // Horizontal lines between rows
            ForEach(1..<max(1, weeks.count), id: \.self) { row in
                Rectangle()
                    .fill(Self.gridLineColor)
                    .frame(height: 0.5)
                    .position(x: width / 2, y: CGFloat(row) * height / rowCount)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Helpers

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
}

// MARK: - Calendar Extension

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
