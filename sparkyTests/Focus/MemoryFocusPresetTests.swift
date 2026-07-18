//
//  MemoryFocusPresetTests.swift
//  sparkyTests
//

import Foundation
import Testing
@testable import sparky

@MainActor
struct MemoryFocusPresetTests {
    @Test func memoryRecipeStartsFromGlobalsAndRemainsLocal() {
        let environment = makeEnvironment(suite: "MemoryFocusPresetTests.local")
        environment.focusSettings.workDurationMinutes = 25
        environment.focusSettings.shortBreakDurationMinutes = 5
        environment.focusSettings.longBreakDurationMinutes = 15
        environment.focusSettings.pomodorosUntilLongBreak = 4
        environment.focusSettings.autoContinue = true

        let viewModel = MemoryEditorViewModel(
            environment: environment,
            attachmentStore: environment.attachmentStore,
            memory: nil,
            defaultMind: nil,
            template: .blank
        )
        let fireDate = Date().addingTimeInterval(600)
        viewModel.setScheduleConfig(
            fireDate: fireDate,
            recurrence: nil,
            weekdaySelection: [],
            referenceTime: fireDate
        )
        viewModel.setFocusEnabled(true)

        #expect(viewModel.focusRecipe == FocusRecipe.from(settings: environment.focusSettings))

        viewModel.setFocusShortBreakDurationMinutes(10)

        #expect(viewModel.focusRecipe?.shortBreakDurationMinutes == 10)
        #expect(environment.focusSettings.shortBreakDurationMinutes == 5)
    }

    @Test func editingLegacyRecipeResolvesUntouchedFieldsFromGlobals() {
        let environment = makeEnvironment(suite: "MemoryFocusPresetTests.legacy")
        environment.focusSettings.shortBreakDurationMinutes = 10
        environment.focusSettings.longBreakDurationMinutes = 30
        environment.focusSettings.pomodorosUntilLongBreak = 5
        environment.focusSettings.autoContinue = false

        let viewModel = MemoryEditorViewModel(
            environment: environment,
            attachmentStore: environment.attachmentStore,
            memory: nil,
            defaultMind: nil,
            template: .blank
        )
        viewModel.scheduleConfigDraft = ScheduleConfigDraft(
            fireDate: Date().addingTimeInterval(600),
            isActive: true,
            focusEnabled: true
        )

        viewModel.setFocusWorkDurationMinutes(30)

        #expect(viewModel.focusRecipe?.workDurationMinutes == 30)
        #expect(viewModel.focusRecipe?.shortBreakDurationMinutes == 10)
        #expect(viewModel.focusRecipe?.longBreakDurationMinutes == 30)
        #expect(viewModel.focusRecipe?.pomodorosUntilLongBreak == 5)
        #expect(viewModel.focusRecipe?.autoContinue == false)
    }

    private func makeEnvironment(suite: String) -> AppEnvironment {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppEnvironment(
            dataController: DataController(inMemory: true),
            focusSettings: FocusSettings(defaults: defaults)
        )
    }
}
