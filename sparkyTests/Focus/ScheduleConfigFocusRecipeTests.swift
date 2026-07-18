//
//  ScheduleConfigFocusRecipeTests.swift
//  sparkyTests
//

import Foundation
import Testing
@testable import sparky

struct ScheduleConfigFocusRecipeTests {

    @Test func draftModelRoundTripPreservesRecipe() {
        let draft = ScheduleConfigDraft(
            fireDate: Date(),
            startDate: Date(),
            timeZoneIdentifier: TimeZone.current.identifier,
            isActive: true,
            focusEnabled: true,
            focusWorkDurationMinutes: 18,
            focusShortBreakDurationMinutes: 4,
            focusLongBreakDurationMinutes: 12,
            focusPomodorosUntilLongBreak: 3,
            focusAutoContinue: false
        )

        let model = draft.toModel()
        let back = ScheduleConfigDraft.from(model)

        #expect(back.focusEnabled == true)
        #expect(back.focusWorkDurationMinutes == 18)
        #expect(back.focusShortBreakDurationMinutes == 4)
        #expect(back.focusLongBreakDurationMinutes == 12)
        #expect(back.focusPomodorosUntilLongBreak == 3)
        #expect(back.focusAutoContinue == false)
    }

    @Test func applyFocusRecipeSeedsConcreteValues() {
        var draft = ScheduleConfigDraft(focusEnabled: true)
        #expect(!draft.hasConcreteFocusRecipe)
        draft.applyFocusRecipe(
            FocusRecipe(
                workDurationMinutes: 25,
                shortBreakDurationMinutes: 5,
                longBreakDurationMinutes: 15,
                pomodorosUntilLongBreak: 4,
                autoContinue: true
            )
        )
        #expect(draft.hasConcreteFocusRecipe)
        #expect(draft.focusWorkDurationMinutes == 25)
    }
}
