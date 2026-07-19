//
//  MemoryRowView.swift
//  sparky
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct MemoryCardView: View {
    let memoryID: UUID
    @ObservedObject var memoryService: MemoryService
    @EnvironmentObject private var environment: AppEnvironment

    /// Optional date context for date-aware completion display (used in CalendarDayView)
    var displayDate: Date?

    /// Optional specific occurrence date for intra-day recurring memories (e.g. hourly)
    var occurrenceDate: Date?

    // Context menu action callbacks (optional - if nil, context menu is disabled)
    var onTogglePin: (() -> Void)?
    var onToggleCompletion: (() -> Void)?
    var onDelete: (() -> Void)?
    var onMoveToMind: ((UUID?) -> Void)?
    var onUpdateStatus: ((MemoryStatus) -> Void)?
    var onEdit: (() -> Void)?

    @State private var showRecurringCompletionAlert = false

    private var isContextMenuEnabled: Bool {
        onTogglePin != nil || onToggleCompletion != nil || onDelete != nil || onMoveToMind != nil || onEdit != nil
    }

    init(
        memoryID: UUID,
        memoryService: MemoryService,
        displayDate: Date? = nil,
        occurrenceDate: Date? = nil,
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
        self.occurrenceDate = occurrenceDate
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
    /// For recurring memories, uses per-date/occurrence completion check
    private var isCompletedForDisplay: Bool {
        guard let memory = memory else { return false }
        // For intra-day recurring memories, use the exact occurrence time
        if let date = occurrenceDate, memory.hasIntraDayRecurrence {
            return memory.isCompleted(for: date)
        }
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
              let config = memory.scheduleConfig,
              let fireDate = config.fireDate else { return nil }

        if config.isAllDay {
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
            return ("Completed", "checkmark.circle.fill", .accentColor)
        }
    }

    private var mindForDisplay: Mind? {
        guard let mind = memory?.mind else { return nil }
        guard !mind.isAllMinds, !mind.isLimbo else { return nil }
        return mind
    }

    private var mindColor: Color {
        guard let hex = mindForDisplay?.colorHex, let color = Color(hex: hex) else {
            return .secondary
        }
        return color
    }

    private func accessibilityDescription(for memory: Memory) -> String {
        var parts = [title]
        if isCompletedForDisplay { parts.append("completed") }
        if let mind = mindForDisplay { parts.append("in \(mind.name)") }
        if let bodyPreview { parts.append(bodyPreview) }
        if let progress = checklistProgressText { parts.append("checklist \(progress)") }
        return parts.joined(separator: ", ")
    }

    private var locationTrigger: LocationConfig? {
        guard let memory = memory else { return nil }
        return memory.locationConfig?.isActive == true ? memory.locationConfig : nil
    }

    private var scheduledTrigger: ScheduleConfig? {
        guard let memory = memory else { return nil }
        return memory.scheduleConfig?.isActive == true ? memory.scheduleConfig : nil
    }

    private var hasFocus: Bool {
        memory?.hasFocus == true
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
                    isCompletedForDisplay: isCompletedForDisplay,
                    occurrenceDate: occurrenceDate
                )

                Divider()
            }

            // Location trigger
            if let locationConfig = locationTrigger {
                MemoryCardLocationMapView(
                    location: locationConfig,
                    isCompletedForDisplay: isCompletedForDisplay
                )

                Divider()
            }

            if hasFocus {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.caption)
                        .foregroundStyle(isCompletedForDisplay ? .secondary : .primary)
                        .frame(width: 20)
                    Text("Focus")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(isCompletedForDisplay ? .secondary : .primary)
                        .strikethrough(isCompletedForDisplay, color: .secondary)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 12)
                .padding(.trailing, 8)
                .padding(.vertical, 10)

                Divider()
            }

            // Card content
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {

                        if let mind = mindForDisplay {
                            HStack(spacing: 4) {
                                Image(systemName: mind.iconName ?? "brain.head.profile")
                                    .font(.system(size: 9))
                                Text(mind.name)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(isCompletedForDisplay ? .secondary : mindColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill((isCompletedForDisplay ? Color.secondary : mindColor).opacity(0.12))
                            )
                            .lineLimit(1)
                        }

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

                Spacer()

                Button {
                    PlatformHaptics.impactMedium()
                    if let onToggleCompletion {
                        onToggleCompletion()
                    } else {
                        Task {
                            if let occurrenceDate, memory.hasIntraDayRecurrence {
                                try? await memoryService.toggleCompletionForDate(memoryID: memoryID, date: occurrenceDate)
                            } else if let displayDate, memory.hasRecurringTriggers {
                                try? await memoryService.toggleCompletionForDate(memoryID: memoryID, date: displayDate)
                            } else if displayDate == nil && memory.hasRecurringTriggers && !memory.isCompleted {
                                showRecurringCompletionAlert = true
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

            // Checklist collapsible section
            if memory.hasChecklist && !memory.checkItems.isEmpty {
                Divider()

                MemoryCardChecklistView(
                    checkItems: memory.checkItems.sorted { $0.sortOrder < $1.sortOrder },
                    onToggleItem: { itemID in
                        Task {
                            let effectiveDate: Date? = if let occurrenceDate, memory.hasIntraDayRecurrence {
                                occurrenceDate
                            } else if let displayDate, memory.hasRecurringTriggers {
                                displayDate
                            } else {
                                nil
                            }
                            try? await memoryService.toggleChecklistItemCompletion(memoryID: memory.id, itemID: itemID, date: effectiveDate)
                        }
                    },
                    isCompletedForDisplay: isCompletedForDisplay
                )
            }
        }
        .cardStyle()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription(for: memory))
        .alert("End Recurrence?", isPresented: $showRecurringCompletionAlert) {
            Button("Complete", role: .destructive) {
                Task { try? await memoryService.toggleCompletion(memoryID: memoryID) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This memory repeats. Completing it will end the recurrence and remove future triggers.")
        }
        .contextMenu {
            if isContextMenuEnabled {
                if let onEdit = onEdit {
                    Button {
                        PlatformHaptics.impactMedium()
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
                        PlatformHaptics.impactMedium()
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
