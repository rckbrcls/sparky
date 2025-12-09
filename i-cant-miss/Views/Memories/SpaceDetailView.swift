//
//  SpaceDetailView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct SpaceDetailView: View {
    let space: SpaceModel

    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject var spaceService: SpaceService
    @ObservedObject var memoryService: MemoryService

    let onSelectMemory: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?
    let onCreateSpace: (SpaceModel?) -> Void
    let onEditSpace: ((SpaceModel) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    let onSpaceContextChange: (SpaceModel?) -> Void

    @State private var showingFilterSheet = false
    @State private var selectedContentTypes: Set<MemoryContentFilterType> = []
    @State private var selectedTriggerTypes: Set<MemoryTriggerType> = []
    @State private var showInbox = true
    @State private var showPinned = true
    @State private var showTriggerSheet = false
    @State private var showContentSheet = false
    @State private var filterSheetDetent: PresentationDetent = .large
    @State private var searchText = ""


    @State private var isMultiSelecting = false
    @State private var selectedMemoryIDs: Set<MemoryModel.ID> = []
    @State private var isPerformingBulkAction = false
    @State private var showingDeleteConfirmation = false
    @State private var bulkActionErrorMessage: String?

    private var activeFilterCount: Int {
        var count = 0
        if !selectedContentTypes.isEmpty && selectedContentTypes.count < MemoryContentFilterType.allCases.count {
            count += selectedContentTypes.count
        }
        if !selectedTriggerTypes.isEmpty && selectedTriggerTypes.count < MemoryTriggerType.allCases.count {
            count += selectedTriggerTypes.count
        }
        if !showInbox {
            count += 1
        }
        return count
    }

    private var isFiltering: Bool {
        activeFilterCount > 0 || isSearching
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedSearchText.isEmpty
    }

    private var resolvedSpace: SpaceModel {
        spaceService.space(id: space.id) ?? space
    }

    private var isAllSpace: Bool {
        resolvedSpace.isAllSpaces
    }

    private var nonPinnedMemories: [MemoryModel] {
        filteredMemories.filter { !$0.isPinned }
    }

    private var pinnedMemories: [MemoryModel] {
        let referenceDate = Date()
        return filteredMemories
            .filter(\.isPinned)
            .sorted { lhs, rhs in
                sortPinned(lhs, rhs, referenceDate: referenceDate)
            }
    }

    // Legacy helper - maintained for compatibility if needed, otherwise safe to remove if unused
    private var inboxMemories: [MemoryModel] {
        filteredMemories.filter { $0.isInbox && !$0.isPinned }
    }

    private var nonInboxMemories: [MemoryModel] {
        filteredMemories.filter { !$0.isInbox && !$0.isPinned }
    }

    private var shouldShowEmptyStateCard: Bool {
        nonPinnedMemories.isEmpty && pinnedMemories.isEmpty
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

        if !showInbox {
            parts.append("No Inbox")
        }

        return parts.isEmpty ? "All" : parts.joined(separator: " • ")
    }

    private var emptyStateTitle: String {
        isFiltering ? "No memories match these filters" : "No memories yet"
    }

    private var emptyStateMessage: String {
        isFiltering
            ? "Try adjusting the filters or reset them to see more memories."
            : "Create a memory to get started in this space."
    }

    private var navigationTitleText: String {
        if isMultiSelecting {
            if selectedMemoryIDs.isEmpty {
                return "Select Memories"
            }
            return "\(selectedMemoryIDs.count) Selected"
        }
        return resolvedSpace.name
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

    private var canCreateSubspace: Bool {
        !resolvedSpace.isAllSpaces
    }

    var body: some View {
        baseView
            .modifier(SpaceDetailModifiers(
                showingDeleteConfirmation: $showingDeleteConfirmation,
                bulkActionErrorMessage: $bulkActionErrorMessage,
                deleteConfirmationMessage: deleteConfirmationMessage,
                isPerformingBulkAction: isPerformingBulkAction,
                onDelete: performBulkDeletion
            ))
            .modifier(SpaceDetailContextModifiers(
                isMultiSelecting: isMultiSelecting,
                spaceID: space.id,
                spaceService: spaceService,
                onMultiSelectionChange: onMultiSelectionChange,
                onNotifyContext: notifySpaceContextChange,
                resolvedSpaceProvider: { resolvedSpace }
            ))
    }

    private var baseView: some View {
        spaceDetailList
            .navigationTitle(navigationTitleText)
            .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search memories")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showTriggerSheet) {
                TriggerFilterSheetView(selectedTriggerTypes: $selectedTriggerTypes)
            }
            .sheet(isPresented: $showContentSheet) {
                ContentFilterSheetView(selectedContentTypes: $selectedContentTypes)
            }
            .sheet(isPresented: $showingFilterSheet, content: filterSheetContent)
    }

    private func notifySpaceContextChange() {
        // Always notify with the resolved space to ensure context is up to date
        onSpaceContextChange(resolvedSpace)
    }

    private var childSpaces: [SpaceModel] {
        if isAllSpace {
            return []
        }
        return spaceService.children(of: resolvedSpace)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
             ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    toggleMultiSelection()
                } label: {
                    Label("Select", systemImage: "checkmark.circle")
                }
                .disabled(isPerformingBulkAction)

                Button {
                    onCreateSpace(isAllSpace ? nil : resolvedSpace)
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
            }
        }
    }

    @ViewBuilder
    private func filterSheetContent() -> some View {
        FilterSheetView(
            selectedContentTypes: $selectedContentTypes,
            selectedTriggerTypes: $selectedTriggerTypes,
            showInbox: $showInbox,
            detentSelection: $filterSheetDetent
        )
        .onAppear { filterSheetDetent = .large }
        .presentationDetents([.large], selection: $filterSheetDetent)
    }

    private var spaceDetailList: some View {
        List {
            subspacesSection

            FilterBadgesBar(
                selectedTriggerTypes: $selectedTriggerTypes,
                selectedContentTypes: $selectedContentTypes,
                showInbox: $showInbox,
                showPinned: $showPinned,
                showTriggerSheet: $showTriggerSheet,
                showContentSheet: $showContentSheet
            )
            .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            mainListSection
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
    private var subspacesSection: some View {
        if !childSpaces.isEmpty {
            SpaceDetailSubspacesSection(
                childSpaces: childSpaces,
                spaceService: spaceService,
                memoryService: memoryService,
                memoryCountProvider: memoryCount(for:),
                onEditSpace: onEditSpace
            )
        }
    }

    @ViewBuilder
    private var mainListSection: some View {
        if isSearching {
            SpaceDetailSearchResultsView(
                memories: filteredMemories,
                isMultiSelecting: isMultiSelecting,
                isPerformingBulkAction: isPerformingBulkAction,
                isMemorySelected: isMemorySelected(_:),
                onSelectMemory: onSelectMemory,
                onEditMemory: onEditMemory,
                onToggleSelection: toggleMemorySelection(_:)
            )
        } else {
            timelineAndInboxSection
        }
    }

    @ViewBuilder
    private var timelineAndInboxSection: some View {
        if !pinnedMemories.isEmpty && showPinned {
            Section {
                 ForEach(pinnedMemories) { memory in
                    MemoryListItemButton(
                        memory: memory,
                        isMultiSelecting: isMultiSelecting,
                        isSelected: isMemorySelected(memory),
                        isDisabled: isPerformingBulkAction,
                        onSelect: onSelectMemory,
                        onToggleSelection: toggleMemorySelection(_:),
                        onEdit: onEditMemory
                    )
                    .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } header: {
                 HStack(spacing: 12) {
                    Label("Pinned Memories", systemImage: "pin.fill")
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 12)
                .listRowInsets(.init(top: 24, leading: 20, bottom: 8, trailing: 20))
            }
             .listSectionSeparator(.hidden)
        }

        ForEach(nonPinnedMemories) { memory in
            MemoryListItemButton(
                memory: memory,
                isMultiSelecting: isMultiSelecting,
                isSelected: isMemorySelected(memory),
                isDisabled: isPerformingBulkAction,
                onSelect: onSelectMemory,
                onToggleSelection: toggleMemorySelection(_:),
                onEdit: onEditMemory
            )
            .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }

        if nonPinnedMemories.isEmpty && pinnedMemories.isEmpty {
             MemoryEmptyStateCard(
                systemImage: "bolt.fill",
                title: emptyStateTitle,
                message: emptyStateMessage
            )
            .padding(.top, 16)
            .listRowInsets(.init(top: 24, leading: 20, bottom: 24, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func presentFilterSheet() {
        filterSheetDetent = .large
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showingFilterSheet = true
        }
    }

    private var filteredMemories: [MemoryModel] {
        let targetSpace = isAllSpace ? nil : resolvedSpace
        let base = memoryService.memories(
            in: targetSpace,
            includeDescendants: false,
            statuses: [],
            includeCompleted: true,
            sort: .updatedAtDescending
        )

        let query = trimmedSearchText

        return base.filter { memory in
            matchesSelectedContentAndTrigger(memory) &&
            (showInbox || !memory.isInbox) &&
            matchesSearch(memory, query: query)
        }
    }

    private func matchesSelectedContentAndTrigger(_ memory: MemoryModel) -> Bool {
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
                case .files:
                    return memory.contents.contains {
                        if case .files = $0 { return true }
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

    private func memoryCount(for space: SpaceModel) -> Int {
        let ids = spaceService.descendantIDs(of: space)
        return memoryService.memories.filter { memory in
            guard let spaceID = memory.space?.id else { return false }
            return ids.contains(spaceID)
        }.count
    }

    private func matchesSearch(_ memory: MemoryModel, query: String) -> Bool {
        guard !query.isEmpty else { return true }

        if memory.title.localizedCaseInsensitiveContains(query) {
            return true
        }

        if let body = memory.body, body.localizedCaseInsensitiveContains(query) {
            return true
        }

        return false
    }

    private func isMemorySelected(_ memory: MemoryModel) -> Bool {
        selectedMemoryIDs.contains(memory.id)
    }

    private func toggleMemorySelection(_ memory: MemoryModel) {
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
                // Failures handled individually.
            }
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
            let lhsPriority = lhs.priority?.rawValue ?? MemoryPriority.noPriority.rawValue
            let rhsPriority = rhs.priority?.rawValue ?? MemoryPriority.noPriority.rawValue
            return lhsPriority > rhsPriority
        }

        return lhs.updatedAt > rhs.updatedAt
    }
}

private struct SpaceDetailModifiers: ViewModifier {
    @Binding var showingDeleteConfirmation: Bool
    @Binding var bulkActionErrorMessage: String?
    let deleteConfirmationMessage: String
    let isPerformingBulkAction: Bool
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("Delete selected memories?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete()
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
    }
}

private struct SpaceDetailContextModifiers: ViewModifier {
    let isMultiSelecting: Bool
    let spaceID: UUID
    @ObservedObject var spaceService: SpaceService
    let onMultiSelectionChange: (Bool) -> Void
    let onNotifyContext: () -> Void
    let resolvedSpaceProvider: () -> SpaceModel

    private var resolvedSpace: SpaceModel {
        resolvedSpaceProvider()
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: isMultiSelecting) { _, newValue in
                onMultiSelectionChange(newValue)
            }
            .onAppear {
                onMultiSelectionChange(isMultiSelecting)
                onNotifyContext()
            }
            .onReceive(spaceService.$spaces) { _ in
                onNotifyContext()
            }
            .onChange(of: resolvedSpace.id) { _, _ in
                onNotifyContext()
            }
            .onDisappear {
                onMultiSelectionChange(false)
            }
            .task(id: resolvedSpace.id) {
                onNotifyContext()
            }
            .onChange(of: spaceID) { _, _ in
                onNotifyContext()
            }
    }
}
