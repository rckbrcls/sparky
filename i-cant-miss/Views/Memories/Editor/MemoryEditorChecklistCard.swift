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
             ForEach(viewModel.checkItems) { item in
                VStack(spacing: 0) {
                    SynapseView(
                        item: binding(for: item),
                        isEditable: isEditingEnabled,
                        onToggle: { viewModel.toggleChecklistCompletion(for: item.id) },
                        onDelete: { viewModel.removeChecklistItem(itemID: item.id) },
                        focusedField: focusedDraftID
                    )
                    .contentShape(Rectangle())
                    .onDrag {
                        self.draggedSynapse = item
                        let itemProvider = NSItemProvider()
                        itemProvider.registerDataRepresentation(forTypeIdentifier: "com.icantmiss.synapse", visibility: .all) { completion in
                            if let data = item.id.uuidString.data(using: .utf8) {
                                completion(data, nil)
                            } else {
                                completion(nil, NSError(domain: "com.icantmiss.synapse", code: -1, userInfo: nil))
                            }
                            return nil
                        }
                        return itemProvider
                    }
                    .onDrop(of: ["com.icantmiss.synapse"], delegate: SynapseDropDelegate(destinationItem: item, viewModel: viewModel, draggedItem: $draggedSynapse))

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

    private func binding(for item: CheckItemDraft) -> Binding<CheckItemDraft> {
        Binding(
            get: {
                if let index = viewModel.checkItems.firstIndex(where: { $0.id == item.id }) {
                    return viewModel.checkItems[index]
                }
                return item
            },
            set: { newValue in
                if let index = viewModel.checkItems.firstIndex(where: { $0.id == item.id }) {
                    viewModel.checkItems[index] = newValue
                }
            }
        )
    }
}
