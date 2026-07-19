//
//  MemoryTimelineView.swift
//  sparky
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct MemoryTimelineView: View {
    @ObservedObject var memoryService: MemoryService
    let onSelectMemory: (Memory) -> Void
    let onEditMemory: ((Memory) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    @Binding var navigationPath: NavigationPath
    var embedsInNavigationStack: Bool = true

    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var calendarDataManager: CalendarDataManager
    @State private var isMultiSelecting = false
    @State private var selectedYear: Int
    @State private var selectedMonth: Date
    @State private var selectedDate: Date
    @State private var selectedMemoryIDs: Set<Memory.ID> = []
    @State private var isPerformingBulkAction = false
    @State private var showingDeleteConfirmation = false
    @State private var bulkActionErrorMessage: String?
    @State private var viewMode: CalendarViewMode

    init(
        memoryService: MemoryService,
        onSelectMemory: @escaping (Memory) -> Void,
        onEditMemory: ((Memory) -> Void)? = nil,
        onMultiSelectionChange: @escaping (Bool) -> Void,
        navigationPath: Binding<NavigationPath>,
        embedsInNavigationStack: Bool = true
    ) {
        self.memoryService = memoryService
        self.onSelectMemory = onSelectMemory
        self.onEditMemory = onEditMemory
        self.onMultiSelectionChange = onMultiSelectionChange
        self._navigationPath = navigationPath
        self.embedsInNavigationStack = embedsInNavigationStack
        self._calendarDataManager = StateObject(wrappedValue: CalendarDataManager(memoryService: memoryService))

        // Initialize state with current date
        let now = Date()
        let calendar = Calendar.current
        self._selectedYear = State(initialValue: calendar.component(.year, from: now))
        self._selectedMonth = State(initialValue: calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now)
        self._selectedDate = State(initialValue: now)
        self._viewMode = State(initialValue: .day(now))
    }

    private var bulkActionMinds: [Mind] {
        environment.mindService.minds.filter { !$0.isDefault }
    }

    private var selectedMemories: [Memory] {
        selectedMemoryIDs.compactMap { memoryService.memory(id: $0) }
    }

    private var canMoveSelection: Bool {
        !selectedMemoryIDs.isEmpty
    }

    private var deleteConfirmationMessage: String {
        let count = selectedMemoryIDs.count
        if count == 1 {
            return "This will permanently remove 1 memory."
        }
        return "This will permanently remove \(count) memories."
    }

    var body: some View {
        Group {
            if embedsInNavigationStack {
                NavigationStack(path: $navigationPath) {
                    content
                        .toolbarTitleDisplayMode(.inline)
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
        currentView
            .background(Color.Theme.secondaryBackground.ignoresSafeArea())
            .clearPhoneNavigationBarBackground()
            .toolbar {
                if isMultiSelecting {
                    MemoryMultiSelectToolbarContent(
                        availableMinds: bulkActionMinds,
                        isPerformingBulkAction: isPerformingBulkAction,
                        canPerformDeletion: canMoveSelection,
                        isStatusEnabled: canMoveSelection,
                        isMindEnabled: canMoveSelection && !bulkActionMinds.isEmpty,
                        onSelectMind: { mind in performMove(to: mind) },
                        onSelectStatus: { status in performStatusUpdate(to: status) },
                        onDelete: { showingDeleteConfirmation = true },
                        onDone: { toggleMultiSelection() }
                    )
                } else {
                    ToolbarItemGroup(placement: .navigation) {
                        if case .day = viewMode {
                            Button {
                                navigateBack()
                            } label: {
                                Text(backButtonTitle)
                            }
                        }
                    }

                    ToolbarItemGroup(placement: .primaryAction) {
                        if shouldShowTodayButton {
                            Button {
                                navigateToToday()
                            } label: {
                                Text("Today")
                            }
                        }
                        Button {
                            toggleMultiSelection()
                        } label: {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                        .disabled(isPerformingBulkAction)
                    }
                }
            }
            .alert("Delete selected memories?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    performBulkDeletion()
                }
                .disabled(isPerformingBulkAction)

                Button("Cancel", role: .cancel) {}
            } message: {
                Text(deleteConfirmationMessage)
            }
            .alert("Unable to complete action", isPresented: Binding(
                get: { bulkActionErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        bulkActionErrorMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(bulkActionErrorMessage ?? "")
            }
            .onChange(of: isMultiSelecting) { _, newValue in
                onMultiSelectionChange(newValue)
            }
            .onChange(of: selectedDate) { _, newValue in
                if case .day = viewMode {
                    viewMode = .day(newValue)
                }
            }
            .onAppear {
                onMultiSelectionChange(isMultiSelecting)
            }
            .onDisappear {
                onMultiSelectionChange(false)
            }
            .onReceive(memoryService.$lastRefreshed) { _ in
                calendarDataManager.clearCache()
            }
    }

    @ViewBuilder
    private var currentView: some View {
        switch viewMode {
        case .month(let month):
            monthView(month: month)
        case .day(let day):
            dayView(day: day)
        }
    }

    private func monthView(month: Date) -> some View {
        CalendarMonthView(
            dataManager: calendarDataManager,
            currentMonth: $selectedMonth,
            selectedDate: viewMode == .day(selectedDate) ? selectedDate : nil,
            onSelectDay: { day in
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedDate = day
                    viewMode = .day(day)
                }
            }
        )
        .id(month)
    }

    private func dayView(day: Date) -> some View {
        CalendarDayView(
            dataManager: calendarDataManager,
            currentDate: $selectedDate,
            isMultiSelecting: isMultiSelecting,
            selectedMemoryIDs: selectedMemoryIDs,
            isPerformingBulkAction: isPerformingBulkAction,
            onSelectMemory: onSelectMemory,
            onEditMemory: onEditMemory,
            onToggleSelection: toggleMemorySelection(_:)
        )
    }

    private var backButtonTitle: String {
        if case .day(let day) = viewMode {
            return monthAbbreviation(from: day)
        }
        return ""
    }

    private func monthAbbreviation(from date: Date) -> String {
        Self.monthFormatter.string(from: date)
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter
    }()

    private var shouldShowTodayButton: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let currentDay = calendar.startOfDay(for: selectedDate)

        if case .day = viewMode, calendar.isDate(currentDay, inSameDayAs: today) {
            return false
        }

        return true
    }

    private func navigateToToday() {
        let now = Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        withAnimation(.easeInOut(duration: 0.25)) {
            selectedYear = calendar.component(.year, from: now)
            selectedMonth = startOfMonth
            selectedDate = now
            viewMode = .day(now)
        }
    }

    private func navigateBack() {
        withAnimation(.easeInOut(duration: 0.25)) {
            switch viewMode {
            case .month:
                break
            case .day:
                viewMode = .month(selectedMonth)
            }
        }
    }

    private func toggleMemorySelection(_ memory: Memory) {
        let id = memory.id
        if selectedMemoryIDs.contains(id) {
            selectedMemoryIDs.remove(id)
        } else {
            selectedMemoryIDs.insert(id)
        }
    }

    private func toggleMultiSelection() {
        if isMultiSelecting {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isMultiSelecting = false
            }
            selectedMemoryIDs.removeAll()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isMultiSelecting = true
            }
            selectedMemoryIDs.removeAll()
        }
        showingDeleteConfirmation = false
    }

    private func performMove(to mind: Mind) {
        performBulkAction { processor, ids in
            await processor.moveMemories(ids, to: mind)
        }
    }

    private func performStatusUpdate(to status: MemoryStatus) {
        performBulkAction { processor, ids in
            await processor.updateStatus(of: ids, to: status)
        }
    }

    private func performBulkAction(
        _ action: @escaping (MemoryBulkActionProcessor, Set<Memory.ID>) async -> MemoryBulkActionProcessor.MemoryBulkActionResult
    ) {
        let ids = selectedMemoryIDs
        guard !ids.isEmpty, !isPerformingBulkAction else { return }

        isPerformingBulkAction = true
        Task {
            let processor = MemoryBulkActionProcessor(environment: environment)
            let result = await action(processor, ids)
            await MainActor.run {
                handleBulkActionResult(result)
            }
        }
    }

    private func handleBulkActionResult(_ result: MemoryBulkActionProcessor.MemoryBulkActionResult) {
        isPerformingBulkAction = false

        if result.hasSuccesses {
            selectedMemoryIDs.subtract(result.succeededIDs)
        }

        if result.hasFailures {
            bulkActionErrorMessage = bulkActionFailureMessage(from: result.failedIDs)
        }
    }

    private func bulkActionFailureMessage(from failures: [UUID: Error]) -> String {
        guard let firstError = failures.values.first else {
            return "Unable to complete the requested action."
        }

        if failures.count == 1 {
            return firstError.localizedDescription
        }

        return "\(failures.count) memories failed to update. \(firstError.localizedDescription)"
    }

    private func performBulkDeletion() {
        let ids = selectedMemoryIDs
        guard !ids.isEmpty else { return }
        isPerformingBulkAction = true
        Task {
            await deleteMemories(withIDs: ids)
            await MainActor.run {
                selectedMemoryIDs.removeAll()
                isMultiSelecting = false
                isPerformingBulkAction = false
            }
        }
    }

    private func deleteMemories(withIDs ids: Set<Memory.ID>) async {
        for id in ids {
            do {
                try await environment.memoryService.deleteMemory(id: id)
            } catch {
                // Silently ignore failures for now.
            }
        }
    }
}

#Preview {
    let environment = AppEnvironment(dataController: DataController.preview)
    environment.bootstrap()
    return MemoryTimelineView(
        memoryService: environment.memoryService,
        onSelectMemory: { _ in },
        onMultiSelectionChange: { _ in },
        navigationPath: .constant(NavigationPath())
    )
    .environmentObject(environment)
}
