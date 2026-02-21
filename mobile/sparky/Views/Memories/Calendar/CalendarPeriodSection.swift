//
//  CalendarPeriodSection.swift
//  sparky
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct CalendarPeriodSection: View {
    let period: CalendarTimePeriod
    let occurrences: [MemoryOccurrence]
    let date: Date
    let isExpanded: Bool
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<Memory.ID>
    let isPerformingBulkAction: Bool
    let onSelectMemory: (Memory) -> Void
    let onEditMemory: ((Memory) -> Void)?
    let onToggleSelection: (Memory) -> Void
    let onToggleExpanded: () -> Void

    var body: some View {
        Section {
            CalendarPeriodHeaderButton(
                period: period,
                count: occurrences.count,
                isExpanded: isExpanded,
                onToggle: onToggleExpanded
            )
            .listRowInsets(.init(top: 16, leading: 20, bottom: 4, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if isExpanded {
                ForEach(occurrences) { occurrence in
                    MemoryListItemButton(
                        memory: occurrence.memory,
                        isMultiSelecting: isMultiSelecting,
                        isSelected: selectedMemoryIDs.contains(occurrence.memory.id),
                        isDisabled: isPerformingBulkAction,
                        onSelect: onSelectMemory,
                        onToggleSelection: onToggleSelection,
                        onEditMemory: onEditMemory,
                        displayDate: date,
                        occurrenceDate: occurrence.occurrenceDate
                    )
                    .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }
}
