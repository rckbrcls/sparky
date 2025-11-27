import SwiftUI

struct MemoryListMoreActionsSheet: View {
    let memory: MemoryModel
    let spaces: [SpaceModel]
    let canEdit: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onMoveToSpace: (UUID?) -> Void
    let onUpdateStatus: (MemoryStatus) -> Void
    let onUpdatePriority: (MemoryPriority?) -> Void

    @State private var selectedSpaceID: UUID?
    @State private var selectedStatus: MemoryStatus
    @State private var selectedPriority: MemoryPriority

    init(memory: MemoryModel,
         spaces: [SpaceModel],
         canEdit: Bool,
         onEdit: @escaping () -> Void,
         onDelete: @escaping () -> Void,
         onTogglePin: @escaping () -> Void,
         onMoveToSpace: @escaping (UUID?) -> Void,
         onUpdateStatus: @escaping (MemoryStatus) -> Void,
         onUpdatePriority: @escaping (MemoryPriority?) -> Void) {
        self.memory = memory
        self.spaces = spaces
        self.canEdit = canEdit
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onTogglePin = onTogglePin
        self.onMoveToSpace = onMoveToSpace
        self.onUpdateStatus = onUpdateStatus
        self.onUpdatePriority = onUpdatePriority

        _selectedSpaceID = State(initialValue: memory.space?.id)
        _selectedStatus = State(initialValue: memory.status)
        _selectedPriority = State(initialValue: memory.priority ?? .noPriority)
    }

    var body: some View {
        List {
            Button(action: onTogglePin) {
                Label(memory.isPinned ? "Unpin" : "Pin",
                      systemImage: memory.isPinned ? "pin.slash" : "pin")
            }

            SpacePicker(selection: $selectedSpaceID, spaces: spaces)

            Picker(selection: $selectedStatus) {
                ForEach(MemoryStatus.allCases) { status in
                    Text(status.rawValue.capitalized).tag(status)
                }
            } label: {
                Label(selectedStatus.rawValue.capitalized, systemImage: "circle.circle")
            }
            .pickerStyle(.menu)

            Picker(selection: $selectedPriority) {
                ForEach(MemoryPriority.allCases) { priority in
                    Label(priority.displayName, systemImage: priority.iconName)
                        .tag(priority)
                }
            } label: {
                Label(selectedPriority.displayName, systemImage: selectedPriority.iconName)
            }
            .pickerStyle(.menu)

            if canEdit {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
            }

            Section {
                Button(role: .destructive, action: onDelete) {
                    Label {
                        Text("Delete")
                    } icon: {
                        Image(systemName: "trash")
                            .foregroundStyle(Color.red)
                    }
                }
            }
        }
        .scrollDisabled(true)
        .frame(maxHeight: .infinity, alignment: .top)
        .onChange(of: selectedSpaceID) { _, newValue in
            onMoveToSpace(newValue)
        }
        .onChange(of: selectedStatus) { _, newValue in
            onUpdateStatus(newValue)
        }
        .onChange(of: selectedPriority) { _, newValue in
            let resolvedPriority = newValue == .noPriority ? nil : newValue
            onUpdatePriority(resolvedPriority)
        }
    }
}
