//
//  MemoryTimelineView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct MemoryTimelineView: View {
    @ObservedObject var memoryService: MemoryService
    let onSelectMemory: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    @Binding var navigationPath: NavigationPath

    @EnvironmentObject private var environment: AppEnvironment
    @State private var showingFilterSheet = false
    @State private var searchText = ""
    @State private var selectedContentTypes: Set<MemoryContentFilterType> = []
    @State private var selectedTriggerTypes: Set<MemoryTriggerType> = []
    @State private var selectedSections: Set<MemoryService.TimelineSection.Kind> = []
    @State private var showInbox = true
    @State private var filterSheetDetent: PresentationDetent = .large
    @State private var collapsedSections: Set<MemoryService.TimelineSection.Kind> = []
    @State private var isInboxExpanded = true
    @State private var autoCollapsedInbox = false
    @State private var isPinnedExpanded = true
    @State private var isMultiSelecting = false
    @State private var selectedMemoryIDs: Set<MemoryModel.ID> = []
    @State private var isPerformingBulkAction = false
    @State private var showingDeleteConfirmation = false
    @State private var bulkActionErrorMessage: String?

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    private var filteredMemories: [MemoryModel] {
        isSearching ? memoryService.searchMemories(query: searchText) : []
    }

    private var timelineSectionData: [MemoryService.TimelineSection] {
        memoryService.timelineSections()
            .filter { section in
                if selectedSections.isEmpty {
                    return true
                }
                return selectedSections.contains(section.kind)
            }
            .map { section in
                MemoryService.TimelineSection(
                    kind: section.kind,
                    memories: section.memories.filter { memory in
                        !memory.isPinned && isMemoryContentAndTriggerSelected(memory)
                    }
                )
            }
            .filter { !$0.memories.isEmpty }
    }

    private var filteredPinnedMemories: [MemoryModel] {
        let referenceDate = Date()
        let isSectionFilterActive = !selectedSections.isEmpty && selectedSections.count < MemoryService.TimelineSection.Kind.allCases.count

        return memoryService.memories
            .filter { memory in
                guard memory.status == .active, memory.isPinned else { return false }
                guard isMemoryContentAndTriggerSelected(memory) else { return false }
                if !showInbox && memory.isInbox {
                    return false
                }

                guard isSectionFilterActive else {
                    return true
                }

                if memory.hasRecurringTriggers && selectedSections.contains(.recurring) {
                    return true
                }

                guard let kind = sectionKind(for: memory, referenceDate: referenceDate) else {
                    return false
                }

                return selectedSections.contains(kind)
            }
            .sorted { lhs, rhs in
                sortPinned(lhs, rhs, referenceDate: referenceDate)
            }
    }

    private var filteredInboxMemories: [MemoryModel] {
        memoryService.inboxMemories()
            .filter { memory in
                !memory.isPinned && isMemoryContentAndTriggerSelected(memory)
            }
    }

    private var hasAnyContent: Bool {
        !filteredPinnedMemories.isEmpty ||
        !timelineSectionData.isEmpty ||
        (showInbox && !filteredInboxMemories.isEmpty)
    }

    private var activeFilterCount: Int {
        var count = 0
        if !selectedContentTypes.isEmpty && selectedContentTypes.count < MemoryContentFilterType.allCases.count {
            count += selectedContentTypes.count
        }
        if !selectedTriggerTypes.isEmpty && selectedTriggerTypes.count < MemoryTriggerType.allCases.count {
            count += selectedTriggerTypes.count
        }
        if !selectedSections.isEmpty && selectedSections.count < MemoryService.TimelineSection.Kind.allCases.count {
            count += selectedSections.count
        }
        if !showInbox {
            count += 1
        }
        return count
    }

    private var filterDescription: String {
        var parts: [String] = []

        if !selectedContentTypes.isEmpty && selectedContentTypes.count < MemoryContentFilterType.allCases.count {
            let contentTypeLabels = selectedContentTypes
                .map(\.label)
                .sorted()
            parts.append(contentTypeLabels.joined(separator: ", "))
        }

        if !selectedTriggerTypes.isEmpty && selectedTriggerTypes.count < MemoryTriggerType.allCases.count {
            let triggerTypeLabels = selectedTriggerTypes
                .map(\.label)
                .sorted()
            parts.append(triggerTypeLabels.joined(separator: ", "))
        }

        if !selectedSections.isEmpty && selectedSections.count < MemoryService.TimelineSection.Kind.allCases.count {
            let sectionTitles = selectedSections
                .map(\.title)
                .sorted()
            parts.append(sectionTitles.joined(separator: ", "))
        }

        if !showInbox {
            parts.append("No Inbox")
        }

        return parts.isEmpty ? "All" : parts.joined(separator: " • ")
    }

    private var navigationTitleText: String {
        if isMultiSelecting {
            if selectedMemoryIDs.isEmpty {
                return "Select Memories"
            }
            return "\(selectedMemoryIDs.count) Selected"
        }
        return "Timeline"
    }

    private var bulkActionSpaces: [SpaceModel] {
        environment.spaceService.spaces.filter { $0.id != SpaceModel.allSpacesIdentifier }
    }

    private var selectedMemories: [MemoryModel] {
        selectedMemoryIDs.compactMap { memoryService.memory(id: $0) }
    }

    private var canMoveSelection: Bool {
        !selectedMemoryIDs.isEmpty
    }

    private var canChangePriorityForSelection: Bool {
        guard canMoveSelection else { return false }
        return selectedMemories.allSatisfy { memorySupportsPriorityChange($0) }
    }

    private var deleteConfirmationMessage: String {
        let count = selectedMemoryIDs.count
        if count == 1 {
            return "This will permanently remove 1 memory."
        }
        return "This will permanently remove \(count) memories."
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            timelineList
                .navigationTitle(navigationTitleText)
                .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search memories")
                .toolbar {
                    if isMultiSelecting {
                        MemoryMultiSelectToolbarContent(
                            availableSpaces: bulkActionSpaces,
                            isPerformingBulkAction: isPerformingBulkAction,
                            canPerformDeletion: canMoveSelection,
                            isPriorityEnabled: canChangePriorityForSelection,
                            isStatusEnabled: canMoveSelection,
                            isSpaceEnabled: canMoveSelection && !bulkActionSpaces.isEmpty,
                            onSelectSpace: { space in performMove(to: space) },
                            onSelectStatus: { status in performStatusUpdate(to: status) },
                            onSelectPriority: { priority in performPriorityUpdate(to: priority) },
                            onDelete: { showingDeleteConfirmation = true },
                            onDone: { toggleMultiSelection() }
                        )
                    } else {
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            MemoryFilterSummaryButton(
                                activeFilterCount: activeFilterCount,
                                filterDescription: filterDescription,
                                isSheetPresented: showingFilterSheet,
                                isDisabled: isPerformingBulkAction
                            ) {
                                filterSheetDetent = .large
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showingFilterSheet = true
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
                .sheet(isPresented: $showingFilterSheet) {
                    FilterSheetView(
                        selectedContentTypes: $selectedContentTypes,
                        selectedTriggerTypes: $selectedTriggerTypes,
                        selectedSections: $selectedSections,
                        showInbox: $showInbox,
                        detentSelection: $filterSheetDetent
                    )
                    .onAppear { filterSheetDetent = .large }
                    .presentationDetents([.large], selection: $filterSheetDetent)
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
                .onAppear(perform: syncExpansionStates)
                .onChange(of: timelineSectionData.count) {
                    syncExpansionStates()
                }
                .onChange(of: filteredInboxMemories.count) {
                    syncExpansionStates()
                }
                .onChange(of: isInboxExpanded) {
                    autoCollapsedInbox = filteredInboxMemories.isEmpty && !isInboxExpanded
                }
                .onChange(of: isMultiSelecting) { _, newValue in
                    onMultiSelectionChange(newValue)
                }
                .onAppear {
                    onMultiSelectionChange(isMultiSelecting)
                }
                .onDisappear {
                    onMultiSelectionChange(false)
                }
        }
    }

    private var timelineList: some View {
        List {
            if isSearching {
                searchResultsList
            } else {
                if hasAnyContent {
                    pinnedSection
                    timelineSectionsList
                    if showInbox {
                        inboxListContent
                    }
                } else {
                    MemoryEmptyStateCard(
                        systemImage: "tray",
                        title: "No memories yet",
                        message: "Create a memory or capture a reminder to get started."
                    )
                    .padding(.top, 16)
                    .listRowInsets(.init(top: 24, leading: 20, bottom: 24, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
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
        .listRowSeparator(.hidden)
        .background(Color.clear)
    }

    @ViewBuilder
    private var pinnedSection: some View {
        if !filteredPinnedMemories.isEmpty {
            MemoryDisclosureListSection(
                title: "Pinned Memories",
                systemImage: "pin.fill",
                isExpanded: $isPinnedExpanded,
                memories: filteredPinnedMemories,
                isMultiSelecting: isMultiSelecting,
                selectedMemoryIDs: selectedMemoryIDs,
                isDisabled: isPerformingBulkAction,
                onSelect: onSelectMemory,
                onEdit: onEditMemory,
                onToggleSelection: toggleMemorySelection(_:))
        }
    }

    @ViewBuilder
    private var searchResultsList: some View {
        if filteredMemories.isEmpty {
            MemoryEmptyStateCard(
                systemImage: "magnifyingglass",
                title: "No memories match your search",
                message: "Try different keywords or reset filters to discover more memories."
            )
            .padding(.top, 16)
            .listRowInsets(.init(top: 16, leading: 20, bottom: 24, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            ForEach(filteredMemories) { memory in
                memoryRow(for: memory)
            }
        }
    }

    @ViewBuilder
    private var timelineSectionsList: some View {
        let sections = timelineSectionData
        ForEach(sections) { section in
            MemoryDisclosureListSection(
                title: section.kind.title,
                systemImage: section.kind.systemImage,
                isExpanded: sectionExpansionBinding(for: section.kind),
                memories: section.memories,
                isMultiSelecting: isMultiSelecting,
                selectedMemoryIDs: selectedMemoryIDs,
                isDisabled: isPerformingBulkAction,
                onSelect: onSelectMemory,
                onEdit: onEditMemory,
                onToggleSelection: toggleMemorySelection(_:))
        }
    }

    @ViewBuilder
    private var inboxListContent: some View {
        let inboxMemories = filteredInboxMemories

        if !inboxMemories.isEmpty {
            Section {
                inboxHeaderRow(memories: inboxMemories)

                if isInboxExpanded {
                    ForEach(inboxMemories) { memory in
                        MemoryListItemButton(
                            memory: memory,
                            isMultiSelecting: isMultiSelecting,
                            isSelected: isMemorySelected(memory),
                            isDisabled: isPerformingBulkAction,
                            onSelect: onSelectMemory,
                            onToggleSelection: toggleMemorySelection(_:),
                            onEdit: onEditMemory)
                        .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listSectionSeparator(.hidden)
        }
    }

    private func inboxHeaderRow(memories: [MemoryModel]) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isInboxExpanded.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Label("Inbox", systemImage: "tray.fill")
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: isInboxExpanded ? "chevron.down" : "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .listRowInsets(.init(top: 24, leading: 20, bottom: isInboxExpanded && !memories.isEmpty ? 0 : 8, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .disabled(memories.isEmpty)
    }

    private func memoryRow(for memory: MemoryModel) -> some View {
        MemoryListItemButton(
            memory: memory,
            isMultiSelecting: isMultiSelecting,
            isSelected: isMemorySelected(memory),
            isDisabled: isPerformingBulkAction,
            onSelect: onSelectMemory,
            onToggleSelection: toggleMemorySelection(_:),
            onEdit: onEditMemory)
        .listRowInsets(.init(top: 6, leading: 20, bottom: 6, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func isMemoryContentAndTriggerSelected(_ memory: MemoryModel) -> Bool {
        // Check content types
        let contentMatches: Bool
        if selectedContentTypes.isEmpty {
            contentMatches = true
        } else {
            contentMatches = selectedContentTypes.contains { contentType in
                switch contentType {
                case .richText:
                    return memory.contents.contains {
                        if case .richText = $0 { return true }
                        return false
                    }
                case .checklist:
                    return memory.hasChecklist
                case .photos:
                    return memory.contents.contains {
                        if case .photos = $0 { return true }
                        return false
                    }
                case .links:
                    return memory.contents.contains {
                        if case .links = $0 { return true }
                        return false
                    }
                case .audio:
                    return memory.contents.contains {
                        if case .audio = $0 { return true }
                        return false
                    }
                }
            }
        }

        // Check trigger types
        let triggerMatches: Bool
        if selectedTriggerTypes.isEmpty {
            triggerMatches = true
        } else {
            triggerMatches = selectedTriggerTypes.contains { triggerType in
                memory.triggers.contains { $0.type == triggerType && $0.isActive }
            }
        }

        return contentMatches && triggerMatches
    }

    private func sectionExpansionBinding(for kind: MemoryService.TimelineSection.Kind) -> Binding<Bool> {
        Binding(
            get: { !collapsedSections.contains(kind) },
            set: { isExpanded in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if isExpanded {
                        collapsedSections.remove(kind)
                    } else {
                        collapsedSections.insert(kind)
                    }
                }
            }
        )
    }

    private func sectionKind(for memory: MemoryModel, referenceDate: Date = Date()) -> MemoryService.TimelineSection.Kind? {
        guard let fireDate = memory.nextFireDate(referenceDate: referenceDate) else { return nil }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? referenceDate
        let sevenDaysOut = calendar.date(byAdding: .day, value: 7, to: startOfTomorrow) ?? referenceDate

        if calendar.isDate(fireDate, inSameDayAs: referenceDate) {
            return .today
        } else if fireDate < sevenDaysOut {
            return .nextSevenDays
        } else {
            return .later
        }
    }

    private func sortPinned(_ lhs: MemoryModel, _ rhs: MemoryModel, referenceDate: Date = Date()) -> Bool {
        let lhsFire = lhs.nextFireDate(referenceDate: referenceDate)
        let rhsFire = rhs.nextFireDate(referenceDate: referenceDate)

        if lhsFire != rhsFire {
            switch (lhsFire, rhsFire) {
            case let (lhsDate?, rhsDate?):
                return lhsDate < rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                break
            }
        }

        if lhs.dueDate != rhs.dueDate {
            switch (lhs.dueDate, rhs.dueDate) {
            case let (lhsDate?, rhsDate?):
                return lhsDate < rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                break
            }
        }

        if lhs.priority != rhs.priority {
            let lhsPriority = lhs.priority?.rawValue ?? -1
            let rhsPriority = rhs.priority?.rawValue ?? -1
            return lhsPriority > rhsPriority
        }

        return lhs.updatedAt > rhs.updatedAt
    }

    private func toggleMemorySelection(_ memory: MemoryModel) {
        let id = memory.id
        if selectedMemoryIDs.contains(id) {
            selectedMemoryIDs.remove(id)
        } else {
            selectedMemoryIDs.insert(id)
        }
    }

    private func syncExpansionStates() {
        if filteredInboxMemories.isEmpty {
            if isInboxExpanded {
                isInboxExpanded = false
                autoCollapsedInbox = true
            }
        } else if autoCollapsedInbox && !isInboxExpanded {
            isInboxExpanded = true
            autoCollapsedInbox = false
        }
    }

    private func isMemorySelected(_ memory: MemoryModel) -> Bool {
        selectedMemoryIDs.contains(memory.id)
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
            searchText = ""
        }
        showingFilterSheet = false
        showingDeleteConfirmation = false
    }

    private func performMove(to space: SpaceModel) {
        performBulkAction { processor, ids in
            await processor.moveMemories(ids, to: space)
        }
    }

    private func performStatusUpdate(to status: MemoryStatus) {
        performBulkAction { processor, ids in
            await processor.updateStatus(of: ids, to: status)
        }
    }

    private func performPriorityUpdate(to priority: MemoryPriority) {
        performBulkAction { processor, ids in
            await processor.updatePriority(of: ids, to: priority)
        }
    }

    private func performBulkAction(
        _ action: @escaping (MemoryBulkActionProcessor, Set<MemoryModel.ID>) async -> MemoryBulkActionProcessor.MemoryBulkActionResult
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

    private func memorySupportsPriorityChange(_ memory: MemoryModel) -> Bool {
        true
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

    private func deleteMemories(withIDs ids: Set<MemoryModel.ID>) async {
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
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MemoryTimelineView(
        memoryService: environment.memoryService,
        onSelectMemory: { _ in },
        onEditMemory: nil,
        onMultiSelectionChange: { _ in },
        navigationPath: .constant(NavigationPath())
    )
    .environmentObject(environment)
}
