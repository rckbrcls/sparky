//
//  CalendarDayView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI
import UIKit

struct CalendarDayView: View {
    @ObservedObject var dataManager: CalendarDataManager
    @Binding var currentDate: Date
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<MemoryModel.ID>
    let isPerformingBulkAction: Bool
    let onSelectMemory: (MemoryModel) -> Void
    let onToggleSelection: (MemoryModel) -> Void

    @State private var displayedDate: Date
    @State private var dayAnchor: Date
    @State private var expandedPeriods: Set<TimePeriod> = Set(TimePeriod.allCases)

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
        onToggleSelection: @escaping (MemoryModel) -> Void
    ) {
        self.dataManager = dataManager
        self._currentDate = currentDate
        self.isMultiSelecting = isMultiSelecting
        self.selectedMemoryIDs = selectedMemoryIDs
        self.isPerformingBulkAction = isPerformingBulkAction
        self.onSelectMemory = onSelectMemory
        self.onToggleSelection = onToggleSelection

        let startOfDay = Calendar.current.startOfDay(for: currentDate.wrappedValue)
        self._displayedDate = State(initialValue: startOfDay)
        self._dayAnchor = State(initialValue: startOfDay)
    }

    var body: some View {
        GeometryReader { proxy in
            TabView(selection: $displayedDate) {
                ForEach(pages, id: \.self) { day in
                    List {
                        dayHeader(for: day)
                            .listRowInsets(.init(top: 24, leading: 0, bottom: 24, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        let memories = dataManager.memoriesForDate(day)

                        let allDayItems = allDayMemories(from: memories, date: day)
                        Section {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedPeriods.contains(.allDay) {
                                        expandedPeriods.remove(.allDay)
                                    } else {
                                        expandedPeriods.insert(.allDay)
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(Color.cyan)
                                        .font(.subheadline)
                                    Text("All Day")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text("\(allDayItems.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                        .rotationEffect(.degrees(expandedPeriods.contains(.allDay) ? 90 : 0))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.cyan.opacity(0.20))
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.cyan.opacity(0.1), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(.init(top: 16, leading: 20, bottom: 4, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                            if expandedPeriods.contains(.allDay) {
                                ForEach(allDayItems) { memory in
                                    MemoryListItemButton(
                                        memory: memory,
                                        isMultiSelecting: isMultiSelecting,
                                        isSelected: selectedMemoryIDs.contains(memory.id),
                                        isDisabled: isPerformingBulkAction,
                                        onSelect: onSelectMemory,
                                        onToggleSelection: onToggleSelection
                                    )
                                    .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                            }
                        }

                        ForEach(TimePeriod.allCases.filter { $0 != .allDay }, id: \.self) { period in
                            let periodMemories = memoriesForPeriod(period, from: memories, date: day)

                            Section {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedPeriods.contains(period) {
                                            expandedPeriods.remove(period)
                                        } else {
                                            expandedPeriods.insert(period)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: period.iconName)
                                            .foregroundStyle(period.color)
                                            .font(.subheadline)
                                        Text(period.title)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                        Text("\(periodMemories.count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.secondary)
                                            .rotationEffect(.degrees(expandedPeriods.contains(period) ? 90 : 0))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(period.color.opacity(0.20))
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(period.color.opacity(0.1), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(.init(top: 16, leading: 20, bottom: 4, trailing: 20))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)

                                if expandedPeriods.contains(period) {
                                    ForEach(periodMemories) { memory in
                                        MemoryListItemButton(
                                            memory: memory,
                                            isMultiSelecting: isMultiSelecting,
                                            isSelected: selectedMemoryIDs.contains(memory.id),
                                            isDisabled: isPerformingBulkAction,
                                            onSelect: onSelectMemory,
                                            onToggleSelection: onToggleSelection
                                        )
                                        .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                    }
                                }
                            }

                        }

                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .environment(\.defaultMinListRowHeight, 0)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 70)
                    }
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
            let normalizedDate = calendar.startOfDay(for: newValue)
            displayedDate = normalizedDate
            updateDayAnchorIfNeeded(for: normalizedDate)
        }
    }

    private func dayHeader(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(primaryDateTitle(for: date))
                .appLargeTitleStyle()

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

    private func updateDayAnchorIfNeeded(for date: Date) {
        let daysFromAnchor = calendar.dateComponents([.day], from: dayAnchor, to: date).day ?? 0
        let threshold = 10
        let isDateInRange = pages.contains { page in
            calendar.isDate(page, inSameDayAs: date)
        }

        if abs(daysFromAnchor) > threshold || !isDateInRange {
            dayAnchor = calendar.startOfDay(for: date)
        }
    }

    private func allDayMemories(from memories: [MemoryModel], date: Date) -> [MemoryModel] {
        memories.filter { memory in
            guard let fireDate = memory.nextFireDate(referenceDate: date) else {
                return false
            }
            let components = calendar.dateComponents([.hour, .minute], from: fireDate)
            return (components.hour ?? 0) == 0 && (components.minute ?? 0) == 0
        }
    }

    private func timedMemories(from memories: [MemoryModel], date: Date) -> [MemoryModel] {
        memories.filter { memory in
            guard let fireDate = memory.nextFireDate(referenceDate: date) else {
                return false
            }
            let components = calendar.dateComponents([.hour, .minute], from: fireDate)
            return (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0
        }
    }

    private enum TimePeriod: CaseIterable {
        case allDay     // All day memories (no specific time)
        case morning    // 06:00 - 12:00
        case afternoon  // 12:00 - 18:00
        case evening    // 18:00 - 22:00
        case night      // 22:00 - 06:00

        var title: String {
            switch self {
            case .allDay: return "All Day"
            case .morning: return "Morning"
            case .afternoon: return "Afternoon"
            case .evening: return "Evening"
            case .night: return "Night"
            }
        }

        var iconName: String {
            switch self {
            case .allDay: return "calendar"
            case .morning: return "sunrise.fill"
            case .afternoon: return "sun.max.fill"
            case .evening: return "sunset.fill"
            case .night: return "moon.stars.fill"
            }
        }

        var color: Color {
            switch self {
            case .allDay: return .cyan
            case .morning: return .orange
            case .afternoon: return .yellow
            case .evening: return .pink
            case .night: return .indigo
            }
        }

        func contains(hour: Int) -> Bool {
            switch self {
            case .allDay:
                return false // All day memories don't have a specific hour
            case .morning:
                return hour >= 6 && hour < 12
            case .afternoon:
                return hour >= 12 && hour < 18
            case .evening:
                return hour >= 18 && hour < 22
            case .night:
                return hour >= 22 || hour < 6
            }
        }
    }

    private func memoriesForPeriod(_ period: TimePeriod, from memories: [MemoryModel], date: Date) -> [MemoryModel] {
        timedMemories(from: memories, date: date).filter { memory in
            guard let fireDate = memory.nextFireDate(referenceDate: date) else {
                return false
            }
            let hour = calendar.component(.hour, from: fireDate)
            return period.contains(hour: hour)
        }
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
        onToggleSelection: { _ in }
    )
    .environmentObject(environment)
}
