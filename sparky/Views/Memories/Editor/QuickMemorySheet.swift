//
//  QuickMemorySheet.swift
//  sparky
//
//  Created by Codex on 10/12/24.
//

import SwiftUI

struct QuickMemorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var mindService: MindService

    @AppStorage("quickMemory.lastReminderMinutes") private var lastReminderMinutes: Int = -1
    @FocusState private var isTitleFocused: Bool

    let environment: AppEnvironment
    let request: QuickMemoryRequest
    let onExpandToEditor: (Mind?, String, ScheduleConfigDraft?) -> Void
    let onQuickCreate: (Mind?, String, ScheduleConfigDraft?) -> Void

    @State private var title = ""
    @State private var selectedMindID: UUID?
    @State private var selectedReminderMinutes: Int?

    init(
        environment: AppEnvironment,
        request: QuickMemoryRequest,
        onExpandToEditor: @escaping (Mind?, String, ScheduleConfigDraft?) -> Void,
        onQuickCreate: @escaping (Mind?, String, ScheduleConfigDraft?) -> Void
    ) {
        self.environment = environment
        self.mindService = environment.mindService
        self.request = request
        self.onExpandToEditor = onExpandToEditor
        self.onQuickCreate = onQuickCreate
    }

    var body: some View {
        Group {
            #if os(iOS)
            content
                .presentationDetents([.height(118)])
                .presentationBackground(.clear)
            #else
            content
                .frame(width: 480, height: 150)
            #endif
        }
        .onAppear {
            configureInitialState()
            DispatchQueue.main.async {
                isTitleFocused = true
            }
        }
    }

    private var content: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                mindIconMenu

                TextField("Memory", text: $title)
                    .font(.custom("Baskerville", size: 20))
                    .textFieldStyle(.plain)
                    .focused($isTitleFocused)
                    .onSubmit(submitQuickMemory)
                    .lineLimit(1)
                    .frame(height: 30)

                Button(action: expandToEditor) {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .quickMemoryCircleControl(tint: Color.primary.opacity(0.1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More options")
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            HStack(spacing: 8) {
                if request.calendarTarget != nil {
                    calendarContextRow
                } else {
                    reminderMenu
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
    }

    private var availableMinds: [Mind] {
        mindService.minds
    }

    private var selectedMind: Mind? {
        guard let id = selectedMindID else { return nil }
        return availableMinds.first { $0.id == id }
    }

    private var mindColor: Color {
        if let hex = selectedMind?.colorHex,
           let color = Color(hex: hex) {
            return color
        }
        return .gray
    }

    private var scheduleConfigDraft: ScheduleConfigDraft? {
        if let target = request.calendarTarget {
            return target.scheduleDraft()
        }

        guard let minutes = selectedReminderMinutes else {
            return nil
        }

        let fireDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        return ScheduleConfigDraft(
            fireDate: fireDate,
            startDate: fireDate,
            timeZoneIdentifier: TimeZone.current.identifier,
            isActive: true
        )
    }

    private var mindIconMenu: some View {
        Menu {
            Picker("Mind", selection: $selectedMindID) {
                Label("No Mind", systemImage: "brain.head.profile")
                    .tag(nil as UUID?)

                ForEach(availableMinds) { mind in
                    Label(mind.name, systemImage: mind.iconName ?? "brain.head.profile")
                        .tag(Optional(mind.id))
                }
            }
        } label: {
            Image(systemName: selectedMind?.iconName ?? "brain.head.profile")
                .foregroundStyle(mindColor)
                .frame(width: 36, height: 36)
                .quickMemoryCircleControl(tint: mindColor.opacity(0.15))
        }
        .accessibilityLabel("Mind")
    }

    @ViewBuilder
    private var calendarContextRow: some View {
        if let target = request.calendarTarget {
            let period = target.period
            let scheduledDate = target.suggestedDate()

            HStack(spacing: 10) {
                Image(systemName: period.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(period.color)

                VStack(alignment: .leading, spacing: 1) {
                    Text(period.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.Theme.textPrimary)

                    Text(
                        scheduledDate,
                        format: .dateTime
                            .weekday(.abbreviated)
                            .month(.abbreviated)
                            .day()
                    )
                    .font(.caption2)
                    .foregroundStyle(Color.Theme.textSecondary)
                }

                if target.period != .allDay {
                    Text(scheduledDate, format: .dateTime.hour().minute())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.Theme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .quickMemoryCapsuleControl(tint: period.color.opacity(0.12))
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var reminderMenu: some View {
        Menu {
            Button {
                setReminderSelection(nil)
            } label: {
                if selectedReminderMinutes == nil {
                    Label("No Reminder", systemImage: "checkmark")
                } else {
                    Text("No Reminder")
                }
            }

            Divider()

            ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                Button {
                    setReminderSelection(minutes)
                } label: {
                    let isSelected = selectedReminderMinutes == minutes
                    let displayText = "in \(minutes) min"
                    if isSelected {
                        Label(displayText, systemImage: "checkmark")
                    } else {
                        Text(displayText)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selectedReminderMinutes != nil ? Color.Theme.warning : .secondary)

                if let minutes = selectedReminderMinutes {
                    Text("Remind me in \(minutes) min")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.Theme.warning)
                } else {
                    Text("Remind me in")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .quickMemoryCapsuleControl(
                tint: selectedReminderMinutes != nil
                    ? Color.Theme.warning.opacity(0.15)
                    : Color.primary.opacity(0.05)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quick reminder")
    }

    private func configureInitialState() {
        let mind = request.mind
        if mind?.isAllMinds == true || mind?.isLimbo == true {
            selectedMindID = nil
        } else {
            selectedMindID = mind?.id
        }

        if request.calendarTarget == nil {
            selectedReminderMinutes = lastReminderMinutes > 0
                ? lastReminderMinutes
                : nil
        } else {
            selectedReminderMinutes = nil
        }
    }

    private func setReminderSelection(_ minutes: Int?) {
        selectedReminderMinutes = minutes
        lastReminderMinutes = minutes ?? -1
    }

    private func submitQuickMemory() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        dismiss()
        onQuickCreate(selectedMind, trimmedTitle, scheduleConfigDraft)
    }

    private func expandToEditor() {
        onExpandToEditor(selectedMind, title, scheduleConfigDraft)
        dismiss()
    }
}

private extension View {
    @ViewBuilder
    func quickMemoryCircleControl(tint: Color) -> some View {
        #if os(iOS)
        glassEffect(.regular.tint(tint))
        #else
        background(Color.Theme.elementBackground, in: Circle())
            .overlay {
                Circle()
                    .stroke(Color.Theme.elementBorder, lineWidth: 1)
            }
        #endif
    }

    @ViewBuilder
    func quickMemoryCapsuleControl(tint: Color) -> some View {
        #if os(iOS)
        glassEffect(.regular.tint(tint))
        #else
        background(Color.Theme.elementBackground, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.Theme.elementBorder, lineWidth: 1)
            }
        #endif
    }
}

#Preview {
    let environment = AppEnvironment(dataController: DataController.preview)
    environment.bootstrap()

    return QuickMemorySheet(
        environment: environment,
        request: QuickMemoryRequest(mind: nil),
        onExpandToEditor: { _, _, _ in },
        onQuickCreate: { _, _, _ in }
    )
}
