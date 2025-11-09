import SwiftUI

struct MemoryEditorTriggerButtonsBar: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showTriggerPicker: Bool
    @Binding var showDueDateSheet: Bool
    @Binding var showExactTimeSheet: Bool
    @Binding var showWeekdaySheet: Bool
    @Binding var showLocationPicker: Bool
    @Binding var showPersonSheet: Bool
    @Binding var showSequentialSheet: Bool
    let memoryLookup: [UUID: MemoryModel]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                MemoryTriggerAddBadge(isPresented: $showTriggerPicker)
                MemoryDueDateTriggerInlineForm(
                    viewModel: viewModel,
                    showSheet: $showDueDateSheet
                )
                MemoryExactTimeTriggerInlineForm(
                    viewModel: viewModel,
                    showSheet: $showExactTimeSheet
                )
                MemoryWeekdayTriggerInlineForm(
                    viewModel: viewModel,
                    showSheet: $showWeekdaySheet
                )
                if hasLocationTrigger {
                    MemoryLocationTriggerInlineForm(
                        viewModel: viewModel,
                        showLocationPicker: $showLocationPicker
                    )
                }
                if hasPersonTrigger {
                    MemoryPersonTriggerInlineForm(
                        viewModel: viewModel,
                        showSheet: $showPersonSheet
                    )
                }
                if hasSequentialTrigger {
                    MemorySequentialTriggerInlineForm(
                        viewModel: viewModel,
                        showSheet: $showSequentialSheet,
                        memoryLookup: memoryLookup
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var hasLocationTrigger: Bool {
        viewModel.triggers.contains(where: { $0.type == .location })
    }

    private var hasPersonTrigger: Bool {
        viewModel.triggers.contains(where: { $0.type == .person })
    }

    private var hasSequentialTrigger: Bool {
        guard let configuration = viewModel.sequentialTrigger?.sequential else { return false }
        return configuration.previousMemoryID != nil || configuration.nextMemoryID != nil
    }
}

struct MemoryTriggerAddBadge: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack {
                Label("Add Trigger", systemImage: "plus")
                    .font(.caption.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.accent)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.glass)
    }
}

