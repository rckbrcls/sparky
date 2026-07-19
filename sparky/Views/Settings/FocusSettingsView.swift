//
//  FocusSettingsView.swift
//  sparky
//

import SwiftUI

struct FocusSettingsView: View {
    @ObservedObject var settings: FocusSettings

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
            } footer: {
                Text("Defaults for new Quick Focus sessions and newly enabled Memory Focus recipes. Local changes do not modify these defaults.")
            }

            Section {
                Toggle("Auto-continue phases", isOn: $settings.autoContinue)
            } footer: {
                Text("When off, Focus pauses between work and break so you can start the next phase manually.")
            }

            Section {
                Button("Reset to defaults", role: .destructive) {
                    settings.resetToDefaults()
                }
            }
        }
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
}
