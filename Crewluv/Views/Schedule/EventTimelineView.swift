//
//  EventTimelineView.swift
//  CrewLuv
//
//  Schedule view: month calendar + scrollable leg list
//

import SwiftUI

struct EventTimelineView: View {
    let status: SharedPilotStatus

    @State private var selectedDate: Date? = nil

    private var legs: [TripLeg] {
        status.tripLegs.sorted { $0.startTime < $1.startTime }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Calendar grid – pinned at top
            TripCalendarView(
                tripLegs: legs,
                selectedDate: $selectedDate
            )

            Divider()
                .padding(.horizontal)

            // Leg list – scrollable
            ScrollView {
                if legs.isEmpty {
                    emptyState
                } else {
                    legList
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .vertical)
        }
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No schedule data")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Schedule will appear when your pilot's Duty app sends trip details.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    // MARK: - Leg List

    private var legList: some View {
        ScrollViewReader { proxy in
            LazyVStack(spacing: 0) {
                ForEach(groupedSections, id: \.date) { section in
                    sectionView(section)
                        .id(section.dateId)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .onChange(of: selectedDate) { _, newDate in
                guard let newDate else { return }
                let cal = Calendar.current
                let startOfNew = cal.startOfDay(for: newDate)

                // Exact match first, then fall back to the last section on or before the selected day
                let target = groupedSections.first(where: { cal.isDate($0.date, inSameDayAs: newDate) })
                    ?? groupedSections.last(where: { $0.date <= startOfNew })

                if let target {
                    withAnimation {
                        proxy.scrollTo(target.dateId, anchor: .top)
                    }
                }
            }
        }
    }

    // MARK: - Section View

    private func sectionView(_ section: DateSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sectionHeaderText(for: section.date))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.top, 12)
                .padding(.bottom, 2)

            ForEach(Array(section.legs.enumerated()), id: \.element.id) { index, leg in
                TimelineRowView(leg: leg)

                // Gap between consecutive legs (hide when < 1 minute)
                if index < section.legs.count - 1 {
                    let nextLeg = section.legs[index + 1]
                    let gap = nextLeg.startTime.timeIntervalSince(leg.endTime)
                    if gap >= 60 {
                        TimeGapView(fromLeg: leg, toLeg: nextLeg)
                    }
                }
            }
        }
    }

    // MARK: - Grouping

    struct DateSection {
        let date: Date
        let dateId: String
        let legs: [TripLeg]
    }

    private var groupedSections: [DateSection] {
        let cal = Calendar.current
        var dict: [Date: [TripLeg]] = [:]

        for leg in legs {
            let day = cal.startOfDay(for: leg.startTime)
            dict[day, default: []].append(leg)
        }

        return dict.keys.sorted().map { day in
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            return DateSection(
                date: day,
                dateId: fmt.string(from: day),
                legs: dict[day]!.sorted { $0.startTime < $1.startTime }
            )
        }
    }

    private func sectionHeaderText(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "Today"
        } else if cal.isDateInYesterday(date) {
            return "Yesterday"
        } else if cal.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let fmt = DateFormatter()
            fmt.dateFormat = "EEEE, MMM d"
            return fmt.string(from: date)
        }
    }
}
