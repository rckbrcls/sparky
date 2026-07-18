//
//  MindDetailView.swift
//  sparky
//

import SwiftUI

struct MindDetailView: View {
    let mind: Mind

    @EnvironmentObject private var environment: AppEnvironment
    @Binding var navigationPath: NavigationPath
    @ObservedObject var mindService: MindService
    @ObservedObject var memoryService: MemoryService

    let onSelectMemory: (Memory) -> Void
    let onEditMemory: ((Memory) -> Void)?
    let onEditMind: ((Mind) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    let onMindContextChange: ((Mind?) -> Void)?
    let onSearchActiveChange: (Bool) -> Void

    @State private var isSearching = false
    @State private var isMultiSelecting = false
    @State private var selectedMemoryIDs: Set<Memory.ID> = []
    @State private var isPerformingBulkAction = false
    @State private var showingDeleteConfirmation = false
    @State private var bulkActionErrorMessage: String?
    @State private var expandedSections: Set<MindSectionType> = Set(MindSectionType.allCases.filter { $0 != .complete })
    private let animatedMindsSectionItemLimit = 20
    enum TriggerFilter: String, CaseIterable, Identifiable {
        case scheduled
        case location

        var id: String { rawValue }

        var label: String {
            switch self {
            case .scheduled: return "Date & Time"
            case .location: return "Location"
            }
        }

        var systemImage: String {
            switch self {
            case .scheduled: return "clock.badge"
            case .location: return "mappin.and.ellipse"
            }
        }
    }

    @State private var selectedTriggerTypes: Set<TriggerFilter> = []
    @State private var sortStrategy: MemoryService.SortStrategy = .createdAtDescending
    private enum MindComposerPresentation: Identifiable {
        case create
        case edit(Mind)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let mind): return mind.id.uuidString
            }
        }
    }

    @State private var mindComposerPresentation: MindComposerPresentation?

    init(
        mind: Mind,
        navigationPath: Binding<NavigationPath>,
        mindService: MindService,
        memoryService: MemoryService,
        onSelectMemory: @escaping (Memory) -> Void,
        onEditMemory: ((Memory) -> Void)? = nil,
        onEditMind: ((Mind) -> Void)? = nil,
        onMultiSelectionChange: @escaping (Bool) -> Void,
        onMindContextChange: ((Mind?) -> Void)?,
        onSearchActiveChange: @escaping (Bool) -> Void
    ) {
        self.mind = mind
        self._navigationPath = navigationPath
        self.mindService = mindService
        self.memoryService = memoryService
        self.onSelectMemory = onSelectMemory
        self.onEditMemory = onEditMemory
        self.onEditMind = onEditMind
        self.onMultiSelectionChange = onMultiSelectionChange
        self.onMindContextChange = onMindContextChange
        self.onSearchActiveChange = onSearchActiveChange
    }

    private var resolvedMind: Mind {
        mindService.mind(id: mind.id) ?? mind
    }

    private var isAllMinds: Bool {
        resolvedMind.isAllMinds
    }

    private var childMinds: [Mind] {
        return resolvedMind.children ?? []
    }

    private var memories: [Memory] {
        memoryService.memories(in: resolvedMind, includeCompleted: true)
    }

    private var filteredMemories: [Memory] {
        memoryService.memories(
            in: resolvedMind,
            statuses: [.active, .completed],
            includeCompleted: true,
            sort: sortStrategy
        ).filter { memory in
            guard !selectedTriggerTypes.isEmpty else { return true }
            if selectedTriggerTypes.contains(.scheduled) && memory.hasSchedule { return true }
            if selectedTriggerTypes.contains(.location) && memory.hasLocation { return true }
            return false
        }
    }

    private var pinnedMemories: [Memory] {
        filteredMemories.filter { $0.isPinned && $0.status == .active }
    }

    private var activeMemories: [Memory] {
        filteredMemories.filter { !$0.isPinned && $0.status == .active }
    }

    private var completedMemories: [Memory] {
        filteredMemories.filter { $0.status == .completed }
    }

    private var bulkActionMinds: [Mind] {
        environment.mindService.minds.filter { !$0.isDefault }
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
            .sheet(isPresented: $isSearching) {
                MemorySearchSheet(
                    mind: resolvedMind,
                    memoryService: memoryService,
                    mindService: mindService,
                    onSelectMemory: onSelectMemory
                )
                .presentationDetents([.large])
                .presentationCornerRadius(24)
                .presentationDragIndicator(.visible)
            }
            .platformCover(item: $mindComposerPresentation) { presentation in
                switch presentation {
                case .create:
                    MindComposerView(environment: environment, parentMind: resolvedMind)
                case .edit(let mind):
                    MindComposerView(environment: environment, mindToEdit: mind, parentMind: resolvedMind)
                }
            }
            .onAppear {
                onMultiSelectionChange(false)
                onMindContextChange?(resolvedMind)
            }
            .onChange(of: isSearching) { _, newValue in
                onSearchActiveChange(newValue)
            }
    }

    private var baseView: some View {
        let isMindsSectionExpanded = expandedSections.contains(.minds)
        let activeMemoryCountsByMindID = isMindsSectionExpanded ? makeActiveMemoryCountsByMindID() : [:]
        let shouldAnimateMindsSection = childMinds.count <= animatedMindsSectionItemLimit

        return ScrollView {
            VStack(spacing: 0) {
                Text(resolvedMind.name)
                    .appLargeTitleStyle()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                    VStack(spacing: 0) {
                        if !childMinds.isEmpty {
                            MindMindsSection(
                                childMinds: childMinds,
                                isExpanded: isMindsSectionExpanded,
                                mindService: mindService,
                                activeMemoryCounts: activeMemoryCountsByMindID,
                                onEditMind: { mind in
                                    mindComposerPresentation = .edit(mind)
                                },
                                onToggleExpanded: {
                                    toggleSection(.minds, animated: shouldAnimateMindsSection)
                                }
                            )
                        }

                        MindMemorySection(
                            sectionType: .pinned,
                            memories: pinnedMemories,
                            isExpanded: expandedSections.contains(.pinned),
                            isMultiSelecting: isMultiSelecting,
                            selectedMemoryIDs: selectedMemoryIDs,
                            isPerformingBulkAction: isPerformingBulkAction,
                            onSelectMemory: onSelectMemory,
                            onEditMemory: onEditMemory,
                            onToggleSelection: toggleMemorySelection,
                            onToggleExpanded: {
                                toggleSection(.pinned)
                            }
                        )

                        MindMemorySection(
                            sectionType: .active,
                            memories: activeMemories,
                            isExpanded: expandedSections.contains(.active),
                            isMultiSelecting: isMultiSelecting,
                            selectedMemoryIDs: selectedMemoryIDs,
                            isPerformingBulkAction: isPerformingBulkAction,
                            onSelectMemory: onSelectMemory,
                            onEditMemory: onEditMemory,
                            onToggleSelection: toggleMemorySelection,
                            onToggleExpanded: {
                                toggleSection(.active)
                            }
                        )

                        MindMemorySection(
                            sectionType: .complete,
                            memories: completedMemories,
                            isExpanded: expandedSections.contains(.complete),
                            isMultiSelecting: isMultiSelecting,
                            selectedMemoryIDs: selectedMemoryIDs,
                            isPerformingBulkAction: isPerformingBulkAction,
                            onSelectMemory: onSelectMemory,
                            onEditMemory: onEditMemory,
                            onToggleSelection: toggleMemorySelection,
                            onToggleExpanded: {
                                toggleSection(.complete)
                            }
                        )
                    }
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.Theme.secondaryBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 70)
        }
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
                ToolbarItem(placement: .navigation) {
                    Button {
                        navigationPath.removeLast()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Section("Filter") {
                            ForEach(TriggerFilter.allCases) { triggerType in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        toggleTriggerType(triggerType)
                                    }
                                } label: {
                                    if selectedTriggerTypes.contains(triggerType) {
                                        Label(triggerType.label, systemImage: "checkmark")
                                    } else {
                                        Label(triggerType.label, systemImage: triggerType.systemImage)
                                    }
                                }
                            }

                            if !selectedTriggerTypes.isEmpty {
                                Button("Clear Filters", systemImage: "xmark.circle") {
                                    withAnimation { selectedTriggerTypes = [] }
                                }
                            }
                        }

                        Section("Sort") {
                            Button {
                                sortStrategy = .createdAtAscending
                            } label: {
                                Label("Created: Oldest First", systemImage: sortStrategy == .createdAtAscending ? "checkmark" : "calendar")
                            }

                            Button {
                                sortStrategy = .createdAtDescending
                            } label: {
                                Label("Created: Newest First", systemImage: sortStrategy == .createdAtDescending ? "checkmark" : "calendar")
                            }

                            Button {
                                sortStrategy = .updatedAtAscending
                            } label: {
                                Label("Updated: Oldest First", systemImage: sortStrategy == .updatedAtAscending ? "checkmark" : "calendar.badge.clock")
                            }

                            Button {
                                sortStrategy = .updatedAtDescending
                            } label: {
                                Label("Updated: Newest First", systemImage: sortStrategy == .updatedAtDescending ? "checkmark" : "calendar.badge.clock")
                            }
                        }
                    } label: {
                        Image(systemName: selectedTriggerTypes.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Section {
                            Button("Search", systemImage: "magnifyingglass") {
                                isSearching = true
                            }
                        }

                        Section {
                            Button("Select", systemImage: "checkmark.circle") {
                                toggleMultiSelection()
                            }
                            .disabled(isPerformingBulkAction)
                        }

                        Section {
                            Button("New Mind", systemImage: "plus") {
                                mindComposerPresentation = .create
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
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
        .navigationBarBackButtonHidden(true)
    }

    private func toggleSection(_ section: MindSectionType, animated: Bool = true) {
        let toggleAction = {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.2)) {
                toggleAction()
            }
        } else {
            toggleAction()
        }
    }

    private func makeActiveMemoryCountsByMindID() -> [Mind.ID: Int] {
        var counts: [Mind.ID: Int] = [:]

        for memory in memoryService.memories where memory.status == .active {
            guard var currentMind = memory.mind else { continue }
            var visitedMindIDs: Set<Mind.ID> = []

            while visitedMindIDs.insert(currentMind.id).inserted {
                counts[currentMind.id, default: 0] += 1
                guard let parentMind = currentMind.parent else { break }
                currentMind = parentMind
            }
        }

        return counts
    }

    private func isTriggerTypeActive(_ type: TriggerFilter) -> Bool {
        selectedTriggerTypes.isEmpty || selectedTriggerTypes.contains(type)
    }

    private func toggleTriggerType(_ type: TriggerFilter) {
        if selectedTriggerTypes.isEmpty {
            selectedTriggerTypes = [type]
        } else if selectedTriggerTypes.contains(type) {
            selectedTriggerTypes.remove(type)
        } else {
            selectedTriggerTypes.insert(type)
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
