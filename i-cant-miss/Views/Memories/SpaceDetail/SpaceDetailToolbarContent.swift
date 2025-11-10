import SwiftUI

struct SpaceDetailToolbarContent: ToolbarContent {
    let activeFilterCount: Int
    let filterDescription: String
    let isFilterSheetPresented: Bool
    let isMultiSelecting: Bool
    let isPerformingBulkAction: Bool
    let hasSelectedMemories: Bool
    let canCreateSubspace: Bool
    let onShowFilters: () -> Void
    let onToggleMultiSelection: () -> Void
    let onRequestDeletion: () -> Void
    let onCreateMemory: () -> Void
    let onCreateSpace: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            MemoryFilterSummaryButton(
                activeFilterCount: activeFilterCount,
                filterDescription: filterDescription,
                isSheetPresented: isFilterSheetPresented,
                isDisabled: isMultiSelecting || isPerformingBulkAction,
                onTap: onShowFilters
            )
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if isMultiSelecting {
                Button(role: .destructive, action: onRequestDeletion) {
                    Image(systemName: "trash")
                }
                .disabled(!hasSelectedMemories || isPerformingBulkAction)
                .accessibilityLabel("Delete selected memories")
            }

            Button(action: onToggleMultiSelection) {
                if isMultiSelecting {
                    Text("Done")
                        .fontWeight(.semibold)
                } else {
                    Label("Select", systemImage: "checkmark.circle")
                }
            }
            .disabled(isPerformingBulkAction)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button(action: onCreateMemory) {
                    Label("Add Memory", systemImage: "plus")
                }

                if canCreateSubspace {
                    Button(action: onCreateSpace) {
                        Label("Add Space", systemImage: "folder.badge.plus")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("Add Item")
            .disabled(isMultiSelecting || isPerformingBulkAction)
        }
    }
}
