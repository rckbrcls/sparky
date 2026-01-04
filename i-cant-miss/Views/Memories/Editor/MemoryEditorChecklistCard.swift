//
//  MemoryEditorChecklistCard.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct MemoryEditorChecklistCard: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    var isEditingEnabled: Bool
    var focusedDraftID: FocusState<UUID?>.Binding

    @State private var draggedSynapse: CheckItemDraft?

    var body: some View {
        VStack(spacing: 0) {
             ForEach($viewModel.checkItems) { $item in
                VStack(spacing: 0) {
                    SynapseView(
                        item: $item,
                        isEditable: isEditingEnabled,
                        onToggle: { viewModel.toggleChecklistCompletion(for: $item.wrappedValue.id) },
                        onDelete: { viewModel.removeChecklistItem(itemID: $item.wrappedValue.id) },
                        focusedField: focusedDraftID
                    )
                    .onDrag {
                        self.draggedSynapse = $item.wrappedValue
                         return NSItemProvider(item: $item.wrappedValue.id.uuidString as NSString, typeIdentifier: "com.icantmiss.synapse")
                    }
                    .onDrop(of: ["com.icantmiss.synapse"], delegate: SynapseDropDelegate(destinationItem: $item.wrappedValue, viewModel: viewModel, draggedItem: $draggedSynapse))

                    if item.id != viewModel.checkItems.last?.id {
                         Divider()
                             .padding(.leading, 16)
                    }
                }
            }
            .onMove { source, destination in
                viewModel.moveChecklistItem(from: source, to: destination)
            }

            if isEditingEnabled {
                if !viewModel.checkItems.isEmpty {
                     Divider()
                         .padding(.leading, 16)
                }
                AddSynapseButton {
                     viewModel.addChecklistItem(title: "", detail: "")
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}
