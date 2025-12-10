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
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var spaceService: SpaceService
    @ObservedObject var memoryService: MemoryService

    let onSelectMemory: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?
    let onEditSpace: ((SpaceModel) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    let onSpaceContextChange: (SpaceModel?) -> Void
    let onSearchActiveChange: (Bool) -> Void

    @State private var selectedContentTypes: Set<MemoryContentFilterType> = []
    @State private var selectedTriggerTypes: Set<MemoryTriggerType> = []
    @State private var showInbox = true
    @State private var showPinned = true
    @State private var showTriggerSheet = false
    @State private var showContentSheet = false
    @State private var showingFilterSheet = false
    @State private var filterSheetDetent: PresentationDetent = .large



    @State private var isMultiSelecting = false
    @State private var selectedMemoryIDs: Set<MemoryModel.ID> = []
    @State private var isPerformingBulkAction = false
    @State private var showingDeleteConfirmation = false
    @State private var bulkActionErrorMessage: String?

    @State private var isSearching = false
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool

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
        activeFilterCount > 0
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
            .navigationBarBackButtonHidden(true)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showTriggerSheet) {
                TriggerFilterSheetView(selectedTriggerTypes: $selectedTriggerTypes)
                    .presentationDetents([.medium])
                    .presentationBackground(.clear)
            }
            .sheet(isPresented: $showContentSheet) {
                ContentFilterSheetView(selectedContentTypes: $selectedContentTypes)
                    .presentationDetents([.medium])
                    .presentationBackground(.clear)
            }
    }

    private func notifySpaceContextChange() {
        // Always notify with the resolved space to ensure context is up to date
        onSpaceContextChange(resolvedSpace)
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
        } else if isSearching {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search memories...", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFieldFocused)
                        .submitLabel(.search)

                    Spacer()
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect()
                .frame(maxWidth: .infinity)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearching = false
                    }
                }
                .fontWeight(.semibold)
            }
        } else {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "square.grid.2x2")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    toggleSearch()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .disabled(isPerformingBulkAction)
            }

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
            Text(navigationTitleText)
                .appLargeTitleStyle()
                .listRowInsets(.init(top: 24, leading: 20, bottom: 4, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

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
        .onChange(of: isSearching) { _, newValue in
            onSearchActiveChange(newValue)
            if newValue {
                isSearchFieldFocused = true
            } else {
                searchText = ""
            }
        }
    }

    @ViewBuilder
    private var mainListSection: some View {
        timelineAndInboxSection
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

    private var filteredMemories: [MemoryModel] {
        let targetSpace = isAllSpace ? nil : resolvedSpace
        let base = memoryService.memories(
            in: targetSpace,
            statuses: [],
            includeCompleted: true,
            sort: .updatedAtDescending
        )

        return base.filter { memory in
            matchesSelectedContentAndTrigger(memory) &&
            (showInbox || !memory.isInbox) &&
            matchesSearchText(memory)
        }
    }

    private func matchesSearchText(_ memory: MemoryModel) -> Bool {
        guard !searchText.isEmpty else { return true }
        let lowercasedSearch = searchText.lowercased()

        // Search in title
        if memory.title.lowercased().contains(lowercasedSearch) {
            return true
        }

        // Search in note/body
        if let note = memory.note, note.lowercased().contains(lowercasedSearch) {
            return true
        }

        return false
    }



    private func toggleSearch() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSearching.toggle()
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
                    return memory.note != nil && !memory.note!.isEmpty
                case .checklist:
                    return memory.hasChecklist
                case .photos:
                    return !memory.photoAttachmentIDs.isEmpty
                case .links:
                    return !memory.linkAttachmentIDs.isEmpty
                case .audio:
                    return !memory.audioAttachmentIDs.isEmpty
                case .files:
                    return !memory.fileAttachmentIDs.isEmpty
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
