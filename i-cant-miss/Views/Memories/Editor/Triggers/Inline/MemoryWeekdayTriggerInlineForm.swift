import SwiftUI

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


