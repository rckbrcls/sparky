//
//  CalendarPeriodSection.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct CalendarPeriodSection: View {
    let period: CalendarTimePeriod
    let memories: [MemoryModel]
    let date: Date
    let isExpanded: Bool
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<MemoryModel.ID>
    let isPerformingBulkAction: Bool
    let onSelectMemory: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?
    let onToggleSelection: (MemoryModel) -> Void
    let onToggleExpanded: () -> Void

    var body: some View {
        Section {
            CalendarPeriodHeaderButton(
                period: period,
                count: memories.count,
                isExpanded: isExpanded,
                onToggle: onToggleExpanded
            )
            .listRowInsets(.init(top: 16, leading: 20, bottom: 4, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if isExpanded {
                ForEach(memories) { memory in
                    MemoryListItemButton(
                        memory: memory,
                        isMultiSelecting: isMultiSelecting,
                        isSelected: selectedMemoryIDs.contains(memory.id),
                        isDisabled: isPerformingBulkAction,
                        onSelect: onSelectMemory,
                        onToggleSelection: onToggleSelection,
                        onEditMemory: onEditMemory,
                        displayDate: date
                    )
                    .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }
}
