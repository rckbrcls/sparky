import SwiftUI

struct MemorySequentialTriggerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    let excludedMemoryID: UUID?
    @State private var selectedPrevious: UUID?
    @State private var selectedNext: UUID?
    @State private var searchText: String = ""

    init(viewModel: MemoryEditorViewModel,
         excludedMemoryID: UUID?) {
        self.viewModel = viewModel
        self.excludedMemoryID = excludedMemoryID
        let configuration = viewModel.sequentialTrigger?.sequential
        _selectedPrevious = State(initialValue: configuration?.previousMemoryID)
        _selectedNext = State(initialValue: configuration?.nextMemoryID)
    }

    var body: some View {
        NavigationStack {
            List {
                infoSection
                selectionSection(kind: .previous)
                selectionSection(kind: .next)

                if selectedPrevious != nil || selectedNext != nil {
                    Section {
                        Button("Remove sequential trigger", role: .destructive) {
                            viewModel.removeSequentialTrigger()
                            selectedPrevious = nil
                            selectedNext = nil
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search memories")
            .navigationTitle("Sequential Trigger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.updateSequentialTrigger(
                            previousMemoryID: selectedPrevious,
                            nextMemoryID: selectedNext
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    private var infoSection: some View {
        Section {
            Text("Choose which memory unlocks this one and which should be scheduled afterwards. When the previous memory completes, the next memory will be scheduled for the following day.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        }
    }

    private func selectionSection(kind: SelectionKind) -> some View {
        Section(kind.title) {
            selectionSummary(kind: kind)
            let sections = spaceSections(filteredBy: searchText)
            if sections.isEmpty {
                Text("No memories available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(sections) { section in
                    if !section.memories.isEmpty {
                        DisclosureGroup(section.space.name) {
                            ForEach(section.memories) { memory in
                                selectableRow(for: memory, kind: kind)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func selectionSummary(kind: SelectionKind) -> some View {
        let selectionID = kind == .previous ? selectedPrevious : selectedNext
        if let selectionID, let memory = memoryLookup[selectionID] {
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.title)
                    .font(.callout.weight(.semibold))
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(memory.space.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    statusBadge(for: memory)
                }
                Button("Clear selection") {
                    if kind == .previous {
                        selectedPrevious = nil
                    } else {
                        selectedNext = nil
                    }
                }
                .font(.footnote)
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
        } else {
            Text(kind.emptyMessage)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func selectableRow(for memory: MemoryModel, kind: SelectionKind) -> some View {
        let currentSelection = kind == .previous ? selectedPrevious : selectedNext
        let isSelected = currentSelection == memory.id
        let isDisabled: Bool = {
            switch kind {
            case .previous:
                return selectedNext == memory.id
            case .next:
                return selectedPrevious == memory.id
            }
        }()

        return Button {
            toggleSelection(for: memory.id, kind: kind)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.title)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundColor(isDisabled ? .secondary : .primary)
                    HStack(spacing: 6) {
                        Text(memory.space.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        statusBadge(for: memory)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                } else if isDisabled {
                    Image(systemName: "slash.circle")
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusBadge(for memory: MemoryModel) -> some View {
        switch memory.status {
        case .active:
            EmptyView()
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        case .archived:
            Image(systemName: "archivebox.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func toggleSelection(for id: UUID, kind: SelectionKind) {
        switch kind {
        case .previous:
            if selectedPrevious == id {
                selectedPrevious = nil
            } else {
                selectedPrevious = id
                if selectedNext == id {
                    selectedNext = nil
                }
            }
        case .next:
            if selectedNext == id {
                selectedNext = nil
            } else {
                selectedNext = id
                if selectedPrevious == id {
                    selectedPrevious = nil
                }
            }
        }
    }

    private func spaceSections(filteredBy query: String) -> [SpaceSection] {
        let candidates = filteredCandidates(query: query)
        let grouped = Dictionary(grouping: candidates, by: \.space)
        return grouped
            .map { SpaceSection(space: $0.key, memories: $0.value.sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })) }
            .sorted { $0.space.name.localizedCaseInsensitiveCompare($1.space.name) == .orderedAscending }
    }

    private func filteredCandidates(query: String) -> [MemoryModel] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return allCandidates }
        return allCandidates.filter { memory in
            memory.title.localizedCaseInsensitiveContains(trimmed) ||
            memory.space.name.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var allCandidates: [MemoryModel] {
        viewModel.environment.memoryService.memories.filter { memory in
            guard matchesOrigin(memory: memory) else { return false }
            if let excludedMemoryID, memory.id == excludedMemoryID {
                return false
            }
            return true
        }
    }

    private var memoryLookup: [UUID: MemoryModel] {
        Dictionary(uniqueKeysWithValues: viewModel.environment.memoryService.memories.map { ($0.id, $0) })
    }

    private func matchesOrigin(memory: MemoryModel) -> Bool {
        guard let origin = memory.metadata.origin else { return false }
        switch origin {
        case .reminder:
            return true
        case .note, .todoList:
            return false
        }
    }

    private enum SelectionKind {
        case previous
        case next

        var title: String {
            switch self {
            case .previous: return "Previous memory"
            case .next: return "Next memory"
            }
        }

        var emptyMessage: String {
            switch self {
            case .previous: return "No previous memory selected."
            case .next: return "No next memory selected."
            }
        }
    }

    private struct SpaceSection: Identifiable {
        let space: SpaceModel
        let memories: [MemoryModel]

        var id: UUID { space.id }
    }
}
