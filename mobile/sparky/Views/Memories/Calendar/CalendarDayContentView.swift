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
            let allDayItems = allDayOccurrences(from: memories, date: day)

            allDaySection(occurrences: allDayItems)

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
    private func allDaySection(occurrences: [MemoryOccurrence]) -> some View {
        CalendarPeriodSection(
            period: .allDay,
            occurrences: occurrences,
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
        let periodOccurrences = occurrencesForPeriod(period, from: memories, date: day)

        CalendarPeriodSection(
            period: period,
            occurrences: periodOccurrences,
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

    private func allDayOccurrences(from memories: [Memory], date: Date) -> [MemoryOccurrence] {
        let dayStart = calendar.startOfDay(for: date)
        return memories
            .filter { memory in
                guard let schedule = memory.scheduleConfig, schedule.isActive else { return false }
                return schedule.isAllDay
            }
            .map { MemoryOccurrence(memory: $0, occurrenceDate: dayStart) }
    }

    private func occurrencesForDay(memory: Memory, day: Date) -> [MemoryOccurrence] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }
        return memory.dates(from: dayStart, to: dayEnd)
            .map { MemoryOccurrence(memory: memory, occurrenceDate: $0) }
    }

    private func occurrencesForPeriod(_ period: CalendarTimePeriod, from memories: [Memory], date: Date) -> [MemoryOccurrence] {
        memories
            .filter { memory in
                guard let schedule = memory.scheduleConfig, schedule.isActive else { return false }
                return !schedule.isAllDay
            }
            .flatMap { occurrencesForDay(memory: $0, day: date) }
            .filter { period.contains(hour: calendar.component(.hour, from: $0.occurrenceDate)) }
            .sorted { $0.occurrenceDate < $1.occurrenceDate }
    }
}
