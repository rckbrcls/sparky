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
    let onToggleSelection: (Memory) -> Void
    let onToggleExpanded: () -> Void
    let creationTarget: CalendarQuickMemoryTarget
    let creationBehavior: CalendarMemoryCreationBehavior

    private var entries: [CalendarPeriodEntry] {
        CalendarPeriodEntries.make(from: occurrences)
    }

    var body: some View {
        Section {
            CalendarPeriodHeaderButton(
                period: period,
                count: entries.count,
                isExpanded: isExpanded,
                onToggle: onToggleExpanded
            )
            #if os(macOS)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.init(top: 16, leading: 20, bottom: 4, trailing: 20))
            #else
            .listRowInsets(.init(top: 16, leading: 20, bottom: 4, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            #endif

            if isExpanded {
                if entries.isEmpty && !isMultiSelecting {
                    CalendarEmptyPeriodButton(
                        period: period,
                        target: creationTarget,
                        creationBehavior: creationBehavior
                    )
                    #if os(macOS)
                    .padding(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                    #else
                    .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    #endif
                }

                ForEach(entries) { entry in
                    periodEntry(entry)
                    #if os(macOS)
                    .padding(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                    #else
                    .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    #endif
                }
            }
        }
    }

    @ViewBuilder
    private func periodEntry(_ entry: CalendarPeriodEntry) -> some View {
        switch entry {
        case .single(let occurrence):
            MemoryListItemButton(
                memory: occurrence.memory,
                isMultiSelecting: isMultiSelecting,
                isSelected: selectedMemoryIDs.contains(occurrence.memory.id),
                isDisabled: isPerformingBulkAction,
                onSelect: onSelectMemory,
                onToggleSelection: onToggleSelection,
                displayDate: date,
                occurrenceDate: occurrence.occurrenceDate
            )
        case .series(let series):
            MemoryListItemButton(
                memory: series.memory,
                isMultiSelecting: isMultiSelecting,
                isSelected: selectedMemoryIDs.contains(series.memory.id),
                isDisabled: isPerformingBulkAction,
                onSelect: onSelectMemory,
                onToggleSelection: onToggleSelection,
                displayDate: date,
                occurrenceDate: series.rangeStart,
                occurrenceRangeEnd: series.rangeEnd
            )
        }
    }
}
