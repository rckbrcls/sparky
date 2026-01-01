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
    let onEditSpace: ((SpaceModel) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    let onSpaceContextChange: (SpaceModel?) -> Void
    let onSearchActiveChange: (Bool) -> Void

    @State private var selectedTriggerTypes: Set<MemoryTriggerType> = []
    @State private var showPinned = true




    @State private var isMultiSelecting = false
    @State private var selectedMemoryIDs: Set<MemoryModel.ID> = []
    @State private var isPerformingBulkAction = false
    @State private var showingDeleteConfirmation = false
    @State private var bulkActionErrorMessage: String?

    @State private var isSearching = false
    @State private var searchText = ""

    @FocusState private var isSearchFieldFocused: Bool

    @State private var isPinnedExpanded = true
    @State private var isActiveExpanded = true
    @State private var isCompletedExpanded = true

    private var activeFilterCount: Int {
        if !selectedTriggerTypes.isEmpty && selectedTriggerTypes.count < MemoryTriggerType.allCases.count {
            return selectedTriggerTypes.count
        }
        return 0
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
        filteredMemories.filter { !$0.isPinned && !$0.isCompleted }
    }

    private var pinnedMemories: [MemoryModel] {
        let referenceDate = Date()
        return filteredMemories
            .filter { $0.isPinned && !$0.isCompleted }
            .sorted { lhs, rhs in
                sortPinned(lhs, rhs, referenceDate: referenceDate)
            }
    }

    private var completedMemories: [MemoryModel] {
        filteredMemories.filter { $0.isCompleted }
    }

    private var shouldShowEmptyStateCard: Bool {
        nonPinnedMemories.isEmpty && pinnedMemories.isEmpty && completedMemories.isEmpty
    }

    private var filterDescription: String {
        if !selectedTriggerTypes.isEmpty && selectedTriggerTypes.count < MemoryTriggerType.allCases.count {
            let triggerTypeLabels = selectedTriggerTypes
                .map(\.label)
                .sorted()
            return triggerTypeLabels.joined(separator: ", ")
        }
        return "All"
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
                isStatusEnabled: canMoveSelection,
                isSpaceEnabled: canMoveSelection && !bulkActionSpaces.isEmpty,
                onSelectSpace: { space in performMove(to: space) },
                onSelectStatus: { status in performStatusUpdate(to: status) },
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



    private var spaceDetailList: some View {
        List {
            Text(navigationTitleText)
                .appLargeTitleStyle()
                .listRowInsets(.init(top: 24, leading: 20, bottom: 4, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            FilterBadgesBar(
                selectedTriggerTypes: $selectedTriggerTypes,
                showPinned: $showPinned
            )
            .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            timelineAndInboxSection
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
    private var timelineAndInboxSection: some View {
        if showPinned {
            Section {
                 Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPinnedExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(Color.orange)
                            .font(.subheadline)
                        Text("Pinned")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Text("\(pinnedMemories.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isPinnedExpanded ? 90 : 0))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.orange.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(.init(top: 16, leading: 20, bottom: 4, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if isPinnedExpanded {
                     ForEach(pinnedMemories) { memory in
                        MemoryListItemButton(
                            memory: memory,
                            isMultiSelecting: isMultiSelecting,
                            isSelected: isMemorySelected(memory),
                            isDisabled: isPerformingBulkAction,
                            onSelect: onSelectMemory,
                            onToggleSelection: toggleMemorySelection(_:)
                        )
                        .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
             .listSectionSeparator(.hidden)
        }

        Section {
                 Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isActiveExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(Color.blue)
                            .font(.subheadline)
                        Text("Memories")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Text("\(nonPinnedMemories.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isActiveExpanded ? 90 : 0))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.blue.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(.init(top: 16, leading: 20, bottom: 4, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if isActiveExpanded {
                    ForEach(nonPinnedMemories) { memory in
                        MemoryListItemButton(
                            memory: memory,
                            isMultiSelecting: isMultiSelecting,
                            isSelected: isMemorySelected(memory),
                            isDisabled: isPerformingBulkAction,
                            onSelect: onSelectMemory,
                            onToggleSelection: toggleMemorySelection(_:)
                        )
                        .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
             .listSectionSeparator(.hidden)

        Section {
                 Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCompletedExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                            .font(.subheadline)
                        Text("Completed")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Text("\(completedMemories.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isCompletedExpanded ? 90 : 0))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.green.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(.init(top: 16, leading: 20, bottom: 4, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if isCompletedExpanded {
                     ForEach(completedMemories) { memory in
                        MemoryListItemButton(
                            memory: memory,
                            isMultiSelecting: isMultiSelecting,
                            isSelected: isMemorySelected(memory),
                            isDisabled: isPerformingBulkAction,
                            onSelect: onSelectMemory,
                            onToggleSelection: toggleMemorySelection(_:)
                        )
                        .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listSectionSeparator(.hidden)

        if nonPinnedMemories.isEmpty && pinnedMemories.isEmpty && completedMemories.isEmpty {
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
            matchesSelectedTrigger(memory) &&
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

    private func matchesSelectedTrigger(_ memory: MemoryModel) -> Bool {
        // Check trigger types
        if selectedTriggerTypes.isEmpty {
            return true
        }
        return selectedTriggerTypes.contains { triggerType in
            memory.triggers.contains { $0.type == triggerType && $0.isActive }
        }
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
