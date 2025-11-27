//
//  MemoryTriggersView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct MemoryTriggersView: View {
    @ObservedObject var memoryService: MemoryService
    let onSelectMemory: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    @Binding var navigationPath: NavigationPath
    var embedsInNavigationStack: Bool = true

    @EnvironmentObject private var environment: AppEnvironment
    @State private var searchText = ""
    @State private var selectedContentTypes: Set<MemoryContentFilterType> = []
    @State private var selectedTriggerTypes: Set<MemoryTriggerType> = []
    @State private var showInbox = true
    @State private var showPinned = true
    @State private var showTriggerSheet = false
    @State private var showContentSheet = false
    @State private var isMultiSelecting = false
    @State private var selectedMemoryIDs: Set<MemoryModel.ID> = []
    @State private var isPerformingBulkAction = false
    @State private var showingDeleteConfirmation = false
    @State private var bulkActionErrorMessage: String?

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    private struct FilteredData {
        let pinned: [MemoryModel]
        let nonPinned: [MemoryModel]
        let isEmpty: Bool
    }

    private var filteredData: FilteredData {
        let baseMemories = memoryService.nonScheduledMemories()

        let allTrigger = baseMemories.filter { memory in
            let activeTriggers = memory.triggers.filter { $0.isActive }
            guard !activeTriggers.isEmpty else { return false }

            let hasLocation = activeTriggers.contains { $0.type == .location }
            let hasPerson = activeTriggers.contains { $0.type == .person }
            let hasSequential = activeTriggers.contains { $0.type == .sequential }

            return hasLocation || hasPerson || hasSequential
        }
        .filter { isMemoryContentAndTriggerSelected($0) }

        let pinned = allTrigger.filter { $0.isPinned }
        let nonPinned = allTrigger.filter { !$0.isPinned }

        return FilteredData(pinned: pinned, nonPinned: nonPinned, isEmpty: allTrigger.isEmpty)
    }

    private var filteredMemories: [MemoryModel] {
        isSearching ? memoryService.searchMemories(query: searchText) : []
    }

    private var navigationTitleText: String {
        if isMultiSelecting {
            if selectedMemoryIDs.isEmpty {
                return "Select Memories"
            }
            return "\(selectedMemoryIDs.count) Selected"
        }
        return "Triggers"
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
        Group {
            if embedsInNavigationStack {
                NavigationStack(path: $navigationPath) {
                    content
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
        triggersList
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.large)
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
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            toggleMultiSelection()
                        } label: {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                        .disabled(isPerformingBulkAction)
                    }
                }
            }
            .sheet(isPresented: $showTriggerSheet) {
                TriggerFilterSheetView(selectedTriggerTypes: $selectedTriggerTypes)
            }
            .sheet(isPresented: $showContentSheet) {
                ContentFilterSheetView(selectedContentTypes: $selectedContentTypes)
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
            .onAppear {
                onMultiSelectionChange(isMultiSelecting)
            }
            .onDisappear {
                onMultiSelectionChange(false)
            }
    }

    private var triggersList: some View {
        List {
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

            if isSearching {
                searchResultsList
            } else {
                let data = filteredData
                if !data.isEmpty {
                    pinnedSection(data: data)

                    ForEach(data.nonPinned) { memory in
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
                } else {
                    MemoryEmptyStateCard(
                        systemImage: "bolt.fill",
                        title: "No triggers yet",
                        message: "Create a memory with location, person, or sequential triggers to get started."
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
    private func pinnedSection(data: FilteredData) -> some View {
        if !data.pinned.isEmpty {
            Section {
                ForEach(data.pinned) { memory in
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

    private func toggleMemorySelection(_ memory: MemoryModel) {
        let id = memory.id
        if selectedMemoryIDs.contains(id) {
            selectedMemoryIDs.remove(id)
        } else {
            selectedMemoryIDs.insert(id)
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
    return MemoryTriggersView(
        memoryService: environment.memoryService,
        onSelectMemory: { _ in },
        onEditMemory: nil,
        onMultiSelectionChange: { _ in },
        navigationPath: .constant(NavigationPath())
    )
    .environmentObject(environment)
}
