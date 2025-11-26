//
//  CalendarDayView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct CalendarDayView: View {
    @ObservedObject var dataManager: CalendarDataManager
    @Binding var currentDate: Date
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<MemoryModel.ID>
    let isPerformingBulkAction: Bool
    let onSelectMemory: (MemoryModel) -> Void
    let onToggleSelection: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?

    private let calendar = Calendar.current

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE - d MMM yyyy"
        return formatter.string(from: currentDate)
    }

    private var memories: [MemoryModel] {
        dataManager.memoriesForDate(currentDate)
    }

    private var allDayMemories: [MemoryModel] {
        memories.filter { memory in
            guard let fireDate = memory.nextFireDate(referenceDate: currentDate) else {
                return false
            }
            let components = calendar.dateComponents([.hour, .minute], from: fireDate)
            return (components.hour ?? 0) == 0 && (components.minute ?? 0) == 0
        }
    }

    private var timedMemories: [MemoryModel] {
        memories.filter { memory in
            guard let fireDate = memory.nextFireDate(referenceDate: currentDate) else {
                return false
            }
            let components = calendar.dateComponents([.hour, .minute], from: fireDate)
            return (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Day navigation header
            dayNavigationHeader
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            // Memory list
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if memories.isEmpty {
                        MemoryEmptyStateCard(
                            systemImage: "calendar",
                            title: "No memories for this day",
                            message: "Create a memory or capture a reminder to get started."
                        )
                        .padding(.horizontal, 20)
                    } else {
                        // All day memories section
                        if !allDayMemories.isEmpty {
                            memoriesSection(title: "All Day", memories: allDayMemories)
                        }

                        // Timed memories section
                        if !timedMemories.isEmpty {
                            memoriesSection(title: "Timed Events", memories: timedMemories)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var dayNavigationHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    navigateToPreviousDay()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(dayTitle)
                    .font(.title3)
                    .fontWeight(.bold)

                if calendar.isDateInToday(currentDate) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    navigateToNextDay()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
    }

    @ViewBuilder
    private func memoriesSection(title: String, memories: [MemoryModel]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            ForEach(memories) { memory in
                MemoryListItemButton(
                    memory: memory,
                    isMultiSelecting: isMultiSelecting,
                    isSelected: selectedMemoryIDs.contains(memory.id),
                    isDisabled: isPerformingBulkAction,
                    onSelect: onSelectMemory,
                    onToggleSelection: onToggleSelection,
                    onEdit: onEditMemory
                )
                .padding(.horizontal, 20)
            }
        }
    }

    private func navigateToPreviousDay() {
        if let newDate = calendar.date(byAdding: .day, value: -1, to: currentDate) {
            currentDate = newDate
        }
    }

    private func navigateToNextDay() {
        if let newDate = calendar.date(byAdding: .day, value: 1, to: currentDate) {
            currentDate = newDate
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    let date = Date()
    let dataManager = CalendarDataManager(memoryService: environment.memoryService)

    return CalendarDayView(
        dataManager: dataManager,
        currentDate: .constant(date),
        isMultiSelecting: false,
        selectedMemoryIDs: [],
        isPerformingBulkAction: false,
        onSelectMemory: { _ in },
        onToggleSelection: { _ in },
        onEditMemory: nil
    )
    .environmentObject(environment)
}
