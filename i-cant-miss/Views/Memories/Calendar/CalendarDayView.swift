//
//  CalendarDayView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct CalendarDayView: View {
    @ObservedObject var dataManager: CalendarDataManager
    @Binding var currentDate: Date
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<MemoryModel.ID>
    let isPerformingBulkAction: Bool
    let onSelectMemory: (MemoryModel) -> Void
    let onToggleSelection: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?

    @State private var displayedDate: Date
    @State private var dayAnchor: Date

    private let calendar = Calendar.current

    private var pages: [Date] {
        generateDayRange()
    }

    init(
        dataManager: CalendarDataManager,
        currentDate: Binding<Date>,
        isMultiSelecting: Bool,
        selectedMemoryIDs: Set<MemoryModel.ID>,
        isPerformingBulkAction: Bool,
        onSelectMemory: @escaping (MemoryModel) -> Void,
        onToggleSelection: @escaping (MemoryModel) -> Void,
        onEditMemory: ((MemoryModel) -> Void)?
    ) {
        self.dataManager = dataManager
        self._currentDate = currentDate
        self.isMultiSelecting = isMultiSelecting
        self.selectedMemoryIDs = selectedMemoryIDs
        self.isPerformingBulkAction = isPerformingBulkAction
        self.onSelectMemory = onSelectMemory
        self.onToggleSelection = onToggleSelection
        self.onEditMemory = onEditMemory

        let startOfDay = Calendar.current.startOfDay(for: currentDate.wrappedValue)
        self._displayedDate = State(initialValue: startOfDay)
        self._dayAnchor = State(initialValue: startOfDay)
    }

    var body: some View {
        GeometryReader { proxy in
            TabView(selection: $displayedDate) {
                ForEach(pages, id: \.self) { day in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            dayHeader(for: day)

                            DaySection(
                                date: day,
                                memories: dataManager.memoriesForDate(day),
                                isMultiSelecting: isMultiSelecting,
                                selectedMemoryIDs: selectedMemoryIDs,
                                isPerformingBulkAction: isPerformingBulkAction,
                                onSelectMemory: onSelectMemory,
                                onToggleSelection: onToggleSelection,
                                onEditMemory: onEditMemory
                            )
                        }
                        .padding(.vertical, 16)
                        .id(day)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .tag(day)
                    .onAppear {
                        ensureMonthDataLoaded(for: day)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .onAppear {
            ensureMonthDataLoaded(for: displayedDate)
        }
        .onChange(of: displayedDate) { _, newValue in
            currentDate = newValue
            ensureMonthDataLoaded(for: newValue)
        }
        .onChange(of: currentDate) { _, newValue in
            displayedDate = calendar.startOfDay(for: newValue)
            dayAnchor = displayedDate
        }
    }

    private func dayHeader(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(primaryDateTitle(for: date))
                .font(.largeTitle)
                .fontWeight(.bold)

            HStack(spacing: 10) {
                Text(secondaryDateTitle(for: date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let label = relativeLabel(for: date) {
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

    private func primaryDateTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private func secondaryDateTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
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

    private func ensureMonthDataLoaded(for date: Date) {
        let monthKey = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        dataManager.ensureMonthLoaded(monthKey)
    }

    private func generateDayRange() -> [Date] {
        let anchor = calendar.startOfDay(for: dayAnchor)
        return (-15...15).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: anchor)
        }
    }
}

// MARK: - Day Section

private struct DaySection: View {
    let date: Date
    let memories: [MemoryModel]
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<MemoryModel.ID>
    let isPerformingBulkAction: Bool
    let onSelectMemory: (MemoryModel) -> Void
    let onToggleSelection: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?

    private let calendar = Calendar.current

    private var allDayMemories: [MemoryModel] {
        memories.filter { memory in
            guard let fireDate = memory.nextFireDate(referenceDate: date) else {
                return false
            }
            let components = calendar.dateComponents([.hour, .minute], from: fireDate)
            return (components.hour ?? 0) == 0 && (components.minute ?? 0) == 0
        }
    }

    private var timedMemories: [MemoryModel] {
        memories.filter { memory in
            guard let fireDate = memory.nextFireDate(referenceDate: date) else {
                return false
            }
            let components = calendar.dateComponents([.hour, .minute], from: fireDate)
            return (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if memories.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    if !allDayMemories.isEmpty {
                        memoriesSection(title: "All Day", memories: allDayMemories)
                    }

                    if !timedMemories.isEmpty {
                        memoriesSection(title: "Timed Events", memories: timedMemories)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func memoriesSection(title: String, memories: [MemoryModel]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            ForEach(memories) { memory in
                MemoryListItemButton(
                    memory: memory,
                    isMultiSelecting: isMultiSelecting,
                    isSelected: selectedMemoryIDs.contains(memory.id),
                    isDisabled: isPerformingBulkAction,
                    onSelect: onSelectMemory,
                    onToggleSelection: onToggleSelection,
                    onEdit: onEditMemory
                )
                .padding(.horizontal, 20)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No events for this day")
                .font(.headline)

            Text("There are no memories scheduled on this date.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    let date = Date()
    let dataManager = CalendarDataManager(memoryService: environment.memoryService)

    return CalendarDayView(
        dataManager: dataManager,
        currentDate: .constant(date),
        isMultiSelecting: false,
        selectedMemoryIDs: [],
        isPerformingBulkAction: false,
        onSelectMemory: { _ in },
        onToggleSelection: { _ in },
        onEditMemory: nil
    )
    .environmentObject(environment)
}
