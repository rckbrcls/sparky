import SwiftUI

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


