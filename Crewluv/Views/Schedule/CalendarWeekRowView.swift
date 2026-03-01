//
//  CalendarWeekRowView.swift
//  CrewLuve
//
//  Renders one week row: layover codes, day numbers, trip bar strip, current-time line
//

import SwiftUI

struct CalendarWeekRowView: View {
    let week: CalendarWeekData
    @Binding var selectedDate: Date?

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            dayNumberRow
            layoverCodeRow
            CalendarTripBarView(segments: week.segments)
        }
        .overlay { currentTimeLine }
    }

    // MARK: - Day Number Row

    private var dayNumberRow: some View {
        HStack(spacing: 0) {
            ForEach(week.days) { day in
                let isSelected = selectedDate.map {
                    calendar.isDate($0, inSameDayAs: day.date)
                } ?? false

                Text("\(day.dayNumber)")
                    .font(.caption)
                    .fontWeight(day.isToday ? .bold : .regular)
                    .foregroundColor(dayForegroundColor(day: day, isSelected: isSelected))
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background {
                        if isSelected {
                            Circle()
                                .fill(.blue)
                                .frame(width: 26, height: 26)
                        } else if day.isToday {
                            Circle()
                                .stroke(.blue, lineWidth: 1.5)
                                .frame(width: 26, height: 26)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDate = day.date
                    }
            }
        }
    }

    private func dayForegroundColor(day: CalendarDayData, isSelected: Bool) -> Color {
        if isSelected {
            return .white
        }
        if !day.isInMonth {
            return .secondary.opacity(0.4)
        }
        return .primary
    }

    // MARK: - Layover Code Row

    private var layoverCodeRow: some View {
        GeometryReader { geo in
            ForEach(layoverSegments) { segment in
                let midFraction = (segment.startFraction + segment.endFraction) / 2.0
                let xPosition = midFraction / 7.0 * geo.size.width

                if let code = segment.layoverCode {
                    Text(code)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(CalendarTripBarView.offDutyColor)
                        .position(x: xPosition, y: 8)
                }
            }
        }
        .frame(height: 12)
    }

    private var layoverSegments: [CalendarBarSegment] {
        week.segments.filter { $0.layoverCode != nil }
    }

    // MARK: - Current Time Line

    @ViewBuilder
    private var currentTimeLine: some View {
        let todayIndex = week.days.firstIndex(where: \.isToday)
        if let todayIndex {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                GeometryReader { geo in
                    let dayWidth = geo.size.width / 7.0
                    let now = timeline.date
                    let startOfToday = calendar.startOfDay(for: now)
                    let secondsIntoDay = now.timeIntervalSince(startOfToday)
                    let dayFraction = secondsIntoDay / 86400.0
                    let xPosition = (CGFloat(todayIndex) + dayFraction) * dayWidth

                    Rectangle()
                        .fill(.green)
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                        .position(x: xPosition, y: geo.size.height / 2)
                }
            }
        }
    }
}
