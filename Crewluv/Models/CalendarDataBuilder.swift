//
//  CalendarDataBuilder.swift
//  CrewLuve
//
//  Transforms [TripLeg] + displayed month into renderable calendar week data
//

import Foundation

// MARK: - Data Types

struct CalendarDayData: Identifiable {
    let id: String          // "yyyy-MM-dd" or "pad-N"
    let date: Date
    let dayNumber: Int
    let isToday: Bool
    let isInMonth: Bool     // false for padding cells from adjacent months
}

struct CalendarBarSegment: Identifiable {
    let id: String
    let startFraction: Double   // 0.0–7.0 coordinate space
    let endFraction: Double
    let category: Category
    let layoverCode: String?
    let hasRoundedLeading: Bool
    let hasRoundedTrailing: Bool

    enum Category {
        case onDuty
        case offDuty
    }
}

struct CalendarWeekData: Identifiable {
    let id: Int             // week index within the month grid
    let days: [CalendarDayData]
    let segments: [CalendarBarSegment]
}

// MARK: - Builder

enum CalendarDataBuilder {

    static func buildWeeks(
        for month: Date,
        tripLegs: [TripLeg],
        calendar: Calendar = .current
    ) -> [CalendarWeekData] {
        let allDays = buildMonthGrid(for: month, calendar: calendar)
        let weeks = allDays.chunked(into: 7)

        return weeks.enumerated().map { weekIndex, weekDays in
            let segments = buildSegments(
                for: weekDays,
                weekIndex: weekIndex,
                tripLegs: tripLegs,
                calendar: calendar
            )
            return CalendarWeekData(id: weekIndex, days: weekDays, segments: segments)
        }
    }

    // MARK: - Month Grid

    private static func buildMonthGrid(
        for month: Date,
        calendar: Calendar
    ) -> [CalendarDayData] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        let weekdayOffset = (calendar.component(.weekday, from: firstOfMonth) - calendar.firstWeekday + 7) % 7
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"

        var days: [CalendarDayData] = []

        // Leading days from previous month
        for i in 0..<weekdayOffset {
            if let date = calendar.date(byAdding: .day, value: -(weekdayOffset - i), to: firstOfMonth) {
                days.append(CalendarDayData(
                    id: dateFmt.string(from: date),
                    date: date,
                    dayNumber: calendar.component(.day, from: date),
                    isToday: calendar.isDateInToday(date),
                    isInMonth: false
                ))
            }
        }

        // Days in the current month
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(CalendarDayData(
                    id: dateFmt.string(from: date),
                    date: date,
                    dayNumber: day,
                    isToday: calendar.isDateInToday(date),
                    isInMonth: true
                ))
            }
        }

        // Trailing days to fill the last week
        let remainder = days.count % 7
        if remainder > 0 {
            let trailingCount = 7 - remainder
            if let lastInMonth = calendar.date(byAdding: .day, value: range.count - 1, to: firstOfMonth) {
                for i in 1...trailingCount {
                    if let date = calendar.date(byAdding: .day, value: i, to: lastInMonth) {
                        days.append(CalendarDayData(
                            id: dateFmt.string(from: date),
                            date: date,
                            dayNumber: calendar.component(.day, from: date),
                            isToday: calendar.isDateInToday(date),
                            isInMonth: false
                        ))
                    }
                }
            }
        }

        return days
    }

    // MARK: - Bar Segments

    private static func buildSegments(
        for weekDays: [CalendarDayData],
        weekIndex: Int,
        tripLegs: [TripLeg],
        calendar: Calendar
    ) -> [CalendarBarSegment] {
        guard let firstDay = weekDays.first else { return [] }

        let weekStart = calendar.startOfDay(for: firstDay.date)
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return [] }
        let weekDuration = weekEnd.timeIntervalSince(weekStart)

        // Group legs by tripId (nil tripId legs each become their own group)
        var tripGroups: [String: [TripLeg]] = [:]
        var soloIndex = 0
        for leg in tripLegs {
            guard leg.type != .home else { continue }
            // Check if leg overlaps this week
            guard leg.startTime < weekEnd && leg.endTime > weekStart else { continue }

            let key: String
            if let tripId = leg.tripId {
                key = tripId
            } else {
                key = "__solo_\(soloIndex)"
                soloIndex += 1
            }
            tripGroups[key, default: []].append(leg)
        }

        var segments: [CalendarBarSegment] = []
        var segmentIndex = 0

        for (tripKey, groupLegs) in tripGroups {
            let sorted = groupLegs.sorted { $0.startTime < $1.startTime }

            // Find full trip boundaries (across all legs with this tripId, not just this week)
            let allTripLegs = tripLegs.filter { leg in
                if let tripId = leg.tripId {
                    return tripId == tripKey
                }
                return false
            }
            let fullTripStart = (allTripLegs.isEmpty ? sorted : allTripLegs)
                .map(\.startTime).min() ?? sorted.first!.startTime
            let fullTripEnd = (allTripLegs.isEmpty ? sorted : allTripLegs)
                .map(\.endTime).max() ?? sorted.last!.endTime

            // Is this the first/last week row for this trip?
            let tripStartsThisWeek = fullTripStart >= weekStart && fullTripStart < weekEnd
            let tripEndsThisWeek = fullTripEnd > weekStart && fullTripEnd <= weekEnd

            for (i, leg) in sorted.enumerated() {
                let clampedStart = max(leg.startTime, weekStart)
                let clampedEnd = min(leg.endTime, weekEnd)

                let startFraction = clampedStart.timeIntervalSince(weekStart) / weekDuration * 7.0
                var endFraction = clampedEnd.timeIntervalSince(weekStart) / weekDuration * 7.0

                // Close small gaps between consecutive legs in the same trip
                if i < sorted.count - 1 {
                    let nextLeg = sorted[i + 1]
                    let gap = nextLeg.startTime.timeIntervalSince(leg.endTime)
                    if gap > 0 && gap < 1800 { // < 30 minutes
                        let nextStart = max(nextLeg.startTime, weekStart)
                        let nextFraction = nextStart.timeIntervalSince(weekStart) / weekDuration * 7.0
                        endFraction = nextFraction
                    }
                }

                guard endFraction > startFraction else { continue }

                let isFirstLegOfTrip = leg.startTime <= fullTripStart
                let isLastLegOfTrip = leg.endTime >= fullTripEnd

                let category: CalendarBarSegment.Category = switch leg.type {
                case .layover: .offDuty
                default: .onDuty
                }

                let layoverCode: String? = if leg.type == .layover {
                    leg.airportCode ?? leg.arrivalAirport
                } else {
                    nil
                }

                segments.append(CalendarBarSegment(
                    id: "\(weekIndex)-\(segmentIndex)",
                    startFraction: startFraction,
                    endFraction: endFraction,
                    category: category,
                    layoverCode: layoverCode,
                    hasRoundedLeading: isFirstLegOfTrip && tripStartsThisWeek,
                    hasRoundedTrailing: isLastLegOfTrip && tripEndsThisWeek
                ))
                segmentIndex += 1
            }
        }

        return segments.sorted { $0.startFraction < $1.startFraction }
    }
}

// MARK: - Array Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
