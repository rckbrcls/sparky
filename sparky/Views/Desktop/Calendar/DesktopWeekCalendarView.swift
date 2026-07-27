#if os(macOS)

import SwiftUI

struct DesktopWeekCalendarView: View {
    @ObservedObject var dataManager: CalendarDataManager

    let days: [Date]
    let onSelect: (Memory) -> Void

    private let calendar = Calendar.current
    private let timeColumnWidth: CGFloat = 76
    private let hourHeight: CGFloat = 62
    private let allDayHeight: CGFloat = 116

    var body: some View {
        VStack(spacing: 0) {
            weekdayHeader
            Divider()
                .overlay(Color.Theme.separator)
            allDayRow
            Divider()
                .overlay(Color.Theme.separator)
            hourlyGrid
        }
        .background(Color.Theme.background)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: timeColumnWidth, height: 54)
                .accessibilityHidden(true)

            ForEach(days, id: \.self) { day in
                HStack(spacing: 5) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.Theme.textSecondary)

                    Text(day.formatted(.dateTime.day()))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            calendar.isDateInToday(day)
                                ? Color.Theme.accentForeground
                                : Color.Theme.textPrimary
                        )
                        .frame(width: 32, height: 32)
                        .background {
                            if calendar.isDateInToday(day) {
                                Circle().fill(Color.accentColor)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    day.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
                )
            }
        }
    }

    private var allDayRow: some View {
        HStack(spacing: 0) {
            Text("all-day")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.Theme.textSecondary)
                .frame(width: timeColumnWidth, height: allDayHeight, alignment: .top)
                .padding(.top, 10)

            ForEach(days, id: \.self) { day in
                DesktopAllDayColumn(
                    occurrences: allDayOccurrences(on: day),
                    onSelect: onSelect
                )
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: allDayHeight)
    }

    private var hourlyGrid: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    hourLabels

                    ForEach(days, id: \.self) { day in
                        DesktopWeekDayColumn(
                            day: day,
                            occurrences: timedOccurrences(on: day),
                            hourHeight: hourHeight,
                            onSelect: onSelect
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .scrollIndicators(.visible)
            .onAppear {
                proxy.scrollTo(8, anchor: .top)
            }
        }
    }

    private var hourLabels: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.Theme.textSecondary)
                    .frame(width: timeColumnWidth, height: hourHeight, alignment: .top)
                    .padding(.top, -7)
                    .id(hour)
                    .accessibilityLabel("\(hour):00")
            }
        }
    }

    private func allDayOccurrences(on date: Date) -> [MemoryOccurrence] {
        dataManager.occurrencesForDate(date).filter(\.isAllDay)
    }

    private func timedOccurrences(on date: Date) -> [MemoryOccurrence] {
        dataManager.occurrencesForDate(date).filter { !$0.isAllDay }
    }
}

#endif
