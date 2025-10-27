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

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    private var filteredMemories: [MemoryModel] {
        isSearching ? memoryService.searchMemories(query: searchText) : []
    }

    var body: some View {
        NavigationStack {
            ScrollView{
                VStack(alignment: .leading, spacing: 16) {
                    if isSearching {
                        searchResultsSection
                    } else {
                        timelineSections
                        inboxSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 70)
            }
            .navigationTitle("Timeline")
            .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search memories")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheetView()
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
}

struct FilterSheetView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Tipos de Trigger") {
                    Toggle("Localização", isOn: .constant(true))
                    Toggle("Tempo", isOn: .constant(true))
                    Toggle("Contato", isOn: .constant(true))
                }

                Section("Status") {
                    Toggle("Ativos", isOn: .constant(true))
                    Toggle("Inativos", isOn: .constant(true))
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Limpar") {
                        // Ação para limpar filtros
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Aplicar") {
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
