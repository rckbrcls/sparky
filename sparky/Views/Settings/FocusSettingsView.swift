//
//  FocusSettingsView.swift
//  sparky
//

import SwiftUI

struct FocusSettingsView: View {
    @ObservedObject var settings: FocusSettings
    let feedback: FocusFeedbackHandling

    var body: some View {
        List {
            Section {
                presetPicker(
                    title: "Focus",
                    value: $settings.workDurationMinutes,
                    presets: FocusPresetOptions.workMinutes,
                    label: FocusPresetOptions.durationLabel
                )
                presetPicker(
                    title: "Short break",
                    value: $settings.shortBreakDurationMinutes,
                    presets: FocusPresetOptions.shortBreakMinutes,
                    label: FocusPresetOptions.durationLabel
                )
                presetPicker(
                    title: "Long break",
                    value: $settings.longBreakDurationMinutes,
                    presets: FocusPresetOptions.longBreakMinutes,
                    label: FocusPresetOptions.durationLabel
                )
                presetPicker(
                    title: "Long break every",
                    value: $settings.pomodorosUntilLongBreak,
                    presets: FocusPresetOptions.pomodorosUntilLongBreak,
                    label: FocusPresetOptions.sessionLabel
                )
            } header: {
                Text("Durations")
            }

            Section {
                Toggle("Auto-continue phases", isOn: $settings.autoContinue)
            }

            Section("Feedback") {
                Toggle("Notifications", isOn: $settings.notificationsEnabled)
                Toggle("Sounds", isOn: $settings.soundsEnabled)
                soundPicker(
                    title: "Focus complete",
                    selection: $settings.focusCompletionSound
                )
                soundPicker(
                    title: "Break complete",
                    selection: $settings.breakCompletionSound
                )
            }

            Section {
                Button("Reset to defaults", role: .destructive) {
                    settings.resetToDefaults()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.Theme.secondaryBackground.ignoresSafeArea())
        .navigationTitle("Focus")
        .inlinePhoneNavigationTitle()
    }

    private func presetPicker(
        title: String,
        value: Binding<Int>,
        presets: [Int],
        label: @escaping (Int) -> String
    ) -> some View {
        Picker(title, selection: value) {
            ForEach(presets, id: \.self) { option in
                Text(label(option))
                    .tag(option)
            }
        }
        .pickerStyle(.menu)
    }

    private func soundPicker(
        title: String,
        selection: Binding<FocusSoundChoice>
    ) -> some View {
        HStack(spacing: 12) {
            Picker(title, selection: selection) {
                ForEach(FocusSoundChoice.allCases) { sound in
                    Text(sound.title)
                        .tag(sound)
                }
            }
            .pickerStyle(.menu)

            Button("Test") {
                feedback.preview(selection.wrappedValue)
            }
        }
        .disabled(!settings.soundsEnabled)
    }
}
