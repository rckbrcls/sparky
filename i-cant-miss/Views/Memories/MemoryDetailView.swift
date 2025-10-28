//
//  MemoryDetailView.swift
//  i-cant-miss
//
//  Created by Codex on 19/01/25.
//

import SwiftUI
import UIKit

struct MemoryDetailView: View {
    let memory: MemoryModel
    let onClose: () -> Void
    let onEdit: (MemoryModel) -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .short
        return formatter
    }()

    private var title: String {
        if let trimmed = memory.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trimmed.isEmpty {
            return trimmed
        }
        return "Untitled"
    }

    private var bodyText: String? {
        guard let trimmed = memory.body?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private var dueDateText: String? {
        guard let dueDate = memory.dueDate else { return nil }
        return Self.dateFormatter.string(from: dueDate)
    }

    private var nextTriggerText: String? {
        guard let fireDate = memory.nextFireDate() else { return nil }
        return Self.relativeFormatter.localizedString(for: fireDate, relativeTo: Date())
    }

    private var checklistProgressText: String? {
        guard memory.hasChecklist else { return nil }
        let total = memory.checkItems.count
        let completed = memory.checkItems.filter(\.isCompleted).count
        return "\(completed) of \(total) completed"
    }

    private var activeTriggers: [MemoryTriggerModel] {
        memory.triggers.filter(\.isActive)
    }

    private var heroChips: [HeroChip] {
        var chips: [HeroChip] = []
//        if let dueDateText {
//            chips.append(HeroChip(icon: "calendar.badge.clock", label: dueDateText))
//        }
//        if let nextTriggerText {
//            chips.append(HeroChip(icon: "alarm", label: "Next \(nextTriggerText)"))
//        }
//        if let checklistProgressText {
//            chips.append(HeroChip(icon: "checklist", label: checklistProgressText))
//        }
        if let priority = memory.priority {
            chips.append(
                HeroChip(
                    icon: priority.iconName,
                    label: priorityLabel(for: priority),
                    tint: priorityColor(for: priority)
                )
            )
        }
        if memory.isPinned {
            chips.append(HeroChip(icon: "pin.fill", label: "Pinned"))
        }
        return chips
    }

    private var backgroundGradient: LinearGradient {
        let accent = spaceAccent
        return LinearGradient(
            colors: [
                accent.opacity(0.15),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var spaceAccent: Color {
        if let hex = memory.space.colorHex,
           let color = Color(hex: hex) {
            return color
        }
        return .accentColor
    }

    private var statusBadge: some View {
        let config: (text: String, icon: String, color: Color)
        switch memory.status {
        case .active:
            config = ("Active", "dot.radiowaves.left.and.right", .blue)
        case .completed:
            config = ("Completed", "checkmark.circle.fill", .green)
        case .archived:
            config = ("Archived", "archivebox.fill", .gray)
        }

        return Label(config.text, systemImage: config.icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(config.color.opacity(0.15), in: Capsule())
            .foregroundStyle(config.color)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroSection
                    if memory.hasAttachments {
                        detailSection(title: "Photos", systemImage: "photo.stack") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    ForEach(memory.attachments) { attachment in
                                        if let image = UIImage(data: attachment.data) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 160, height: 160)
                                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(.thinMaterial, lineWidth: 1)
                                                )
                                        } else {
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(.secondary.opacity(0.1))
                                                .frame(width: 160, height: 160)
                                                .overlay(
                                                    Image(systemName: "photo.fill")
                                                        .font(.system(size: 28))
                                                        .foregroundStyle(.secondary)
                                                )
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    if memory.hasChecklist {
                        detailSection(title: "Checklist", systemImage: "checklist") {
                            VStack(spacing: 12) {
                                ForEach(memory.checkItems) { item in
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(item.isCompleted ? .green : .secondary)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.title)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(.primary)
                                            if let detail = item.detail, !detail.isEmpty {
                                                Text(detail)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    if !activeTriggers.isEmpty {
                        detailSection(title: "Triggers", systemImage: "alarm.fill") {
                            VStack(spacing: 12) {
                                ForEach(activeTriggers) { trigger in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: trigger.type.systemImage)
                                            .foregroundStyle(spaceAccent)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(triggerTitle(for: trigger))
                                                .font(.body.weight(.medium))
                                            Text(triggerDescription(for: trigger))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    
                    detailSection(title: "Details", systemImage: "info.circle.fill") {
                        VStack(spacing: 12) {
                            detailRow(icon: "tray.fill", title: "Space", value: memory.space.name)
                            detailRow(icon: "flag.fill", title: "Status", value: statusText(for: memory.status))
                            if let priority = memory.priority {
                                detailRow(
                                    icon: priority.iconName,
                                    title: "Priority",
                                    value: priorityLabel(for: priority)
                                )
                            }
                            if let dueDateText {
                                detailRow(icon: "calendar.badge.clock", title: "Due date", value: dueDateText)
                            }
                            if let nextTriggerText {
                                detailRow(icon: "alarm", title: "Next trigger", value: nextTriggerText)
                            }
                        }
                    }

                    detailSection(title: "History", systemImage: "clock.arrow.circlepath") {
                        VStack(spacing: 12) {
                            detailRow(
                                icon: "calendar.badge.plus",
                                title: "Created",
                                value: Self.dateFormatter.string(from: memory.createdAt)
                            )
                            detailRow(
                                icon: "calendar.badge.exclamationmark",
                                title: "Updated",
                                value: Self.dateFormatter.string(from: memory.updatedAt)
                            )
                            if let lastCompletionDate = memory.lastCompletionDate {
                                detailRow(
                                    icon: "checkmark.seal.fill",
                                    title: "Last completion",
                                    value: Self.dateFormatter.string(from: lastCompletionDate)
                                )
                            }
                            if memory.snoozeCount > 0 {
                                detailRow(
                                    icon: "zzz",
                                    title: "Snoozed",
                                    value: "\(memory.snoozeCount) times"
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(backgroundGradient.ignoresSafeArea())
            .navigationTitle("Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .close) {
                        onClose()
                    }
                    label: {
                        Label("Close", systemImage: "xmark")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onEdit(memory)
                    }label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .accessibilityLabel("Edit memory")
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(spaceAccent)
                        .frame(width: 10, height: 10)
                    if let icon = memory.space.iconName {
                        Image(systemName: icon)
                            .foregroundStyle(spaceAccent)
                    }
                    Text(memory.space.name)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if let bodyText {
                    Text(bodyText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
            }

            if !heroChips.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(heroChips) { chip in
                        InfoChip(icon: chip.icon, text: chip.label, tint: chip.tint)
                    }
                }
            }
        }
        .padding(24)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    @ViewBuilder
    private func detailSection(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.secondary)
            content()
        }
        .padding(20)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
    }

    private func statusText(for status: MemoryStatus) -> String {
        switch status {
        case .active: return "Active"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }

    private func priorityLabel(for priority: MemoryPriority) -> String {
        switch priority {
        case .low: return "Low priority"
        case .medium: return "Medium priority"
        case .high: return "High priority"
        }
    }

    private func priorityColor(for priority: MemoryPriority) -> Color {
        switch priority {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }

    private func triggerTitle(for trigger: MemoryTriggerModel) -> String {
        switch trigger.type {
        case .time:
            return "Time reminder"
        case .dayOfWeek:
            return "Weekday reminder"
        case .location:
            return trigger.location?.name ?? "Location reminder"
        case .person:
            return trigger.person?.name ?? "Person reminder"
        }
    }

    private func triggerDescription(for trigger: MemoryTriggerModel) -> String {
        switch trigger.type {
        case .time:
            if let fireDate = trigger.fireDate {
                return Self.dateFormatter.string(from: fireDate)
            }
            return "One-time trigger"
        case .dayOfWeek:
            var parts: [String] = []
            let summary = weekdayMaskSummary(mask: trigger.weekdayMask)
            if summary != "No days selected" {
                parts.append(summary)
            }
            if let fireDate = trigger.fireDate {
                parts.append(Self.timeFormatter.string(from: fireDate))
            }
            return parts.isEmpty ? "Repeats on selected days" : parts.joined(separator: " • ")
        case .location:
            guard let location = trigger.location else {
                return "Location based"
            }
            var parts: [String] = []
            parts.append(location.event.label)
            if let name = location.name {
                parts.append(name)
            }
            return parts.joined(separator: " • ")
        case .person:
            if let person = trigger.person {
                return "When interacting with \(person.name)"
            }
            return "Person-based trigger"
        }
    }
}

private struct HeroChip: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    var tint: Color = .secondary
}

private struct InfoChip: View {
    let icon: String
    let text: String
    var tint: Color

    init(icon: String, text: String, tint: Color = .secondary) {
        self.icon = icon
        self.text = text
        self.tint = tint
    }

    var body: some View {
        Label {
            Text(text)
                .font(.subheadline.weight(.semibold))
        } icon: {
            Image(systemName: icon)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

private func weekdayMaskSummary(mask: Int16) -> String {
    guard mask != 0 else { return "No days selected" }
    let formatter = DateFormatter()
    let symbols = formatter.shortWeekdaySymbols ?? []
    guard !symbols.isEmpty else { return "No days selected" }
    let days = (1...7).compactMap { day -> String? in
        let bit = Int16(1 << day)
        guard mask & bit != 0 else { return nil }
        return symbols[(day - 1) % symbols.count]
    }
    return days.isEmpty ? "No days selected" : days.joined(separator: ", ")
}

#Preview {
    let calendar = Calendar.current
    let now = Date()

    let dueDate = calendar.date(byAdding: .day, value: 2, to: now)
    let dailyFireDate = calendar.date(bySettingHour: 7, minute: 30, second: 0, of: now)
    let weekdayFireDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now)
    let weekdayStartDate = calendar.startOfDay(for: now)

    let weekdayMask: Int16 = [2, 4, 6].reduce(0) { partialResult, weekday in
        partialResult | Int16(1 << (weekday - 1))
    }

    let timeTrigger = MemoryTriggerModel(
        id: UUID(),
        type: .time,
        fireDate: dailyFireDate,
        startDate: now,
        recurrenceRule: RecurrenceRule(frequency: .daily, interval: 1),
        timeZoneIdentifier: TimeZone.current.identifier,
        weekdayMask: 0,
        isActive: true,
        location: nil,
        person: nil,
        spacedStage: 1,
        lastReviewDate: calendar.date(byAdding: .day, value: -3, to: now),
        ignoreCount: 0
    )

    let weekdayTrigger = MemoryTriggerModel(
        id: UUID(),
        type: .dayOfWeek,
        fireDate: weekdayFireDate,
        startDate: weekdayStartDate,
        recurrenceRule: RecurrenceRule(frequency: .weekly, interval: 1),
        timeZoneIdentifier: TimeZone.current.identifier,
        weekdayMask: weekdayMask,
        isActive: true,
        location: nil,
        person: nil,
        spacedStage: 2,
        lastReviewDate: calendar.date(byAdding: .day, value: -10, to: now),
        ignoreCount: 1
    )

    let locationTrigger = MemoryTriggerModel(
        id: UUID(),
        type: .location,
        fireDate: nil,
        startDate: nil,
        recurrenceRule: nil,
        timeZoneIdentifier: nil,
        weekdayMask: 0,
        isActive: true,
        location: .init(
            latitude: -23.561707,
            longitude: -46.655981,
            radius: 150,
            name: "Academia do Parque",
            event: .onEntry
        ),
        person: nil,
        spacedStage: 0,
        lastReviewDate: nil,
        ignoreCount: 0
    )

    let personTrigger = MemoryTriggerModel(
        id: UUID(),
        type: .person,
        fireDate: nil,
        startDate: nil,
        recurrenceRule: nil,
        timeZoneIdentifier: nil,
        weekdayMask: 0,
        isActive: true,
        location: nil,
        person: .init(name: "Coach Taylor", contactIdentifier: "contact-coach"),
        spacedStage: 0,
        lastReviewDate: calendar.date(byAdding: .day, value: -14, to: now),
        ignoreCount: 2
    )

    let checkItems = [
        CheckItemModel(
            id: UUID(),
            title: "Separar garrafa de água",
            detail: "Checar se está cheia antes de sair",
            isCompleted: true,
            sortOrder: 0,
            createdAt: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
            updatedAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
            completedAt: calendar.date(byAdding: .day, value: -1, to: now)
        ),
        CheckItemModel(
            id: UUID(),
            title: "Preparar playlist motivacional",
            detail: "Adicionar faixas novas na sexta",
            isCompleted: false,
            sortOrder: 1,
            createdAt: calendar.date(byAdding: .day, value: -4, to: now) ?? now,
            updatedAt: now,
            completedAt: nil
        )
    ]

    let space = SpaceModel(
        id: UUID(),
        name: "Bem-estar",
        colorHex: "#34D399",
        iconName: "heart.fill",
        sortOrder: 1,
        parentID: nil,
        childIDs: [],
        isDefault: false,
        legacyFolder: FolderModel(
            id: UUID(),
            name: "Saúde",
            colorHex: "#059669",
            iconName: "cross.case.fill",
            audience: .reminders,
            isDefault: false,
            sortOrder: 0
        )
    )

    let metadata = MemoryModel.Metadata(
        origin: .reminder(UUID()),
        legacyStatus: .completed,
        legacyAudience: .reminders,
        autoCompleteOnChecklistCompletion: true
    )

    let memory = MemoryModel(
        id: UUID(),
        title: "Morning workout",
        body: "Short run + stretching routine.\nDon't forget water.",
        createdAt: calendar.date(byAdding: .day, value: -7, to: now) ?? now,
        updatedAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
        status: .active,
        isPinned: true,
        priority: .high,
        dueDate: dueDate,
        space: space,
        triggers: [timeTrigger, weekdayTrigger, locationTrigger, personTrigger],
        checkItems: checkItems,
        snoozeCount: 3,
        lastCompletionDate: calendar.date(byAdding: .day, value: -2, to: now),
        metadata: metadata,
        attachments: []
    )
    return MemoryDetailView(memory: memory, onClose: {}, onEdit: { _ in })
}
