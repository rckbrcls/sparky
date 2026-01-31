//
//  CalendarDayContentView.swift
//  sparky
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct CalendarDayContentView: View {
    let day: Date
    let dataManager: CalendarDataManager
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<Memory.ID>
    let isPerformingBulkAction: Bool
    let onSelectMemory: (Memory) -> Void
    let onEditMemory: ((Memory) -> Void)?
    let onToggleSelection: (Memory) -> Void
    @Binding var expandedPeriods: Set<CalendarTimePeriod>
    let onEnsureMonthDataLoaded: (Date) -> Void

    private let calendar = Calendar.current

    var body: some View {
        List {
            dayHeader
                .listRowInsets(.init(top: 24, leading: 0, bottom: 24, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            let memories = dataManager.memoriesForDate(day)
            let allDayItems = allDayMemories(from: memories, date: day)

            allDaySection(memories: allDayItems)

            ForEach(CalendarTimePeriod.allCases.filter { $0 != .allDay }, id: \.self) { period in
                periodSection(period: period, memories: memories)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 70)
        }
        .onAppear {
            onEnsureMonthDataLoaded(day)
        }
    }

    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(primaryDateTitle(for: day))
                .appLargeTitleStyle()

            HStack(spacing: 10) {
                Text(secondaryDateTitle(for: day))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let label = relativeLabel(for: day) {
                    Text(label.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func allDaySection(memories: [Memory]) -> some View {
        CalendarPeriodSection(
            period: .allDay,
            memories: memories,
            date: day,
            isExpanded: expandedPeriods.contains(.allDay),
            isMultiSelecting: isMultiSelecting,
            selectedMemoryIDs: selectedMemoryIDs,
            isPerformingBulkAction: isPerformingBulkAction,
            onSelectMemory: onSelectMemory,
            onEditMemory: onEditMemory,
            onToggleSelection: onToggleSelection,
            onToggleExpanded: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedPeriods.contains(.allDay) {
                        expandedPeriods.remove(.allDay)
                    } else {
                        expandedPeriods.insert(.allDay)
                    }
                }
            }
        )
    }

    @ViewBuilder
    private func periodSection(period: CalendarTimePeriod, memories: [Memory]) -> some View {
        let periodMemories = memoriesForPeriod(period, from: memories, date: day)

        CalendarPeriodSection(
            period: period,
            memories: periodMemories,
            date: day,
            isExpanded: expandedPeriods.contains(period),
            isMultiSelecting: isMultiSelecting,
            selectedMemoryIDs: selectedMemoryIDs,
            isPerformingBulkAction: isPerformingBulkAction,
            onSelectMemory: onSelectMemory,
            onEditMemory: onEditMemory,
            onToggleSelection: onToggleSelection,
            onToggleExpanded: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedPeriods.contains(period) {
                        expandedPeriods.remove(period)
                    } else {
                        expandedPeriods.insert(period)
                    }
                }
            }
        )
    }

    private func primaryDateTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func secondaryDateTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd, yyyy"
        return formatter.string(from: date)
    }

    private func relativeLabel(for date: Date) -> String? {
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        return nil
    }

    private func allDayMemories(from memories: [Memory], date: Date) -> [Memory] {
        memories.filter { memory in
            // Check for scheduled all-day triggers
            guard let config = memory.scheduleConfig, config.isActive else {
                return false
            }
            return config.isAllDay
        }
    }

    private func timedMemories(from memories: [Memory], date: Date) -> [Memory] {
        memories.filter { memory in
            guard let config = memory.scheduleConfig, config.isActive else {
                return false
            }
            return !config.isAllDay
        }
    }

    private func memoriesForPeriod(_ period: CalendarTimePeriod, from memories: [Memory], date: Date) -> [Memory] {
        timedMemories(from: memories, date: date).filter { memory in
            guard let fireDate = fireDateForDay(memory: memory, day: date) else {
                return false
            }
            let hour = calendar.component(.hour, from: fireDate)
            return period.contains(hour: hour)
        }
    }

    /// Returns the fire date for a memory on a specific day, regardless of whether the date is in the past.
    /// This is used for calendar display where we need to show the scheduled time even for past events.
    private func fireDateForDay(memory: Memory, day: Date) -> Date? {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }

        // Get all dates for this memory on the specified day
        let datesOnDay = memory.dates(from: dayStart, to: dayEnd)
        if let matchingDate = datesOnDay.first {
            return matchingDate
        }

        // Fallback: check if the memory has a schedule config with a fireDate on this day
        if let config = memory.scheduleConfig, config.isActive,
           let fireDate = config.fireDate, calendar.isDate(fireDate, inSameDayAs: day) {
            return fireDate
        }

        return nil
    }
}