struct MemoryDueDateTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showSheet: Bool

    var body: some View {
        Group {
            if viewModel.dueDateEnabled {
                configuredButton
                    .swipeActions {
                        Button(role: .destructive) {
                            viewModel.dueDateEnabled = false
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            } else {
                addButton
            }
        }
    }

    private var configuredButton: some View {
        Button {
            showSheet = true
        } label: {
            HStack {
                Label("Due: " + viewModel.dueDate.formatted(date: .abbreviated, time: .shortened),
                      systemImage: "calendar")
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.glass)
    }

    private var addButton: some View {
        Button {
            showSheet = true
        } label: {
            Label("Add due date", systemImage: "calendar.badge.plus")
                .foregroundStyle(.accent)
                .font(.caption.bold())
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.glass)
    }
}

struct MemoryExactTimeTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showSheet: Bool

    private var trigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .time })
    }

    var body: some View {
        Group {
            if let trigger, let fireDate = trigger.fireDate {
                configuredButton(for: trigger, fireDate: fireDate)
                    .swipeActions {
                        Button(role: .destructive) {
                            viewModel.setTimeTrigger(fireDate: nil, recurrence: nil)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            } else {
                addButton
            }
        }
    }

    private func configuredButton(for trigger: MemoryTriggerDraft, fireDate: Date) -> some View {
        Button {
            showSheet = true
        } label: {
            HStack {
                Label(timeSummary(for: trigger, fireDate: fireDate),
                      systemImage: "clock.badge")
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.glass)
    }

    private var addButton: some View {
        Button {
            showSheet = true
        } label: {
            Label("Add exact time", systemImage: "clock.badge.plus")
                .foregroundStyle(.accent)
                .font(.caption.bold())
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.glass)
    }

    private func timeSummary(for trigger: MemoryTriggerDraft, fireDate: Date) -> String {
        if let recurrence = trigger.recurrenceRule {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .medium
            let dateText = formatter.string(from: fireDate)
            let recurrenceText = recurrenceSummary(recurrence)
            return "\(dateText) · \(recurrenceText)"
        }
        return fireDate.formatted(date: .abbreviated, time: .shortened)
    }

    private func recurrenceSummary(_ recurrence: RecurrenceRule) -> String {
        switch recurrence.frequency {
        case .daily:
            return recurrence.interval == 1 ? "Daily" : "Every \(recurrence.interval) days"
        case .weekly:
            return recurrence.interval == 1 ? "Weekly" : "Every \(recurrence.interval) weeks"
        case .monthly:
            return recurrence.interval == 1 ? "Monthly" : "Every \(recurrence.interval) months"
        case .yearly:
            return recurrence.interval == 1 ? "Yearly" : "Every \(recurrence.interval) years"
        }
    }
}

struct MemoryWeekdayTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showSheet: Bool

    private var trigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .dayOfWeek })
    }

    var body: some View {
        Group {
            if let trigger {
                configuredButton(for: trigger)
                    .swipeActions {
                        Button(role: .destructive) {
                            viewModel.setWeekdayTrigger(
                                weekdaySelection: [],
                                referenceTime: trigger.fireDate ?? Date()
                            )
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            } else {
                addButton
            }
        }
    }

    private func configuredButton(for trigger: MemoryTriggerDraft) -> some View {
        Button {
            showSheet = true
        } label: {
            HStack {
                Label(weekdaySummary(for: trigger),
                      systemImage: "calendar")
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.glass)
    }

    private var addButton: some View {
        Button {
            showSheet = true
        } label: {
            Label("Add weekday routine", systemImage: "calendar.badge.clock")
                .foregroundStyle(.accent)
                .font(.caption.bold())
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.glass)
    }

    private func weekdaySummary(for trigger: MemoryTriggerDraft) -> String {
        if trigger.weekdayMask == 0 {
            return "No weekdays selected"
        }
        var summary = weekdayMaskSummary(mask: trigger.weekdayMask)
        if let fireDate = trigger.fireDate {
            summary += " · " + fireDate.formatted(date: .omitted, time: .shortened)
        }
        return summary
    }
}

struct MemoryLocationTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showLocationPicker: Bool

    private var trigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .location })
    }

    var body: some View {
        if let trigger, let location = trigger.location {
            Button {
                showLocationPicker = true
            } label: {
                HStack {
                    Label(location.name ?? "Location", systemImage: "mappin.circle.fill")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
            .swipeActions {
                Button(role: .destructive) {
                    viewModel.removeTrigger(id: trigger.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            Button {
                showLocationPicker = true
            } label: {
                Label("Location", systemImage: "mappin.circle.fill")
                    .foregroundStyle(.accent)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
        }
    }
}

struct MemoryPersonTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showSheet: Bool

    private var trigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .person })
    }

    var body: some View {
        if let trigger, let person = trigger.person {
            Button {
                showSheet = true
            } label: {
                HStack {
                    Label(person.name, systemImage: "person.crop.circle.fill")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
            .swipeActions {
                Button(role: .destructive) {
                    viewModel.removeTrigger(id: trigger.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            Button {
                showSheet = true
            } label: {
                Label("Person", systemImage: "person.crop.circle.badge.plus")
                    .foregroundStyle(.accent)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
        }
    }
}

struct MemorySequentialTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showSheet: Bool
    let memoryLookup: [UUID: MemoryModel]

    private var configuration: MemoryTriggerModel.TriggerSequential? {
        viewModel.sequentialTrigger?.sequential
    }

    var body: some View {
        if hasConfiguration {
            Button {
                showSheet = true
            } label: {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.right.circle")
                        .font(.caption.bold())
                    Text(summaryText)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
            .swipeActions {
                Button(role: .destructive) {
                    viewModel.removeSequentialTrigger()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            Button {
                showSheet = true
            } label: {
                Label("Sequence", systemImage: "arrowshape.turn.up.right.circle.badge.clockwise")
                    .foregroundStyle(.accent)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
        }
    }

    private var hasConfiguration: Bool {
        guard let configuration else { return false }
        return configuration.previousMemoryID != nil || configuration.nextMemoryID != nil
    }

    private var summaryText: String {
        guard let configuration else { return "Sequential trigger" }
        let previous = configuration.previousMemoryID.flatMap { name(for: $0) }
        let next = configuration.nextMemoryID.flatMap { name(for: $0) }

        switch (previous, next) {
        case let (prev?, next?):
            return "\(prev) → \(next)"
        case let (prev?, nil):
            return "After \(prev)"
        case let (nil, next?):
            return "Activates \(next)"
        default:
            return "Sequential trigger"
        }
    }

    private func name(for id: UUID) -> String {
        if let title = memoryLookup[id]?.title, !title.isEmpty {
            return title
        }
        return String(id.uuidString.prefix(6)) + "…"
    }
}

func weekdayMaskSummary(mask: Int16) -> String {
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
