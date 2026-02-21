
import SwiftUI

struct SynapseDropDelegate: DropDelegate {
    let destinationItem: CheckItemDraft
    let viewModel: MemoryEditorViewModel
    @Binding var draggedItem: CheckItemDraft?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        self.draggedItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem else { return }
        guard draggedItem.id != destinationItem.id else { return }

        guard let fromIndex = viewModel.checkItems.firstIndex(where: { $0.id == draggedItem.id }),
              let toIndex = viewModel.checkItems.firstIndex(where: { $0.id == destinationItem.id }) else { return }

        if fromIndex != toIndex {
            withAnimation {
                let destinationOffset = (fromIndex < toIndex) ? toIndex + 1 : toIndex
                viewModel.moveChecklistItem(from: IndexSet(integer: fromIndex), to: destinationOffset)
            }
        }
    }
}
