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
    let onCreateMemory: (Mind?) -> Void
    let onMultiSelectionChange: (Bool) -> Void
    let onMindContextChange: ((Mind?) -> Void)?
    let onSearchActiveChange: (Bool) -> Void

    @State private var isSearching = false
    @State private var isMultiSelecting = false
    @State private var selectedMemoryIDs: Set<Memory.ID> = []
    @State private var isPerformingBulkAction = false
    @State private var showingDeleteConfirmation = false
    @State private var bulkActionErrorMessage: String?

    private enum StatusFilter: String, CaseIterable, Identifiable {
        case all
        case active
        case completed

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: return "All"
            case .active: return "Active"
            case .completed: return "Completed"
            }
        }

        var systemImage: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .active: return "circle"
            case .completed: return "checkmark.circle"
            }
        }

        var statuses: [MemoryStatus] {
            switch self {
            case .all: return MemoryStatus.allCases
            case .active: return [.active]
            case .completed: return [.completed]
            }
        }
    }

    private enum MindAssignmentFilter: String, CaseIterable, Identifiable {
        case all
        case withMind
        case noMind

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: return "All"
            case .withMind: return "With Mind"
            case .noMind: return "No Mind"
            }
        }

        var systemImage: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .withMind: return "folder"
            case .noMind: return "tray"
            }
        }
    }

    private struct MindFilterOption: Identifiable {
        let mind: Mind
        let depth: Int

        var id: Mind.ID { mind.id }
    }

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

    @State private var statusFilter: StatusFilter = .all
    @State private var mindAssignmentFilter: MindAssignmentFilter = .all
    @State private var selectedMindIDs: Set<Mind.ID> = []
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
        onCreateMemory: @escaping (Mind?) -> Void,
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
        self.onCreateMemory = onCreateMemory
        self.onMultiSelectionChange = onMultiSelectionChange
        self.onMindContextChange = onMindContextChange
        self.onSearchActiveChange = onSearchActiveChange
    }

    private var resolvedMind: Mind {
        mindService.mind(id: mind.id) ?? mind
    }

    private var childMinds: [Mind] {
        return resolvedMind.children ?? []
    }

    private var unfilteredMemories: [Memory] {
        memoryService.memories(
            in: resolvedMind,
            includeCompleted: true
        )
    }

    private var shouldShowEmptyState: Bool {
        MindDetailView.shouldShowEmptyState(
            childMindsCount: childMinds.count,
            unfilteredMemoriesCount: unfilteredMemories.count
        )
    }

    private var emptyStateTargetMind: Mind? {
        MindDetailView.targetMind(for: resolvedMind)
    }

    private var emptyStateAccessibilityLabel: String {
        guard let targetMind = emptyStateTargetMind else {
            return "Add Memory"
        }
        return "Add Memory to \(targetMind.name)"
    }

    private var filteredMemories: [Memory] {
        memoryService.memories(
            in: resolvedMind,
            statuses: statusFilter.statuses,
            includeCompleted: true,
            sort: sortStrategy
        ).filter { memory in
            matchesTriggerFilter(memory) && matchesMindAssignmentFilter(memory)
        }
    }

    private var hasActiveFilters: Bool {
        statusFilter != .all
            || !selectedTriggerTypes.isEmpty
            || (resolvedMind.isAllMinds && mindAssignmentFilter != .all)
    }

    private var mindFilterOptions: [MindFilterOption] {
        var options: [MindFilterOption] = []
        var visitedMindIDs: Set<Mind.ID> = []
        let rootMinds = mindService.minds.filter { $0.parent == nil }

        appendMindFilterOptions(
            from: rootMinds,
            depth: 0,
            visitedMindIDs: &visitedMindIDs,
            options: &options
        )

        let remainingMinds = mindService.minds.filter { !visitedMindIDs.contains($0.id) }
        appendMindFilterOptions(
            from: remainingMinds,
            depth: 0,
            visitedMindIDs: &visitedMindIDs,
            options: &options
        )

        return options
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
            .onAppear {
                onMultiSelectionChange(false)
                onMindContextChange?(resolvedMind)
            }
            .onChange(of: isSearching) { _, newValue in
                onSearchActiveChange(newValue)
            }
    }

    private var baseView: some View {
        let activeMemoryCountsByMindID = childMinds.isEmpty ? [:] : makeActiveMemoryCountsByMindID()
        let displayContent = MindMemoryDisplayContent(memories: filteredMemories)

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
                        MindMindsGrid(
                            childMinds: childMinds,
                            mindService: mindService,
                            activeMemoryCounts: activeMemoryCountsByMindID,
                            onEditMind: { mind in
                                mindComposerPresentation = .edit(mind)
                            }
                        )
                    }

                    if shouldShowEmptyState {
                        MindEmptyStateView(
                            accessibilityLabel: emptyStateAccessibilityLabel,
                            onCreateMemory: {
                                onCreateMemory(emptyStateTargetMind)
                            }
                        )
                        .padding(.top, 40)
                    } else {
                        if !displayContent.pinnedMemories.isEmpty {
                            MindPinnedSection(
                                memories: displayContent.pinnedMemories,
                                isMultiSelecting: isMultiSelecting,
                                selectedMemoryIDs: selectedMemoryIDs,
                                isPerformingBulkAction: isPerformingBulkAction,
                                onSelectMemory: onSelectMemory,
                                onEditMemory: onEditMemory,
                                onToggleSelection: toggleMemorySelection
                            )
                        }

                        MindMemoryList(
                            memories: displayContent.remainingMemories,
                            isMultiSelecting: isMultiSelecting,
                            selectedMemoryIDs: selectedMemoryIDs,
                            isPerformingBulkAction: isPerformingBulkAction,
                            onSelectMemory: onSelectMemory,
                            onEditMemory: onEditMemory,
                            onToggleSelection: toggleMemorySelection
                        )
                    }
                }
            }
            #if os(macOS)
            .frame(
                maxWidth: DesktopLayoutMetrics.primaryContentMaxWidth,
                alignment: .leading
            )
            #endif
            .frame(maxWidth: .infinity)
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
                    .neutralToolbarItemStyle()
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Section("Status") {
                            ForEach(StatusFilter.allCases) { filter in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        statusFilter = filter
                                    }
                                } label: {
                                    Label(
                                        filter.label,
                                        systemImage: statusFilter == filter ? "checkmark" : filter.systemImage
                                    )
                                }
                            }
                        }

                        if resolvedMind.isAllMinds {
                            Section("Mind") {
                                ForEach(MindAssignmentFilter.allCases) { filter in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            setMindAssignmentFilter(filter)
                                        }
                                    } label: {
                                        Label(
                                            filter.label,
                                            systemImage: mindAssignmentFilter == filter
                                                ? "checkmark"
                                                : filter.systemImage
                                        )
                                    }
                                }
                            }

                            if mindAssignmentFilter == .withMind && !mindFilterOptions.isEmpty {
                                Section("Minds") {
                                    ForEach(mindFilterOptions) { option in
                                        Toggle(
                                            isOn: Binding(
                                                get: { selectedMindIDs.contains(option.id) },
                                                set: { isSelected in
                                                    setMind(option.id, isSelected: isSelected)
                                                }
                                            )
                                        ) {
                                            Label(
                                                mindFilterLabel(for: option),
                                                systemImage: option.mind.iconName ?? "brain.head.profile"
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        Section("Triggers") {
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
                        }

                        if hasActiveFilters {
                            Section {
                                Button("Clear Filters", systemImage: "xmark.circle") {
                                    withAnimation {
                                        statusFilter = .all
                                        mindAssignmentFilter = .all
                                        selectedMindIDs = []
                                        selectedTriggerTypes = []
                                    }
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
                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .neutralToolbarItemStyle()
                    .accessibilityLabel("Filter memories")
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        #if os(iOS)
                        Section {
                            Button("Search", systemImage: "magnifyingglass") {
                                isSearching = true
                            }
                        }
                        #endif

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
                    .neutralToolbarItemStyle()
                    .platformSheet(isPresented: $isSearching) {
                        MemorySearchSheet(
                            mind: resolvedMind,
                            memoryService: memoryService,
                            mindService: mindService,
                            onSelectMemory: onSelectMemory
                        )
                        .presentationDetents([.large])
                        .presentationCornerRadius(24)
                        .presentationDragIndicator(.visible)
                        .macPopoverFrame(width: 480, height: 560)
                    }
                    .platformCover(item: $mindComposerPresentation) { presentation in
                        switch presentation {
                        case .create:
                            MindComposerView(
                                environment: environment,
                                parentMind: resolvedMind,
                                presentationStyle: .platformPopover
                            )
                            .macPopoverFrame(width: 440, height: 560)
                        case let .edit(mind):
                            MindComposerView(
                                environment: environment,
                                mindToEdit: mind,
                                parentMind: resolvedMind,
                                presentationStyle: .platformPopover
                            )
                            .macPopoverFrame(width: 440, height: 560)
                        }
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

    private func toggleTriggerType(_ type: TriggerFilter) {
        if selectedTriggerTypes.isEmpty {
            selectedTriggerTypes = [type]
        } else if selectedTriggerTypes.contains(type) {
            selectedTriggerTypes.remove(type)
        } else {
            selectedTriggerTypes.insert(type)
        }
    }

    private func matchesTriggerFilter(_ memory: Memory) -> Bool {
        guard !selectedTriggerTypes.isEmpty else { return true }
        if selectedTriggerTypes.contains(.scheduled) && memory.hasSchedule { return true }
        if selectedTriggerTypes.contains(.location) && memory.hasLocation { return true }
        return false
    }

    private func matchesMindAssignmentFilter(_ memory: Memory) -> Bool {
        guard resolvedMind.isAllMinds else { return true }

        switch mindAssignmentFilter {
        case .all:
            return true
        case .withMind:
            guard let mindID = memory.mind?.id else { return false }
            return selectedMindIDs.isEmpty || selectedMindIDs.contains(mindID)
        case .noMind:
            return memory.mind == nil
        }
    }

    private func setMindAssignmentFilter(_ filter: MindAssignmentFilter) {
        mindAssignmentFilter = filter
        if filter != .withMind {
            selectedMindIDs.removeAll()
        }
    }

    private func setMind(_ mindID: Mind.ID, isSelected: Bool) {
        if isSelected {
            selectedMindIDs.insert(mindID)
        } else {
            selectedMindIDs.remove(mindID)
        }
    }

    private func mindFilterLabel(for option: MindFilterOption) -> String {
        String(repeating: "› ", count: option.depth) + option.mind.name
    }

    private func appendMindFilterOptions(
        from minds: [Mind],
        depth: Int,
        visitedMindIDs: inout Set<Mind.ID>,
        options: inout [MindFilterOption]
    ) {
        for mind in sortedMinds(minds) {
            guard visitedMindIDs.insert(mind.id).inserted else { continue }
            options.append(MindFilterOption(mind: mind, depth: depth))
            appendMindFilterOptions(
                from: mind.children ?? [],
                depth: depth + 1,
                visitedMindIDs: &visitedMindIDs,
                options: &options
            )
        }
    }

    private func sortedMinds(_ minds: [Mind]) -> [Mind] {
        minds.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
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

// MARK: - Testable Pure Helpers
extension MindDetailView {
    nonisolated static func shouldShowEmptyState(
        childMindsCount: Int,
        unfilteredMemoriesCount: Int
    ) -> Bool {
        childMindsCount == 0 && unfilteredMemoriesCount == 0
    }

    static func targetMind(for mind: Mind) -> Mind? {
        if mind.isAllMinds {
            return nil
        }
        return mind
    }
}
