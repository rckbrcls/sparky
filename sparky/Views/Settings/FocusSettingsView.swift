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
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        cardSectionLabel("Durations")

                        cardDivider

                        presetPicker(
                            title: "Focus",
                            value: $settings.workDurationMinutes,
                            presets: FocusPresetOptions.workMinutes,
                            label: FocusPresetOptions.durationLabel
                        )

                        cardDivider

                        presetPicker(
                            title: "Short break",
                            value: $settings.shortBreakDurationMinutes,
                            presets: FocusPresetOptions.shortBreakMinutes,
                            label: FocusPresetOptions.durationLabel
                        )

                        cardDivider

                        presetPicker(
                            title: "Long break",
                            value: $settings.longBreakDurationMinutes,
                            presets: FocusPresetOptions.longBreakMinutes,
                            label: FocusPresetOptions.durationLabel
                        )

                        cardDivider

                        presetPicker(
                            title: "Long break every",
                            value: $settings.pomodorosUntilLongBreak,
                            presets: FocusPresetOptions.pomodorosUntilLongBreak,
                            label: FocusPresetOptions.sessionLabel
                        )
                    }
                    .cardStyle()

                    Toggle("Auto-continue phases", isOn: $settings.autoContinue)
                        .tint(Color.accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .cardStyle()

                    VStack(spacing: 0) {
                        cardSectionLabel("Feedback")

                        cardDivider

                        Toggle("Notifications", isOn: $settings.notificationsEnabled)
                            .tint(Color.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)

                        cardDivider

                        Toggle("Sounds", isOn: $settings.soundsEnabled)
                            .tint(Color.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)

                        cardDivider

                        soundPicker(
                            title: "Focus complete",
                            selection: $settings.focusCompletionSound
                        )

                        cardDivider

                        soundPicker(
                            title: "Break complete",
                            selection: $settings.breakCompletionSound
                        )
                    }
                    .cardStyle()

                    Button(role: .destructive) {
                        settings.resetToDefaults()
                    } label: {
                        Text("Reset to defaults")
                            .foregroundStyle(Color.Theme.destructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .cardStyle()
                }
            }
            .listRowInsets(.init(top: 6, leading: 20, bottom: 6, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .compactPhoneListSections()
        .contentMargins(.top, 0, for: .scrollContent)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.Theme.secondaryBackground.ignoresSafeArea())
        .navigationTitle("Focus")
        .inlinePhoneNavigationTitle()
    }

    private var cardDivider: some View {
        Divider()
            .padding(.horizontal, 12)
    }

    private func cardSectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
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
        .tint(Color.Theme.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
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
            .tint(Color.Theme.textPrimary)

            Button("Test") {
                feedback.preview(selection.wrappedValue)
            }
            .foregroundStyle(Color.Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .disabled(!settings.soundsEnabled)
    }
}
