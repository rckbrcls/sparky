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

    @EnvironmentObject private var environment: AppEnvironment
    @State private var showingFilterSheet = false
    @State private var searchText = ""
    @State private var selectedMemoryTypes: Set<MemoryType> = []
    @State private var selectedSections: Set<MemoryService.TimelineSection.Kind> = []
    @State private var showInbox = true
    @State private var filterSheetDetent: PresentationDetent = .large
    @State private var collapsedSections: Set<MemoryService.TimelineSection.Kind> = []
    @State private var isInboxExpanded = true
    @State private var isUpcomingExpanded = true
    @State private var autoCollapsedInbox = false
    @State private var autoCollapsedUpcoming = false
    @State private var isMultiSelecting = false
    @State private var selectedMemoryIDs: Set<MemoryModel.ID> = []
    @State private var isPerformingBulkAction = false
    @State private var showingDeleteConfirmation = false

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
                        isMemoryTypeSelected(memory)
                    }
                )
            }
            .filter { !$0.memories.isEmpty }
    }

    private var filteredInboxMemories: [MemoryModel] {
        memoryService.inboxMemories()
            .filter { isMemoryTypeSelected($0) }
    }

    private var activeFilterCount: Int {
        var count = 0
        if !selectedMemoryTypes.isEmpty && selectedMemoryTypes.count < MemoryType.allCases.count {
            count += selectedMemoryTypes.count
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

        if !selectedMemoryTypes.isEmpty && selectedMemoryTypes.count < MemoryType.allCases.count {
            let typeLabels = selectedMemoryTypes
                .map(\.label)
                .sorted()
            parts.append(typeLabels.joined(separator: ", "))
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

    private var deleteConfirmationMessage: String {
        let count = selectedMemoryIDs.count
        if count == 1 {
            return "This will permanently remove 1 memory."
        }
        return "This will permanently remove \(count) memories."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isSearching {
                        searchResultsSection
                    } else {
                        timelineSections
                        if showInbox {
                            inboxSection
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 70)
            }
            .navigationTitle(navigationTitleText)
            .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search memories")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if isMultiSelecting {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(selectedMemoryIDs.isEmpty || isPerformingBulkAction)
                        .accessibilityLabel("Delete selected memories")
                    }

                    Button {
                        toggleMultiSelection()
                    } label: {
                        if isMultiSelecting {
                            Text("Done")
                                .fontWeight(.semibold)
                        } else {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                    }
                    .disabled(isPerformingBulkAction)
                }

                ToolbarItem(placement: .principal) {
                    Button {
                        filterSheetDetent = .large
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showingFilterSheet = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .symbolEffect(.bounce, value: activeFilterCount)
                            Text(filterDescription)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .animation(.easeInOut(duration: 0.2), value: filterDescription)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .rotationEffect(.degrees(showingFilterSheet ? 180 : 0))
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showingFilterSheet)
                        }
                        .foregroundStyle(activeFilterCount > 0 ? Color.accent : .primary)
                        .animation(.easeInOut(duration: 0.2), value: activeFilterCount)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.interactive())
                    }
                    .disabled(isMultiSelecting || isPerformingBulkAction)
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheetView(
                    selectedMemoryTypes: $selectedMemoryTypes,
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
            .onAppear(perform: syncExpansionStates)
            .onChange(of: timelineSectionData.count) {
                syncExpansionStates()
            }
            .onChange(of: filteredInboxMemories.count) {
                syncExpansionStates()
            }
            .onChange(of: isUpcomingExpanded) {
                autoCollapsedUpcoming = timelineSectionData.isEmpty && !isUpcomingExpanded
            }
            .onChange(of: isInboxExpanded) {
                autoCollapsedInbox = filteredInboxMemories.isEmpty && !isInboxExpanded
            }
        }
    }

    private var searchResultsSection: some View {
        Section {
            if filteredMemories.isEmpty {
                MemoryEmptyStateCard(
                    systemImage: "magnifyingglass",
                    title: "No memories match your search",
                    message: "Try different keywords or reset filters to discover more memories."
                )
            } else {
                ForEach(filteredMemories) { memory in
                    MemoryListItemButton(
                        memory: memory,
                        isMultiSelecting: isMultiSelecting,
                        isSelected: isMemorySelected(memory),
                        isDisabled: isPerformingBulkAction,
                        onSelect: onSelectMemory,
                        onToggleSelection: toggleMemorySelection(_:))
                }
            }
        } header: {
            Divider()
                .padding(.top, 16)
        }
    }

    private var timelineSections: some View {
        let sections = timelineSectionData

        return Group {
            if sections.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    DisclosureGroup(isExpanded: $isUpcomingExpanded) {
                        MemoryEmptyStateCard(
                            systemImage: "tray",
                            title: "No memories with active triggers",
                            message: "Create or activate reminders to see them organized on your timeline."
                        )
                        .padding(.top)
                    } label: {
                        Label("Upcoming", systemImage: "calendar")
                            .foregroundStyle(.white)
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isUpcomingExpanded)
                }
                .padding(.top)
            } else {
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
                        onToggleSelection: toggleMemorySelection(_:))
                }
            }
        }
    }

    private var inboxSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(isExpanded: $isInboxExpanded) {
                if filteredInboxMemories.isEmpty {
                    MemoryEmptyStateCard(
                        systemImage: "checkmark.seal",
                        title: "Inbox is clear",
                        message: "Create a memory or capture a reminder to keep building your inbox."
                    )
                    .padding(.top)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(filteredInboxMemories) { memory in
                            MemoryListItemButton(
                                memory: memory,
                                isMultiSelecting: isMultiSelecting,
                                isSelected: isMemorySelected(memory),
                                isDisabled: isPerformingBulkAction,
                                onSelect: onSelectMemory,
                                onToggleSelection: toggleMemorySelection(_:))
                        }
                    }
                    .padding(.top)
                }
            } label: {
                Label("Inbox", systemImage: "tray.fill")
                    .foregroundStyle(.white)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isInboxExpanded)
        }
        .padding(.top)
    }

    private func isMemoryTypeSelected(_ memory: MemoryModel) -> Bool {
        if selectedMemoryTypes.isEmpty {
            return true
        }
        guard let origin = memory.metadata.origin else { return true }

        switch origin {
        case .reminder:
            return selectedMemoryTypes.contains(.reminder)
        case .note:
            return selectedMemoryTypes.contains(.note)
        case .todoList:
            return selectedMemoryTypes.contains(.todo)
        }
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

    private func toggleMemorySelection(_ memory: MemoryModel) {
        let id = memory.id
        if selectedMemoryIDs.contains(id) {
            selectedMemoryIDs.remove(id)
        } else {
            selectedMemoryIDs.insert(id)
        }
    }

    private func syncExpansionStates() {
        if timelineSectionData.isEmpty {
            if isUpcomingExpanded {
                isUpcomingExpanded = false
                autoCollapsedUpcoming = true
            }
        } else if autoCollapsedUpcoming && !isUpcomingExpanded {
            isUpcomingExpanded = true
            autoCollapsedUpcoming = false
        }

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
            guard let memory = memoryService.memory(id: id),
                  let origin = memory.metadata.origin else {
                continue
            }

            do {
                switch origin {
                case .reminder(let reminderID):
                    try await environment.reminderService.deleteReminder(id: reminderID)
                case .note(let noteID):
                    try await environment.noteService.deleteNote(id: noteID)
                case .todoList(let listID):
                    try await environment.todoService.deleteList(id: listID)
                }
            } catch {
                // Silently ignore failures for now; individual services surface errors independently.
            }
        }

        await memoryService.refresh(force: true)
    }

}

