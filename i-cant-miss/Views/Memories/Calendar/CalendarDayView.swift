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
    let onEditMemory: ((MemoryModel) -> Void)?
    let onToggleSelection: (MemoryModel) -> Void

    @State private var displayedDate: Date
    @State private var dayAnchor: Date
    @State private var expandedPeriods: Set<CalendarTimePeriod> = Set(CalendarTimePeriod.allCases)

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
        onEditMemory: ((MemoryModel) -> Void)? = nil,
        onToggleSelection: @escaping (MemoryModel) -> Void
    ) {
        self.dataManager = dataManager
        self._currentDate = currentDate
        self.isMultiSelecting = isMultiSelecting
        self.selectedMemoryIDs = selectedMemoryIDs
        self.isPerformingBulkAction = isPerformingBulkAction
        self.onSelectMemory = onSelectMemory
        self.onEditMemory = onEditMemory
        self.onToggleSelection = onToggleSelection

        let startOfDay = Calendar.current.startOfDay(for: currentDate.wrappedValue)
        self._displayedDate = State(initialValue: startOfDay)
        self._dayAnchor = State(initialValue: startOfDay)
    }

    var body: some View {
        GeometryReader { proxy in
            TabView(selection: $displayedDate) {
                ForEach(pages, id: \.self) { day in
                    CalendarDayContentView(
                        day: day,
                        dataManager: dataManager,
                        isMultiSelecting: isMultiSelecting,
                        selectedMemoryIDs: selectedMemoryIDs,
                        isPerformingBulkAction: isPerformingBulkAction,
                        onSelectMemory: onSelectMemory,
                        onEditMemory: onEditMemory,
                        onToggleSelection: onToggleSelection,
                        expandedPeriods: $expandedPeriods,
                        onEnsureMonthDataLoaded: { date in
                            ensureMonthDataLoaded(for: date)
                        }
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .tag(day)
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
        onEditMemory: nil,
        onToggleSelection: { _ in }
    )
    .environmentObject(environment)
}
