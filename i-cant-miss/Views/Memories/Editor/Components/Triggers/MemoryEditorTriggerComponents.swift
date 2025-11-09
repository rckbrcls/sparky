import SwiftUI

struct MemoryEditorTriggerButtonsBar: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showTriggerPicker: Bool
    @Binding var showScheduleSheet: Bool
    @Binding var showLocationPicker: Bool
    @Binding var showPersonSheet: Bool
    @Binding var showSequentialSheet: Bool
    let memoryLookup: [UUID: MemoryModel]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                MemoryTriggerAddBadge(isPresented: $showTriggerPicker)
                MemoryScheduleTriggerInlineForm(
                    viewModel: viewModel,
                    showSheet: $showScheduleSheet
                )
                MemoryLocationTriggerInlineForm(
                    viewModel: viewModel,
                    showLocationPicker: $showLocationPicker
                )
                MemoryPersonTriggerInlineForm(
                    viewModel: viewModel,
                    showSheet: $showPersonSheet
                )
                MemorySequentialTriggerInlineForm(
                    viewModel: viewModel,
                    showSheet: $showSequentialSheet,
                    memoryLookup: memoryLookup
                )
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MemoryTriggerAddBadge: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label("Add Trigger", systemImage: "plus")
                .font(.caption.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .buttonStyle(.glassProminent)
    }
}

struct MemoryScheduleTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showSheet: Bool

    private var timeTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .time })
    }

    private var weekdayTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .dayOfWeek })
    }

    private var hasSchedule: Bool {
        timeTrigger != nil || weekdayTrigger != nil || viewModel.dueDateEnabled
    }

    var body: some View {
        if hasSchedule {
            Button {
                showSheet = true
            } label: {
                HStack {
                    Label(schedulePrimaryText, systemImage: "calendar.badge.clock")
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
                    viewModel.clearScheduleTriggers()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            Button {
                showSheet = true
            } label: {
                Label("Schedule", systemImage: "calendar.badge.plus")
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

    private var schedulePrimaryText: String {
        if viewModel.dueDateEnabled {
            return "Due: " + viewModel.dueDate.formatted(date: .abbreviated, time: .shortened)
        }
        if let date = timeTrigger?.fireDate ?? weekdayTrigger?.fireDate {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        if let mask = weekdayTrigger?.weekdayMask, mask != 0 {
            return weekdayMaskSummary(mask: mask)
        }
        return "Custom schedule"
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
