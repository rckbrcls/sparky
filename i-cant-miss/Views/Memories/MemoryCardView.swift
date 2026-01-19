//
//  MemoryRowView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI
import UIKit
import MapKit

struct MemoryCardView: View {
    let memoryID: UUID
    @ObservedObject var memoryService: MemoryService
    @EnvironmentObject private var environment: AppEnvironment
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    /// Optional date context for date-aware completion display (used in CalendarDayView)
    var displayDate: Date?

    // Context menu action callbacks (optional - if nil, context menu is disabled)
    var onTogglePin: (() -> Void)?
    var onToggleCompletion: (() -> Void)?
    var onDelete: (() -> Void)?
    var onMoveToSpace: ((UUID?) -> Void)?
    var onUpdateStatus: ((MemoryStatus) -> Void)?
    var onEdit: (() -> Void)?

    private var isContextMenuEnabled: Bool {
        onTogglePin != nil || onToggleCompletion != nil || onDelete != nil || onMoveToSpace != nil || onEdit != nil
    }

    init(
        memoryID: UUID,
        memoryService: MemoryService,
        displayDate: Date? = nil,
        onTogglePin: (() -> Void)? = nil,
        onToggleCompletion: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onMoveToSpace: ((UUID?) -> Void)? = nil,
        onUpdateStatus: ((MemoryStatus) -> Void)? = nil,
        onEdit: (() -> Void)? = nil
    ) {
        self.memoryID = memoryID
        self._memoryService = ObservedObject(wrappedValue: memoryService)
        self.displayDate = displayDate
        self.onTogglePin = onTogglePin
        self.onToggleCompletion = onToggleCompletion
        self.onDelete = onDelete
        self.onMoveToSpace = onMoveToSpace
        self.onUpdateStatus = onUpdateStatus
        self.onEdit = onEdit
    }

    private var memory: MemoryModel? {
        memoryService.memory(id: memoryID)
    }