enum MemoryType: String, CaseIterable, Identifiable {
    case reminder
    case note
    case todo

    var id: String { rawValue }

    var label: String {
        switch self {
        case .reminder: return "Reminders"
        case .note: return "Notes"
        case .todo: return "Todos"
        }
    }

    var systemImage: String {
        switch self {
        case .reminder: return "bell.fill"
        case .note: return "note.text"
        case .todo: return "checklist"
        }
    }
}

struct FilterSheetView: View {
    @Environment(\.dismiss) var dismiss

    @Binding var selectedMemoryTypes: Set<MemoryType>
    @Binding var selectedSections: Set<MemoryService.TimelineSection.Kind>
    @Binding var showInbox: Bool
    @Binding var detentSelection: PresentationDetent

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMemoryTypes.removeAll()
                        }
                    } label: {
                        HStack {
                            Label("All Types", systemImage: "square.stack.3d.up.fill")
                                .foregroundStyle(Color.accent)
                            Spacer()
                            if selectedMemoryTypes.isEmpty || selectedMemoryTypes.count == MemoryType.allCases.count {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accent)
                                    .fontWeight(.semibold)
                            }
                        }
                    }

                    ForEach(MemoryType.allCases) { type in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                toggleMemoryType(type)
                            }
                        } label: {
                            HStack {
                                Label(type.label, systemImage: type.systemImage)
                                    .foregroundStyle(Color.accent)
                                Spacer()
                                if isMemoryTypeVisuallySelected(type) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Memory Type")
                }

                Section {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSections.removeAll()
                        }
                    } label: {
                        HStack {
                            Label("All Sections", systemImage: "calendar")
                                .foregroundStyle(Color.accent)
                            Spacer()
                            if selectedSections.isEmpty || selectedSections.count == MemoryService.TimelineSection.Kind.allCases.count {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accent)
                                    .fontWeight(.semibold)
                            }
                        }
                    }

                    ForEach(MemoryService.TimelineSection.Kind.allCases) { kind in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                toggleSection(kind)
                            }
                        } label: {
                            HStack {
                                Label(kind.title, systemImage: kind.systemImage)
                                    .foregroundStyle(Color.accent)
                                Spacer()
                                if isSectionVisuallySelected(kind) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Timeline Section")
                }

                Section {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showInbox.toggle()
                        }
                    } label: {
                        HStack {
                            Label("Show Inbox", systemImage: "tray.fill")
                                .foregroundStyle(Color.accent)
                            Spacer()
                            if showInbox {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accent)
                                    .fontWeight(.semibold)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                } header: {
                    Text("Inbox")
                }
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .scrollDisabled(detentSelection == .medium)
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMemoryTypes.removeAll()
                            selectedSections.removeAll()
                            showInbox = true
                        }
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMemoryTypes.removeAll()
                            selectedSections.removeAll()
                            showInbox = true
                        }
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm){
                        dismiss()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                    }
                }
            }
        }
    }

    private func isMemoryTypeVisuallySelected(_ type: MemoryType) -> Bool {
        if selectedMemoryTypes.isEmpty {
            return true
        }
        return selectedMemoryTypes.contains(type)
    }

    private func toggleMemoryType(_ type: MemoryType) {
        if selectedMemoryTypes.contains(type) {
            selectedMemoryTypes.remove(type)
        } else {
            selectedMemoryTypes.insert(type)
        }
    }

    private func isSectionVisuallySelected(_ kind: MemoryService.TimelineSection.Kind) -> Bool {
        if selectedSections.isEmpty {
            return true
        }
        return selectedSections.contains(kind)
    }

    private func toggleSection(_ kind: MemoryService.TimelineSection.Kind) {
        if selectedSections.contains(kind) {
            selectedSections.remove(kind)
        } else {
            selectedSections.insert(kind)
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MemoryTimelineView(
        memoryService: environment.memoryService,
        onSelectMemory: { _ in }
    )
    .environmentObject(environment)
}
