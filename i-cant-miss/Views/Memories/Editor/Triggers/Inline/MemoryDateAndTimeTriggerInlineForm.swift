import SwiftUI

struct MemoryDateAndTimeTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showSheet: Bool

    private var trigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .scheduled })
    }

    var body: some View {
        Group {
            if let trigger {
                configuredButton(for: trigger)
                    .swipeActions {
                        Button(role: .destructive) {
                            viewModel.setScheduledTrigger(
                                fireDate: nil,
                                recurrence: nil,
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
                Label(scheduledSummary(for: trigger),
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
            Label("Add date & time", systemImage: "clock.badge.plus")
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

    private func scheduledSummary(for trigger: MemoryTriggerDraft) -> String {
        var parts: [String] = []

        // Se houver weekdayMask, mostrar resumo dos dias
        if trigger.weekdayMask != 0 {
            let weekdaySummary = weekdayMaskSummary(mask: trigger.weekdayMask)
            parts.append(weekdaySummary)
        }

        // Se houver fireDate, mostrar data/hora
        if let fireDate = trigger.fireDate {
            if trigger.weekdayMask != 0 {
                // Se houver dias da semana, mostrar apenas a hora
                parts.append(fireDate.formatted(date: .omitted, time: .shortened))
            } else {
                // Caso contrário, mostrar data e hora
                parts.append(fireDate.formatted(date: .abbreviated, time: .shortened))
            }
        }

        // Se houver recorrência, mostrar resumo
        if let recurrence = trigger.recurrenceRule {
            parts.append(recurrenceSummary(recurrence))
        }

        if parts.isEmpty {
            return "No date selected"
        }

        return parts.joined(separator: " · ")
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