    /// Checks if this memory is completed for display purposes
    /// For recurring memories with a displayDate, uses per-date completion check
    private var isCompletedForDisplay: Bool {
        guard let memory = memory else { return false }
        // For recurring memories with a displayDate, use date-specific completion
        if let date = displayDate, memory.hasRecurringTriggers {
            return memory.isCompleted(for: date)
        }
        // Otherwise, use the global status
        return memory.isCompleted
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private func relativeDateString(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // Se for muito recente (menos de 1 minuto), mostra "just now"
        if let seconds = calendar.dateComponents([.second], from: date, to: now).second,
           seconds < 60 {
            return "just now"
        }
        
        // Usa o formato relativo padrão que não mostra segundos
        return Self.relativeFormatter.localizedString(for: date, relativeTo: now)
    }

    private func createdDateString(for date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private var title: String {
        guard let memory = memory else { return "Untitled" }
        let trimmed = memory.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private var bodyPreview: String? {
        guard let memory = memory,
              let body = memory.body?.trimmingCharacters(in: .whitespacesAndNewlines),
              !body.isEmpty else { return nil }
        return body
    }

    private var scheduledDateText: String? {
        guard let memory = memory,
              let trigger = memory.triggers.first(where: { $0.type == .scheduled }),
              let fireDate = trigger.fireDate else { return nil }

        // Don't show time for all-day memories
        if trigger.isAllDay {
            return nil
        }

        return fireDate.formatted(date: .omitted, time: .shortened)
    }

    private var checklistProgressText: String? {
        guard let memory = memory,
              memory.hasChecklist else { return nil }
        let total = memory.checkItems.count
        guard total > 0 else { return nil }
        let completed = memory.checkItems.filter(\.isCompleted).count
        return "\(completed)/\(total)"
    }

    private var sequentialSummary: String? {
        guard let memory = memory,
              let sequential = memory.triggers.first(where: { $0.type == .sequential })?.sequential else {
            return nil
        }
        return "Step \(sequential.stepIndex + 1)"
    }

    private var statusBadge: (text: String, systemImage: String, color: Color)? {
        guard let memory = memory else { return nil }
        switch memory.status {
        case .active:
            return nil
        case .completed:
            return ("Completed", "checkmark.circle.fill", .green)
        }
    }

    private var spaceAccent: Color {
        guard let memory = memory,
              let hex = memory.space?.colorHex,
              let color = Color(hex: hex) else {
            return .accentColor
        }
        return color
    }
    
    private var locationTrigger: MemoryTriggerModel? {
        guard let memory = memory else { return nil }
        return memory.triggers.first(where: { $0.type == .location && $0.isActive })
    }
    
    private var sequentialTrigger: MemoryTriggerModel? {
        guard let memory = memory else { return nil }
        return memory.triggers.first(where: { $0.type == .sequential && $0.isActive })
    }
    
    private var sequenceMemories: [MemoryModel] {
        guard let memory = memory,
              let sequential = sequentialTrigger?.sequential else {
            return []
        }
        let sequenceID = sequential.sequenceID
        return memoryService.memories
            .filter { mem in
                mem.triggers.contains { $0.type == .sequential && $0.sequential?.sequenceID == sequenceID }
            }
            .sorted { lhs, rhs in
                let lhsIndex = lhs.triggers.first(where: { $0.type == .sequential })?.sequential?.stepIndex ?? 0
                let rhsIndex = rhs.triggers.first(where: { $0.type == .sequential })?.sequential?.stepIndex ?? 0
                return lhsIndex < rhsIndex
            }
    }

    var body: some View {
        if let memory = memory {
            memoryContent(memory: memory)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func memoryContent(memory: MemoryModel) -> some View {
        VStack(spacing: 0) {
            // Map (if has location trigger) - prioridade sobre sequential
            if let locationTrigger = locationTrigger, let location = locationTrigger.location {
                MemoryCardLocationMapView(location: location)
                    .frame(height: 120)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 12,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 12
                        )
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 12,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 12
                        )
                        .stroke(Color("ElementBorder"), lineWidth: 2)
                    )
            } else if let sequential = sequentialTrigger?.sequential, !sequenceMemories.isEmpty {
                // Sequential trigger view (se não houver location trigger)
                MemoryCardSequentialView(
                    memories: sequenceMemories,
                    displayDate: displayDate
                )
            }
            
            // Card content
            HStack(alignment: .center, spacing: 12) {
                let spaceIcon = memory.space?.iconName ?? "square.grid.2x2.fill"
                let spaceColor = memory.space?.colorHex.flatMap { Color(hex: $0) } ?? .gray

                Image(systemName: spaceIcon)
                    .foregroundStyle(spaceColor)
                    .frame(width: 32, height: 32)
                    .glassEffect(.regular.tint(spaceColor.opacity(0.15)))

                VStack(alignment: .leading, spacing: 6) {
                    VStack (alignment: .leading, spacing: 6){
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(isCompletedForDisplay ? .secondary : .primary)
                            .strikethrough(isCompletedForDisplay, color: .secondary)
                            .lineLimit(2)


                        if let bodyPreview {
                            Text(bodyPreview)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .strikethrough(isCompletedForDisplay, color: .secondary)
                                .lineLimit(2)
                        }

                    }

                    if scheduledDateText != nil {
                        HStack(spacing: 12) {
                            if let scheduledDateText {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                    Text(scheduledDateText)
                                        .strikethrough(isCompletedForDisplay, color: .secondary)
                                }
                                .fontWeight(.medium)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundStyle(isCompletedForDisplay ? Color.secondary : Color.primary.opacity(0.7))
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                                .background(.secondary.opacity(isCompletedForDisplay ? 0.1 : 0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Text(createdDateString(for: memory.createdAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text("•")
                            .foregroundStyle(.tertiary)
                            .font(.caption2)

                        Text("Updated \(relativeDateString(for: memory.updatedAt))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 2)
                }

                Spacer()

                // Completion check circle button
                // Only show checkbox if:
                // 1. Memory has no sequence trigger, OR
                // 2. Memory is the current step in its sequence
                let shouldShowCheckbox = !memory.hasSequenceTrigger || memory.isCurrentInSequence
                if let onToggleCompletion = onToggleCompletion, shouldShowCheckbox {
                    Button {
                        feedbackGenerator.impactOccurred()
                        onToggleCompletion()
                    } label: {
                        Image(systemName: isCompletedForDisplay ? "checkmark.circle.fill" : "circle")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: (locationTrigger != nil || sequentialTrigger != nil) ? 0 : 12,
                    bottomLeadingRadius: memory.hasChecklist && !memory.checkItems.isEmpty ? 0 : 12,
                    bottomTrailingRadius: memory.hasChecklist && !memory.checkItems.isEmpty ? 0 : 12,
                    topTrailingRadius: (locationTrigger != nil || sequentialTrigger != nil) ? 0 : 12
                )
                .fill(Color("ElementBackground"))
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: (locationTrigger != nil || sequentialTrigger != nil) ? 0 : 12,
                    bottomLeadingRadius: memory.hasChecklist && !memory.checkItems.isEmpty ? 0 : 12,
                    bottomTrailingRadius: memory.hasChecklist && !memory.checkItems.isEmpty ? 0 : 12,
                    topTrailingRadius: (locationTrigger != nil || sequentialTrigger != nil) ? 0 : 12
                )
                .stroke(Color("ElementBorder"), lineWidth: 2)
            )
            
            // Checklist collapsible section
            if memory.hasChecklist && !memory.checkItems.isEmpty {
                MemoryCardChecklistView(
                    checkItems: memory.checkItems,
                    onToggleItem: { itemID in
                        Task {
                            try? await memoryService.toggleChecklistItemCompletion(memoryID: memory.id, itemID: itemID)
                        }
                    },
                    isCompletedForDisplay: isCompletedForDisplay
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("ElementBackground"))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
        )
        .contentShape(Rectangle())
        .contextMenu {
            if isContextMenuEnabled {
                if let onEdit = onEdit {
                    Button {
                        feedbackGenerator.impactOccurred()
                        onEdit()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }

                if let onTogglePin = onTogglePin {
                    Button {
                        onTogglePin()
                    } label: {
                        Label(memory.isPinned ? "Unpin" : "Pin",
                              systemImage: memory.isPinned ? "pin.slash.fill" : "pin.fill")
                    }
                }


                if let onMoveToSpace = onMoveToSpace {
                    Menu {
                        Button {
                            onMoveToSpace(nil)
                        } label: {
                            Label("No Space", systemImage: "tray")
                        }

                        ForEach(environment.spaceService.spaces.filter { 
                            $0.id != SpaceModel.allSpacesIdentifier && $0.id != SpaceModel.inboxSpacesIdentifier 
                        }, id: \.id) { space in
                            Button {
                                onMoveToSpace(space.id)
                            } label: {
                                Label(space.name, systemImage: space.iconName ?? "folder")
                            }
                        }
                    } label: {
                        Label("Move to Space", systemImage: "folder")
                    }
                }



                if let onDelete = onDelete {
                    Divider()

                    Button {
                        Task {
                            try? await memoryService.duplicateMemory(memoryID: memoryID)
                        }
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }

                    Button(role: .destructive) {
                        feedbackGenerator.impactOccurred()
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }


}
#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    let sampleMemoryID = UUID()
    return MemoryCardView(memoryID: sampleMemoryID, memoryService: environment.memoryService)
        .environmentObject(environment)
        .padding()
}
