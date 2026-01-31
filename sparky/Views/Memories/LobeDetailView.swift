//
//  LobeDetailView.swift
//  sparky
//
//  Created by Codex on 09/03/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct LobeDetailView: View {
    let lobe: Space

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var lobeService: LobeService
    @ObservedObject var memoryService: MemoryService

    let onSelectMemory: (Memory) -> Void
    let onEditMemory: ((Memory) -> Void)?
    let onEditLobe: ((Space) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    let onLobeContextChange: (Space?) -> Void
    let onSearchActiveChange: (Bool) -> Void

    @State private var selectedTriggerTypes: Set<MemoryTriggerType> = []
    @State private var selectedSortStrategy: MemoryService.SortStrategy = .updatedAtDescending

    @State private var isMultiSelecting = false
    @State private var selectedMemoryIDs: Set<Memory.ID> = []
    @State private var isPerformingBulkAction = false
    @State private var showingDeleteConfirmation = false
    @State private var bulkActionErrorMessage: String?
    @State private var isSearching = false
    @State private var isPinnedExpanded = true
    @State private var isActiveExpanded = true
    @State private var isCompletedExpanded = false
    @State private var draggedMemoryID: UUID? = nil

    private var activeFilterCount: Int {
        if !selectedTriggerTypes.isEmpty && selectedTriggerTypes.count < MemoryTriggerType.allCases.count {
            return selectedTriggerTypes.count
        }
        return 0
    }

    private var isFiltering: Bool {
        activeFilterCount > 0
    }

    private var resolvedLobe: Space {
        lobeService.lobe(id: lobe.id) ?? lobe
    }

    private var isAllSpaces: Bool {
        resolvedLobe.isAllSpaces
    }

    private var isInboxSpace: Bool {
        resolvedLobe.isInbox
    }

    private var isLimboSpace: Bool {
        resolvedLobe.isLimbo
    }

    private var isAllSpaceForMind: Bool {
        resolvedLobe.isAllSpaceForMind
    }

    private var nonPinnedMemories: [Memory] {
        filteredMemories.filter { !$0.isPinned && !$0.isCompleted }
    }

    private var pinnedMemories: [Memory] {
        let referenceDate = Date()
        return filteredMemories
            .filter { $0.isPinned && !$0.isCompleted }
            .sorted { lhs, rhs in
                sortPinned(lhs, rhs, referenceDate: referenceDate)
            }
    }

    private var completedMemories: [Memory] {
        filteredMemories.filter { $0.isCompleted }
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

    private var navigationTitleText: String {
        if isMultiSelecting {
            if selectedMemoryIDs.isEmpty {
                return "Select Memories"
            }
            return "\(selectedMemoryIDs.count) Selected"
        }
        return resolvedLobe.name
    }

    private var bulkActionLobes: [Space] {
        environment.lobeService.lobes.filter {
            $0.id != Space.allSpacesIdentifier &&
            $0.id != Space.inboxIdentifier &&
            $0.id != Space.limboIdentifier
        }
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
        baseView
            .modifier(LobeDetailModifiers(
                showingDeleteConfirmation: $showingDeleteConfirmation,
                bulkActionErrorMessage: $bulkActionErrorMessage,
                deleteConfirmationMessage: deleteConfirmationMessage,
                isPerformingBulkAction: isPerformingBulkAction,
                onDelete: performBulkDeletion
            ))
            .modifier(LobeDetailContextModifiers(
                isMultiSelecting: isMultiSelecting,
                lobeID: lobe.id,
                lobeService: lobeService,
                onMultiSelectionChange: onMultiSelectionChange,
                onNotifyContext: notifyLobeContextChange,
                resolvedLobeProvider: { resolvedLobe }
            ))
            .fullScreenCover(isPresented: $isSearching) {
                MemorySearchSheet(
                    lobe: lobe,
                    memoryService: memoryService,
                    onSelectMemory: onSelectMemory,
                    lobeService: lobeService
                )
            }
    }

    private var baseView: some View {
        lobeDetailList
            .navigationBarBackButtonHidden(true)
            .toolbar { toolbarContent }
    }

    private func notifyLobeContextChange() {
        // Always notify with the resolved lobe to ensure context is up to date
        onLobeContextChange(resolvedLobe)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isMultiSelecting {
            MemoryMultiSelectToolbarContent(
                availableLobes: bulkActionLobes,
                isPerformingBulkAction: isPerformingBulkAction,
                canPerformDeletion: canMoveSelection,
                isStatusEnabled: canMoveSelection,
                isLobeEnabled: canMoveSelection && !bulkActionLobes.isEmpty,
                onSelectLobe: { lobe in performMove(to: lobe) },
                onSelectStatus: { status in performStatusUpdate(to: status) },
                onDelete: { showingDeleteConfirmation = true },
                onDone: { toggleMultiSelection() }
            )
        } else {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
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



    private var lobeDetailList: some View {
        List {
            Text(navigationTitleText)
                .appLargeTitleStyle()
                .listRowInsets(.init(top: 24, leading: 20, bottom: 4, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            FilterBadgesBar(
                selectedTriggerTypes: $selectedTriggerTypes,
                sortStrategy: $selectedSortStrategy
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
        .animation(.easeInOut(duration: 0.35), value: pinnedMemories.map(\.id))
        .animation(.easeInOut(duration: 0.35), value: nonPinnedMemories.map(\.id))
        .animation(.easeInOut(duration: 0.35), value: completedMemories.map(\.id))
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 70)
        }
        .listRowSeparator(.hidden)
        .background(Color.clear)
        .onChange(of: isSearching) { _, newValue in
            onSearchActiveChange(newValue)
        }
    }

    @ViewBuilder
    private var timelineAndInboxSection: some View {
        // Pinned section
            Section {
                 Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPinnedExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.elementBorder)
                            .font(.subheadline)
                        Text("Pinned")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.elementBorder)
                        Text("\(pinnedMemories.count)")
                            .font(.caption)
                            .foregroundStyle(.elementBorder)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.elementBorder)
                            .rotationEffect(.degrees(isPinnedExpanded ? 90 : 0))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.accentColor.opacity(0.8), lineWidth: 1)
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
                            onToggleSelection: toggleMemorySelection(_:),
                            onEditMemory: onEditMemory
                        )
                        .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .opacity(draggedMemoryID == memory.id ? 0.5 : 1.0)
                        .onDrag {
                            guard selectedSortStrategy == .manual, !isMultiSelecting else {
                                return NSItemProvider()
                            }
                            draggedMemoryID = memory.id
                            return NSItemProvider(object: memory.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            handleDrop(providers: providers, targetMemoryID: memory.id, memories: pinnedMemories)
                            return true
                        }
                    }
                }
            }
             .listSectionSeparator(.hidden)

        Section {
                 Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isActiveExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.elementBorder)
                            .font(.subheadline)
                        Text("Active")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.elementBorder)
                        Text("\(nonPinnedMemories.count)")
                            .font(.caption)
                            .foregroundStyle(.elementBorder)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.elementBorder)
                            .rotationEffect(.degrees(isActiveExpanded ? 90 : 0))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.accentColor.opacity(0.8), lineWidth: 1)
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
                            onToggleSelection: toggleMemorySelection(_:),
                            onEditMemory: onEditMemory
                        )
                        .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .opacity(draggedMemoryID == memory.id ? 0.5 : 1.0)
                        .onDrag {
                            guard selectedSortStrategy == .manual, !isMultiSelecting else {
                                return NSItemProvider()
                            }
                            draggedMemoryID = memory.id
                            return NSItemProvider(object: memory.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            handleDrop(providers: providers, targetMemoryID: memory.id, memories: nonPinnedMemories)
                            return true
                        }
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
                            .foregroundStyle(.elementBorder)
                            .font(.subheadline)
                        Text("Completed")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.elementBorder)
                        Text("\(completedMemories.count)")
                            .font(.caption)
                            .foregroundStyle(.elementBorder)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.elementBorder)
                            .rotationEffect(.degrees(isCompletedExpanded ? 90 : 0))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.accentColor.opacity(0.8), lineWidth: 1)
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
                            onToggleSelection: toggleMemorySelection(_:),
                            onEditMemory: onEditMemory
                        )
                        .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .opacity(draggedMemoryID == memory.id ? 0.5 : 1.0)
                        .onDrag {
                            guard selectedSortStrategy == .manual, !isMultiSelecting else {
                                return NSItemProvider()
                            }
                            draggedMemoryID = memory.id
                            return NSItemProvider(object: memory.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            handleDrop(providers: providers, targetMemoryID: memory.id, memories: completedMemories)
                            return true
                        }
                    }
                }
            }
            .listSectionSeparator(.hidden)


    }

    private var filteredMemories: [Memory] {
        let base: [Memory]
        if isAllSpaces {
            base = memoryService.memories(
                in: nil,
                statuses: [],
                includeCompleted: true,
                sort: selectedSortStrategy
            )
        } else if isInboxSpace || isLimboSpace {
            let unsorted = memoryService.memories.filter { memory in
                memory.lobe == nil
            }
            base = memoryService.sortedMemories(unsorted, using: selectedSortStrategy)
        } else if isAllSpaceForMind {
            if let mindID = resolvedLobe.mind?.id {
                let unsorted = memoryService.memories.filter { memory in
                    guard let memoryLobeMindID = memory.lobe?.mind?.id else { return false }
                    return memoryLobeMindID == mindID
                }
                base = memoryService.sortedMemories(unsorted, using: selectedSortStrategy)
            } else {
                base = []
            }
        } else {
            base = memoryService.memories(
                in: resolvedLobe,
                statuses: [],
                includeCompleted: true,
                sort: selectedSortStrategy
            )
        }

        return base.filter { memory in
            matchesSelectedTrigger(memory)
        }
    }





    private func toggleSearch() {
        isSearching.toggle()
    }

    private func matchesSelectedTrigger(_ memory: Memory) -> Bool {
        // Check trigger types
        if selectedTriggerTypes.isEmpty {
            return true
        }
        return selectedTriggerTypes.contains { triggerType in
            switch triggerType {
            case .scheduled:
                return memory.hasSchedule
            case .location:
                return memory.hasLocation
            }
        }
    }

    private func isMemorySelected(_ memory: Memory) -> Bool {
        selectedMemoryIDs.contains(memory.id)
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

    private func performMove(to lobe: Space) {
        performBulkAction { processor, ids in
            await processor.moveMemories(ids, to: lobe)
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
                // Failures handled individually.
            }
        }
    }

    private func sortPinned(_ lhs: Memory, _ rhs: Memory, referenceDate: Date = Date()) -> Bool {
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

        return (lhs.updatedAt ?? Date()) > (rhs.updatedAt ?? Date())
    }

    private func handleDrop(providers: [NSItemProvider], targetMemoryID: UUID, memories: [Memory]) {
        guard selectedSortStrategy == .manual else {
            draggedMemoryID = nil
            return
        }

        // Try to get the dragged ID from the provider first
        if let provider = providers.first {
            provider.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
                var decodedUUID: UUID? = nil

                if error == nil {
                    // Try to decode UUID from provider data
                    if let data = data as? Data,
                       let uuidString = String(data: data, encoding: .utf8),
                       let uuid = UUID(uuidString: uuidString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        decodedUUID = uuid
                    } else if let string = data as? String,
                              let uuid = UUID(uuidString: string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        decodedUUID = uuid
                    }
                }

                // Use decoded UUID or fallback to draggedID from state
                let finalDraggedID = decodedUUID ?? draggedMemoryID

                DispatchQueue.main.async {
                    if let draggedID = finalDraggedID, draggedID != targetMemoryID {
                        self.processDrop(draggedID: draggedID, droppedOnID: targetMemoryID, in: memories)
                    } else {
                        draggedMemoryID = nil
                    }
                }
            }
        } else {
            // If no provider, try using draggedID from state directly
            if let draggedID = draggedMemoryID, draggedID != targetMemoryID {
                processDrop(draggedID: draggedID, droppedOnID: targetMemoryID, in: memories)
            } else {
                draggedMemoryID = nil
            }
        }
    }

    private func processDrop(draggedID: UUID, droppedOnID: UUID, in memories: [Memory]) {
        guard selectedSortStrategy == .manual,
              let draggedIndex = memories.firstIndex(where: { $0.id == draggedID }),
              let droppedIndex = memories.firstIndex(where: { $0.id == droppedOnID }),
              draggedIndex != droppedIndex else {
            draggedMemoryID = nil
            return
        }

        var reorderedMemories = memories
        let draggedMemory = reorderedMemories.remove(at: draggedIndex)
        reorderedMemories.insert(draggedMemory, at: droppedIndex)

        let memoryIDs = reorderedMemories.map { $0.id }

        Task {
            do {
                try await memoryService.updateMemoryOrder(memoryIDs: memoryIDs)
            } catch {
                // Handle error silently for now
            }
        }

        draggedMemoryID = nil
    }
}

private struct LobeDetailModifiers: ViewModifier {
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

private struct LobeDetailContextModifiers: ViewModifier {
    let isMultiSelecting: Bool
    let lobeID: UUID
    @ObservedObject var lobeService: LobeService
    let onMultiSelectionChange: (Bool) -> Void
    let onNotifyContext: () -> Void
    let resolvedLobeProvider: () -> Space

    private var resolvedLobe: Space {
        resolvedLobeProvider()
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
            .onReceive(lobeService.$lobes) { _ in
                onNotifyContext()
            }
            .onChange(of: resolvedLobe.id) { _, _ in
                onNotifyContext()
            }
            .onDisappear {
                onMultiSelectionChange(false)
            }
            .task(id: resolvedLobe.id) {
                onNotifyContext()
            }
            .onChange(of: lobeID) { _, _ in
                onNotifyContext()
            }
    }
}
