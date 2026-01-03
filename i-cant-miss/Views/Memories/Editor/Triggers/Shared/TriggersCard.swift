import SwiftUI

struct TriggersCard: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showDateAndTimeSheet: Bool
    @Binding var showLocationPicker: Bool
    @Binding var showPersonSheet: Bool
    @Binding var showSequentialSheet: Bool
    let memoryLookup: [UUID: MemoryModel]

    private var triggerCount: Int {
        viewModel.triggers.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 8) {
                // Existing triggers
                if hasScheduledTrigger {
                    TriggerMiniCard(
                        trigger: viewModel.triggers.first(where: { $0.type == .scheduled }),
                        iconName: "clock.badge",
                        label: scheduledLabel,
                        onTap: { showDateAndTimeSheet = true },
                        onDelete: { removeTrigger(type: .scheduled) }
                    )
                }

                if hasLocationTrigger {
                    TriggerMiniCard(
                        trigger: viewModel.triggers.first(where: { $0.type == .location }),
                        iconName: "mappin.circle.fill",
                        label: locationLabel,
                        onTap: { showLocationPicker = true },
                        onDelete: { removeTrigger(type: .location) }
                    )
                }

                if hasPersonTrigger {
                    TriggerMiniCard(
                        trigger: viewModel.triggers.first(where: { $0.type == .person }),
                        iconName: "person.crop.circle.fill",
                        label: personLabel,
                        onTap: { showPersonSheet = true },
                        onDelete: { removeTrigger(type: .person) }
                    )
                }

                if hasSequentialTrigger {
                    TriggerMiniCard(
                        trigger: viewModel.sequentialTrigger,
                        iconName: "arrowshape.turn.up.right.circle",
                        label: sequentialLabel,
                        onTap: { showSequentialSheet = true },
                        onDelete: { viewModel.removeSequentialTrigger() }
                    )
                }



                // Add trigger button (dashed border)
                if triggerCount == 0 {
                    addTriggerButton
                }
            }
        }
    }

    private var addTriggerButton: some View {
        Menu {
            Button {
                showDateAndTimeSheet = true
            } label: {
                Label("Date & Time", systemImage: "clock.badge")
            }

            Button {
                showLocationPicker = true
            } label: {
                Label("Location", systemImage: "mappin.circle.fill")
            }

            Button {
                showPersonSheet = true
            } label: {
                Label("Person", systemImage: "person.crop.circle.badge.plus")
            }

            Button {
                showSequentialSheet = true
            } label: {
                Label("Sequence", systemImage: "arrow.right")
            }


        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.caption.bold())
                Text("Add Trigger")
                    .font(.caption.bold())
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.4))
            )
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
        .accessibilityLabel("Add trigger")
    }

    // MARK: - Trigger State Helpers

    private var hasScheduledTrigger: Bool {
        viewModel.triggers.contains(where: { $0.type == .scheduled })
    }

    private var hasLocationTrigger: Bool {
        viewModel.triggers.contains(where: { $0.type == .location })
    }

    private var hasPersonTrigger: Bool {
        viewModel.triggers.contains(where: { $0.type == .person })
    }

    private var hasSequentialTrigger: Bool {
        return viewModel.sequentialTrigger?.sequential != nil
    }



    // MARK: - Label Helpers

    private var scheduledLabel: String {
        guard let trigger = viewModel.triggers.first(where: { $0.type == .scheduled }) else {
            return "Date & Time"
        }
        return scheduledSummary(for: trigger)
    }

    private var locationLabel: String {
        guard let trigger = viewModel.triggers.first(where: { $0.type == .location }),
              let location = trigger.location else {
            return "Location"
        }
        return location.name ?? "Location"
    }

    private var personLabel: String {
        guard let trigger = viewModel.triggers.first(where: { $0.type == .person }),
              let person = trigger.person else {
            return "Person"
        }
        return person.name
    }

    private var sequentialLabel: String {
        guard let configuration = viewModel.sequentialTrigger?.sequential else {
            return "Sequence"
        }
        return "Step \(configuration.stepIndex + 1)"
    }



    // MARK: - Helper Functions

    private func removeTrigger(type: MemoryTriggerType) {
        if let trigger = viewModel.triggers.first(where: { $0.type == type }) {
            viewModel.removeTrigger(id: trigger.id)
        }
    }

    private func name(for id: UUID) -> String {
        if let title = memoryLookup[id]?.title, !title.isEmpty {
            return title
        }
        return String(id.uuidString.prefix(6)) + "…"
    }

    private func scheduledSummary(for trigger: MemoryTriggerDraft) -> String {
        var parts: [String] = []

        if trigger.weekdayMask != 0 {
            let weekdaySummary = weekdayMaskSummary(mask: trigger.weekdayMask)
            parts.append(weekdaySummary)
        }

        if let fireDate = trigger.fireDate {
            if trigger.isAllDay {
                // All-day: show only date, no time
                parts.append(fireDate.formatted(date: .abbreviated, time: .omitted))
            } else if trigger.weekdayMask != 0 {
                parts.append(fireDate.formatted(date: .omitted, time: .shortened))
            } else {
                parts.append(fireDate.formatted(date: .abbreviated, time: .shortened))
            }
        }

        if let recurrence = trigger.recurrenceRule {
            parts.append(recurrenceSummary(recurrence))
        }

        if parts.isEmpty {
            return "Date & Time"
        }

        return parts.joined(separator: " · ")
    }

    private func recurrenceSummary(_ recurrence: RecurrenceRule) -> String {
        switch recurrence.frequency {
        case .minutely:
            return recurrence.interval == 1 ? "Every minute" : "Every \(recurrence.interval) minutes"
        case .hourly:
            return recurrence.interval == 1 ? "Every hour" : "Every \(recurrence.interval) hours"
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

// MARK: - TriggerMiniCard

private struct TriggerMiniCard: View {
    let trigger: MemoryTriggerDraft?
    let iconName: String
    let label: String
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.subheadline)
                .foregroundStyle(.accent)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Spacer()

            Menu {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .highPriorityGesture(TapGesture()) // Consume taps to prevent row selection
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .id(trigger?.id ?? UUID())
    }
}
