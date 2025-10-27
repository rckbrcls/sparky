//
//  SpaceDetailView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct SpaceDetailView: View {
    let space: SpaceModel

    @ObservedObject var spaceService: SpaceService
    @ObservedObject var memoryService: MemoryService

    let onCreateMemory: (SpaceModel?) -> Void
    let onSelectMemory: (MemoryModel) -> Void
    let onCreateSpace: () -> Void

    @State private var showingFilterSheet = false
    @State private var statusFilter: StatusFilter = .active

    @Namespace private var animation

    enum StatusFilter: String, CaseIterable, Identifiable {
        case active = "Active"
        case completed = "Completed"
        case archived = "Archived"
        case all = "All"

        var id: String { rawValue }
    }

    private var activeFilterCount: Int {
        switch statusFilter {
        case .all:
            return 0
        default:
            return 1
        }
    }

    private var filterDescription: String {
        statusFilter.rawValue
    }

    var body: some View {
        ScrollView{
            VStack(alignment: .leading, spacing: 16) {
                if !childSpaces.isEmpty {
                    Section("Subspaces") {
                        ForEach(childSpaces) { child in
                            NavigationLink(value: child) {
                                SpaceRowView(
                                    space: child,
                                    count: memoryCount(for: child),
                                    parentLookup: spaceService.space(id:)
                                )
                            }
                        }
                    }
                }

                Section {
                    if filteredMemories.isEmpty {
                        Label("No memories in this space", systemImage: "tray")
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
                }

            }
            .padding(.horizontal, 20)
            .padding(.bottom, 70)
        }
        .navigationTitle(space.name)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
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
                    .padding(12)
                    .glassEffect(.regular.interactive())
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    onCreateMemory(space)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create Memory")
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            SpaceFilterSheetView(selectedStatusFilter: $statusFilter)
        }
        .refreshable {
            await refresh()
        }
    }

    private var childSpaces: [SpaceModel] {
        spaceService.children(of: space)
    }

    private var filteredMemories: [MemoryModel] {
        let statuses: Set<MemoryStatus>
        let includeArchived: Bool

        switch statusFilter {
        case .active:
            statuses = [.active]
            includeArchived = false
        case .completed:
            statuses = [.completed]
            includeArchived = false
        case .archived:
            statuses = [.archived]
            includeArchived = true
        case .all:
            statuses = []
            includeArchived = true
        }

        return memoryService.memories(
            in: space,
            includeDescendants: false,
            statuses: statuses,
            includeCompleted: statusFilter != .active,
            includeArchived: includeArchived,
            sort: .updatedAtDescending
        )
    }

    private func memoryCount(for space: SpaceModel) -> Int {
        let ids = spaceService.descendantIDs(of: space)
        return memoryService.memories.filter { ids.contains($0.space.id) }.count
    }

    private func refresh() async {
        async let spaces = spaceService.refresh(force: true)
        async let memories = memoryService.refresh(force: true)
        _ = await (spaces, memories)
    }
}

struct SpaceFilterSheetView: View {
    @Environment(\.dismiss) var dismiss

    @Binding var selectedStatusFilter: SpaceDetailView.StatusFilter

    @Namespace private var selectionAnimation

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SpaceDetailView.StatusFilter.allCases) { filter in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedStatusFilter = filter
                            }
                        } label: {
                            HStack {
                                Label(filter.rawValue, systemImage: filter.systemImage)
                                    .foregroundStyle(Color.accent)
                                Spacer()
                                if selectedStatusFilter == filter {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accent)
                                        .fontWeight(.semibold)
                                        .matchedGeometryEffect(id: "statusCheck", in: selectionAnimation)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                    }
                } header: {
                    Text("Status Filter")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedStatusFilter = .active
                        }
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

extension SpaceDetailView.StatusFilter {
    var systemImage: String {
        switch self {
        case .active:
            return "checkmark.circle.fill"
        case .completed:
            return "checkmark.seal.fill"
        case .archived:
            return "archivebox.fill"
        case .all:
            return "square.stack.3d.up.fill"
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return SpacesRootView(
        spaceService: environment.spaceService,
        memoryService: environment.memoryService,
        onCreateMemory: { _ in },
        onSelectMemory: { _ in },
        onCreateSpace: {}
    )
}
