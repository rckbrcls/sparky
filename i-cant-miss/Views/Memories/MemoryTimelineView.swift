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

    @State private var showingFilterSheet = false
    @State private var searchText = ""
    @State private var selectedMemoryType: MemoryType?
    @State private var selectedSection: MemoryService.TimelineSection.Kind?
    @State private var showInbox = true

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    private var filteredMemories: [MemoryModel] {
        isSearching ? memoryService.searchMemories(query: searchText) : []
    }

    private var activeFilterCount: Int {
        var count = 0
        if selectedMemoryType != nil {
            count += 1
        }
        if selectedSection != nil {
            count += 1
        }
        if !showInbox {
            count += 1
        }
        return count
    }

    private var filterDescription: String {
        var parts: [String] = []

        if let type = selectedMemoryType {
            parts.append(type.label)
        }

        if let section = selectedSection {
            parts.append(section.title)
        }

        if !showInbox {
            parts.append("No Inbox")
        }

        return parts.isEmpty ? "All" : parts.joined(separator: " • ")
    }

    var body: some View {
        NavigationStack {
            ScrollView{
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
            .navigationTitle("Timeline")
            .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search memories")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button {
                        showingFilterSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            Text(filterDescription)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(activeFilterCount > 0 ? Color.accent : .primary)
                    }
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheetView(
                    selectedMemoryType: $selectedMemoryType,
                    selectedSection: $selectedSection,
                    showInbox: $showInbox
                )
            }
            .refreshable {
                await memoryService.refresh(force: true)
            }
        }
    }

    private var searchResultsSection: some View {
        Section {
            if filteredMemories.isEmpty {
                Label("No results found", systemImage: "magnifyingglass")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredMemories) { memory in
                    Button {
                        onSelectMemory(memory)
                    } label: {
                        MemoryCardView(memory: memory)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Divider()
                .padding(.top, 16)
        }
    }

    private var timelineSections: some View {
        let sections = memoryService.timelineSections()
            .filter { section in
                if let selected = selectedSection {
                    return section.kind == selected
                }
                return true
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

        return Group {
            if sections.isEmpty {
                Section("Upcoming") {
                    Label("No memories with active triggers", systemImage: "tray")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.memories) { memory in
                            Button {
                                onSelectMemory(memory)
                            } label: {
                                MemoryCardView(memory: memory)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Label(section.kind.title, systemImage: section.kind.systemImage)
                            .padding(.top, 16)
                        Divider()
                    }

                }
            }
        }
    }

    private var inboxSection: some View {
        Section  {
            let memories = memoryService.inboxMemories()
                .filter { isMemoryTypeSelected($0) }
            if memories.isEmpty {
                Label("All caught up", systemImage: "checkmark.seal")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(memories, id: \.self) { memory in
                    Button {
                        onSelectMemory(memory)
                    } label: {
                        MemoryCardView(memory: memory)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        header: {
            Label("Inbox", systemImage: "tray.fill")
                .padding(.top, 16)
            Divider()
        }
    }

    private func isMemoryTypeSelected(_ memory: MemoryModel) -> Bool {
        guard let selectedType = selectedMemoryType else { return true }
        guard let origin = memory.metadata.origin else { return true }

        switch origin {
        case .reminder:
            return selectedType == .reminder
        case .note:
            return selectedType == .note
        case .todoList:
            return selectedType == .todo
        }
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

    @Binding var selectedMemoryType: MemoryType?
    @Binding var selectedSection: MemoryService.TimelineSection.Kind?
    @Binding var showInbox: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedMemoryType = nil
                    } label: {
                        HStack {
                            Label("All Types", systemImage: "square.stack.3d.up.fill")
                                .foregroundStyle(Color.accent)
                            Spacer()
                            if selectedMemoryType == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accent)
                                    .fontWeight(.semibold)
                            }
                        }
                    }

                    ForEach(MemoryType.allCases) { type in
                        Button {
                            selectedMemoryType = type
                        } label: {
                            HStack {
                                Label(type.label, systemImage: type.systemImage)
                                    .foregroundStyle(Color.accent)
                                Spacer()
                                if selectedMemoryType == type {
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
                        selectedSection = nil
                    } label: {
                        HStack {
                            Label("All Sections", systemImage: "calendar")
                                .foregroundStyle(Color.accent)
                            Spacer()
                            if selectedSection == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accent)
                                    .fontWeight(.semibold)
                            }
                        }
                    }

                    ForEach(MemoryService.TimelineSection.Kind.allCases) { kind in
                        Button {
                            selectedSection = kind
                        } label: {
                            HStack {
                                Label(kind.title, systemImage: kind.systemImage)
                                    .foregroundStyle(Color.accent)
                                Spacer()
                                if selectedSection == kind {
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
                        showInbox.toggle()
                    } label: {
                        HStack {
                            Label("Show Inbox", systemImage: "tray.fill")
                                .foregroundStyle(Color.accent)
                            Spacer()
                            if showInbox {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accent)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                } header: {
                    Text("Inbox")
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        selectedMemoryType = nil
                        selectedSection = nil
                        showInbox = true
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MemoryTimelineView(
        memoryService: environment.memoryService,
        onSelectMemory: { _ in }
    )
}
