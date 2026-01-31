//
//  MemoryRowView.swift
//  sparky
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
    var onMoveToMind: ((UUID?) -> Void)?
    var onUpdateStatus: ((MemoryStatus) -> Void)?
    var onEdit: (() -> Void)?

    private var isContextMenuEnabled: Bool {
        onTogglePin != nil || onToggleCompletion != nil || onDelete != nil || onMoveToMind != nil || onEdit != nil
    }

    init(
        memoryID: UUID,
        memoryService: MemoryService,
        displayDate: Date? = nil,
        onTogglePin: (() -> Void)? = nil,
        onToggleCompletion: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onMoveToMind: ((UUID?) -> Void)? = nil,
        onUpdateStatus: ((MemoryStatus) -> Void)? = nil,
        onEdit: (() -> Void)? = nil
    ) {
        self.memoryID = memoryID
        self._memoryService = ObservedObject(wrappedValue: memoryService)
        self.displayDate = displayDate
        self.onTogglePin = onTogglePin
        self.onToggleCompletion = onToggleCompletion
        self.onDelete = onDelete
        self.onMoveToMind = onMoveToMind
        self.onUpdateStatus = onUpdateStatus
        self.onEdit = onEdit
    }

    private var memory: Memory? {
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


    private var statusBadge: (text: String, systemImage: String, color: Color)? {
        guard let memory = memory else { return nil }
        switch memory.status {
        case .active:
            return nil
        case .completed:
            return ("Completed", "checkmark.circle.fill", .green)
        }
    }

    private var locationTrigger: MemoryTriggerModel? {
        guard let memory = memory else { return nil }
        return memory.triggers.first(where: { $0.type == .location && $0.isActive })
    }

    private var scheduledTrigger: MemoryTriggerModel? {
        guard let memory = memory else { return nil }
        return memory.triggers.first(where: { $0.type == .scheduled && $0.isActive })
    }

    var body: some View {
        if let memory = memory {
            memoryContent(memory: memory)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func memoryContent(memory: Memory) -> some View {
        VStack(spacing: 0) {
            // DateTime trigger (if has scheduled trigger)
            if let scheduledTrigger = scheduledTrigger {
                MemoryCardDateTimeView(
                    trigger: scheduledTrigger,
                    isCompletedForDisplay: isCompletedForDisplay
                )
                .padding(6)
            }

            // Map (if has location trigger)
            if let locationTrigger = locationTrigger, let location = locationTrigger.location {
                MemoryCardLocationMapView(location: location)
                    .frame(height: 120)
                    .padding(6)
            }

            // Card content
            HStack(alignment: .center, spacing: 12) {
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
                }

                Spacer()

                Button {
                    feedbackGenerator.impactOccurred()
                    if let onToggleCompletion {
                        onToggleCompletion()
                    } else {
                        Task {
                            if let displayDate, memory.hasRecurringTriggers {
                                try? await memoryService.toggleCompletionForDate(memoryID: memoryID, date: displayDate)
                            } else {
                                try? await memoryService.toggleCompletion(memoryID: memoryID)
                            }
                        }
                    }
                } label: {
                    Image(systemName: isCompletedForDisplay ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isCompletedForDisplay ? Color.accentColor : .secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .padding(.top, 6)

            // Checklist collapsible section
            if memory.hasChecklist && !memory.checkItems.isEmpty {
                MemoryCardChecklistView(
                    checkItems: memory.checkItems.sorted { $0.sortOrder < $1.sortOrder },
                    onToggleItem: { itemID in
                        Task {
                            try? await memoryService.toggleChecklistItemCompletion(memoryID: memory.id, itemID: itemID)
                        }
                    },
                    isCompletedForDisplay: isCompletedForDisplay
                )
                .background(
                    Color.Theme.secondaryBackgroundag
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 10,
                                bottomTrailingRadius: 10,
                                topTrailingRadius: 0
                            )
                        )
                )
            }
        }
        .cardStyle()
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


                if let onMoveToMind = onMoveToMind {
                    Menu {
                        Button {
                            onMoveToMind(nil)
                        } label: {
                            Label("No Mind", systemImage: "tray")
                        }

                        ForEach(environment.mindService.minds, id: \.id) { mind in
                            Button {
                                onMoveToMind(mind.id)
                            } label: {
                                Label(mind.name, systemImage: mind.iconName ?? "brain.head.profile")
                            }
                        }
                    } label: {
                        Label("Move to Mind", systemImage: "folder")
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
    let environment = AppEnvironment(dataController: DataController.preview)
    environment.bootstrap()
    let sampleMemoryID = UUID()
    return MemoryCardView(memoryID: sampleMemoryID, memoryService: environment.memoryService)
        .environmentObject(environment)
        .padding()
}
