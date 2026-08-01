//
//  FocusConfigurationMenu.swift
//  sparky
//

import SwiftUI

struct FocusConfigurationMenu: View {
    @Binding var recipe: FocusRecipe
    let onChange: () -> Void

    @State private var isPresented = false

    var body: some View {
        // Single glass circle — toolbar shared glass is hidden at call site.
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.body.weight(.medium))
                .foregroundStyle(Color.Theme.textPrimary)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Quick Focus settings")
        .accessibilityHint("Opens settings for the next Quick Focus session")
        .popover(isPresented: $isPresented) {
            configurationPanel
                .presentationCompactAdaptation(.popover)
        }
    }

    private var configurationPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Quick Focus settings")
                    .font(.headline)
                    .foregroundStyle(Color.Theme.textPrimary)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.Theme.textSecondary)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Close Quick Focus settings")
            }
            .padding(.bottom, 10)

            Divider()

            configurationRow(
                title: "Focus",
                value: recipe.workDurationMinutes,
                presets: FocusPresetOptions.workMinutes,
                label: FocusPresetOptions.durationLabel,
                onSelect: setWorkDuration
            )

            Divider()

            configurationRow(
                title: "Short break",
                value: recipe.shortBreakDurationMinutes,
                presets: FocusPresetOptions.shortBreakMinutes,
                label: FocusPresetOptions.durationLabel,
                onSelect: setShortBreakDuration
            )

            Divider()

            configurationRow(
                title: "Long break",
                value: recipe.longBreakDurationMinutes,
                presets: FocusPresetOptions.longBreakMinutes,
                label: FocusPresetOptions.durationLabel,
                onSelect: setLongBreakDuration
            )

            Divider()

            configurationRow(
                title: "Long break every",
                value: recipe.pomodorosUntilLongBreak,
                presets: FocusPresetOptions.pomodorosUntilLongBreak,
                label: FocusPresetOptions.sessionLabel,
                onSelect: setPomodorosUntilLongBreak
            )

            Divider()

            Toggle(
                "Auto-continue phases",
                isOn: Binding(
                    get: { recipe.autoContinue },
                    set: setAutoContinue
                )
            )
            .toggleStyle(.switch)
            .tint(Color.accentColor)
            .padding(.vertical, 10)
            .accessibilityLabel("Auto-continue Quick Focus phases")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 320)
    }

    private func configurationRow(
        title: String,
        value: Int,
        presets: [Int],
        label: @escaping (Int) -> String,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .foregroundStyle(Color.Theme.textPrimary)

            Spacer(minLength: 12)

            Menu {
                ForEach(presets, id: \.self) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        if option == value {
                            Label(label(option), systemImage: "checkmark")
                        } else {
                            Text(label(option))
                        }
                    }
                }
            } label: {
                Text(label(value))
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.Theme.textPrimary)
            .glassEffect(.regular.interactive(), in: .capsule)
            .accessibilityLabel(title)
            .accessibilityValue(label(value))
        }
        .padding(.vertical, 10)
    }

    private func setWorkDuration(_ minutes: Int) {
        updateRecipe(
            workDurationMinutes: minutes,
            shortBreakDurationMinutes: recipe.shortBreakDurationMinutes,
            longBreakDurationMinutes: recipe.longBreakDurationMinutes,
            pomodorosUntilLongBreak: recipe.pomodorosUntilLongBreak,
            autoContinue: recipe.autoContinue
        )
    }

    private func setShortBreakDuration(_ minutes: Int) {
        updateRecipe(
            workDurationMinutes: recipe.workDurationMinutes,
            shortBreakDurationMinutes: minutes,
            longBreakDurationMinutes: recipe.longBreakDurationMinutes,
            pomodorosUntilLongBreak: recipe.pomodorosUntilLongBreak,
            autoContinue: recipe.autoContinue
        )
    }

    private func setLongBreakDuration(_ minutes: Int) {
        updateRecipe(
            workDurationMinutes: recipe.workDurationMinutes,
            shortBreakDurationMinutes: recipe.shortBreakDurationMinutes,
            longBreakDurationMinutes: minutes,
            pomodorosUntilLongBreak: recipe.pomodorosUntilLongBreak,
            autoContinue: recipe.autoContinue
        )
    }

    private func setPomodorosUntilLongBreak(_ count: Int) {
        updateRecipe(
            workDurationMinutes: recipe.workDurationMinutes,
            shortBreakDurationMinutes: recipe.shortBreakDurationMinutes,
            longBreakDurationMinutes: recipe.longBreakDurationMinutes,
            pomodorosUntilLongBreak: count,
            autoContinue: recipe.autoContinue
        )
    }

    private func setAutoContinue(_ enabled: Bool) {
        updateRecipe(
            workDurationMinutes: recipe.workDurationMinutes,
            shortBreakDurationMinutes: recipe.shortBreakDurationMinutes,
            longBreakDurationMinutes: recipe.longBreakDurationMinutes,
            pomodorosUntilLongBreak: recipe.pomodorosUntilLongBreak,
            autoContinue: enabled
        )
    }

    private func updateRecipe(
        workDurationMinutes: Int,
        shortBreakDurationMinutes: Int,
        longBreakDurationMinutes: Int,
        pomodorosUntilLongBreak: Int,
        autoContinue: Bool
    ) {
        recipe = FocusRecipe(
            workDurationMinutes: workDurationMinutes,
            shortBreakDurationMinutes: shortBreakDurationMinutes,
            longBreakDurationMinutes: longBreakDurationMinutes,
            pomodorosUntilLongBreak: pomodorosUntilLongBreak,
            autoContinue: autoContinue
        )
        onChange()
    }
}
