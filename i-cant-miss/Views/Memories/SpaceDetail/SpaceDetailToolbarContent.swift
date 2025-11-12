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
    let onCreateSpace: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if canCreateSubspace {
                Button(action: onCreateSpace) {
                    Image(systemName: "folder.badge.plus")
                }
                .accessibilityLabel("Add Space")
                .disabled(isMultiSelecting || isPerformingBulkAction)
            }

            MemoryFilterSummaryButton(
                activeFilterCount: activeFilterCount,
                filterDescription: filterDescription,
                isSheetPresented: isFilterSheetPresented,
                isDisabled: isMultiSelecting || isPerformingBulkAction,
                onTap: onShowFilters
            )

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
    }
}
