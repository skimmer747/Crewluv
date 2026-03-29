//
//  EventTimelineView.swift
//  CrewLuve
//
//  Schedule view: month calendar + scrollable leg list
//

import SwiftUI

struct EventTimelineView: View {
    let status: SharedPilotStatus

    @State private var selectedDate: Date? = nil
    @State private var isProgrammaticScroll = false
    @State private var isCurrentEventScroll = false
    @State private var pinnedSectionDate: Date?

    private var legs: [TripLeg] {
        status.tripLegs.sorted { $0.startTime < $1.startTime }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Calendar grid – pinned at top
            TripCalendarView(
                tripLegs: legs,
                selectedDate: $selectedDate,
                onCurrentEvent: {
                    isCurrentEventScroll = true
                    selectedDate = Date()
                }
            )

            Divider()
                .padding(.horizontal)

            // Leg list – scrollable
            ScrollViewReader { proxy in
                ScrollView {
                    if legs.isEmpty {
                        emptyState
                    } else {
                        legList
                    }
                }
                .coordinateSpace(name: "timeline")
                .onPreferenceChange(SectionOffsetKey.self) { offsets in
                    // The pinned header is the one closest to (but not far below) the top
                    pinnedSectionDate = offsets
                        .filter { $0.minY <= 20 }
                        .max(by: { $0.minY < $1.minY })?
                        .date
                }
                .scrollEdgeEffectStyle(.soft, for: .vertical)
                .onChange(of: selectedDate) { _, newDate in
                    guard let newDate else { return }
                    let cal = Calendar.current
                    let now = Date()

                    if isCurrentEventScroll {
                        isCurrentEventScroll = false

                        // Find the section containing the up-next or active leg
                        var targetSection: DateSection?

                        if let upNextLeg = legs.first(where: { $0.startTime > now }) {
                            let day = cal.startOfDay(for: upNextLeg.startTime)
                            targetSection = groupedSections.first { cal.isDate($0.date, inSameDayAs: day) }
                        } else if let activeLeg = legs.first(where: { $0.startTime <= now && now <= $0.endTime }) {
                            let day = cal.startOfDay(for: activeLeg.startTime)
                            targetSection = groupedSections.first { cal.isDate($0.date, inSameDayAs: day) }
                        } else {
                            targetSection = groupedSections.first { cal.isDate($0.date, inSameDayAs: now) }
                        }

                        if let targetSection {
                            isProgrammaticScroll = true
                            withAnimation {
                                proxy.scrollTo(targetSection.dateId, anchor: .top)
                            }
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(500))
                                isProgrammaticScroll = false
                            }
                        }
                        return
                    }

                    // Calendar date tap: scroll to the day section
                    var target: DateSection?
                    if cal.isDateInToday(newDate),
                       let activeLeg = legs.first(where: { $0.startTime <= now && now <= $0.endTime }) {
                        let activeDay = cal.startOfDay(for: activeLeg.startTime)
                        target = groupedSections.first(where: { cal.isDate($0.date, inSameDayAs: activeDay) })
                    }

                    if target == nil {
                        target = groupedSections.first(where: { cal.isDate($0.date, inSameDayAs: newDate) })
                            ?? groupedSections.last(where: { $0.date <= cal.startOfDay(for: newDate) })
                    }

                    if let target {
                        isProgrammaticScroll = true
                        withAnimation {
                            proxy.scrollTo(target.dateId, anchor: .top)
                        }
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(500))
                            isProgrammaticScroll = false
                        }
                    }
                }
            }
        }
        .task {
            isCurrentEventScroll = true
            selectedDate = Date()
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
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(groupedSections, id: \.date) { section in
                sectionView(section)
                    .id(section.dateId)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Section View

    private func sectionView(_ section: DateSection) -> some View {
        Section {
            TimelineView(.periodic(from: Date(), by: 60)) { context in
                sectionContent(section, upNextID: upNextLegID(at: context.date))
            }
        } header: {
            sectionHeader(section)
        }
    }

    @ViewBuilder
    private func sectionContent(_ section: DateSection, upNextID: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(section.legs.enumerated()), id: \.element.id) { index, leg in
                TimelineRowView(
                    leg: leg,
                    homeAirportCode: status.homeAirportCode,
                    isUpNext: leg.id == upNextID
                )
                .onTapGesture {
                    selectedDate = Calendar.current.startOfDay(for: leg.startTime)
                }

                // Gap between consecutive legs (hide when < 1 minute)
                if index < section.legs.count - 1 {
                    legGapView(section: section, index: index, leg: leg)
                }
            }
        }
    }

    @ViewBuilder
    private func legGapView(section: DateSection, index: Int, leg: TripLeg) -> some View {
        let nextLeg = section.legs[index + 1]
        let gap = nextLeg.startTime.timeIntervalSince(leg.endTime)
        if gap >= 60 {
            TimeGapView(fromLeg: leg, toLeg: nextLeg)
        }
    }

    @ViewBuilder
    private func sectionHeader(_ section: DateSection) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(section.date)
        let isPinned = pinnedSectionDate.map { cal.isDate($0, inSameDayAs: section.date) } ?? false
        SectionHeaderLabel(
            title: sectionHeaderText(for: section.date),
            isToday: isToday,
            isHighlighted: isToday || isPinned,
            date: section.date
        )
    }

    // MARK: - Up Next

    /// Returns the ID of the first leg that hasn't started yet and isn't currently active.
    private func upNextLegID(at now: Date) -> String? {
        // Skip any leg that is currently active (already in progress)
        legs.first { $0.startTime > now }?.id
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

// MARK: - Section Header Label

private struct SectionHeaderLabel: View {
    let title: String
    let isToday: Bool
    let isHighlighted: Bool
    let date: Date

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(isHighlighted ? .black : .secondary)
            .textCase(.uppercase)
            .padding(.horizontal, isHighlighted ? 8 : 0)
            .padding(.vertical, isHighlighted ? 4 : 0)
            .background(highlightBackground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .padding(.bottom, 2)
            .background(.bar)
            .overlay(offsetTracker)
    }

    @ViewBuilder
    private var highlightBackground: some View {
        if isHighlighted {
            RoundedRectangle(cornerRadius: 6)
                .fill(isToday ? Color.green : Color.yellow)
        }
    }

    private var offsetTracker: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: SectionOffsetKey.self,
                value: [SectionOffset(date: date, minY: geo.frame(in: .named("timeline")).minY)]
            )
        }
    }
}

// MARK: - Section Offset Tracking

private struct SectionOffset: Equatable {
    let date: Date
    let minY: CGFloat
}

private struct SectionOffsetKey: PreferenceKey {
    static var defaultValue: [SectionOffset] = []
    static func reduce(value: inout [SectionOffset], nextValue: () -> [SectionOffset]) {
        value.append(contentsOf: nextValue())
    }
}
