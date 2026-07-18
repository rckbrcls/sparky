//
//  ScheduleConfigDraft.swift
//  sparky
//
//  In-memory draft for editing schedule configuration in UI.
//

import Foundation

struct ScheduleConfigDraft: Identifiable, Hashable {
    let id: UUID
    var fireDate: Date?
    var startDate: Date?
    var recurrenceRule: RecurrenceRule?
    var timeZoneIdentifier: String?
    var weekdayMask: Int16
    var isActive: Bool
    var isAllDay: Bool
    var recurrenceEndType: RecurrenceEndType
    var reminder: NestedReminderPolicy
    var focusEnabled: Bool
    var focusWorkDurationMinutes: Int
    var focusShortBreakDurationMinutes: Int
    var focusLongBreakDurationMinutes: Int
    var focusPomodorosUntilLongBreak: Int
    var focusAutoContinue: Bool

    init(
        id: UUID = UUID(),
        fireDate: Date? = nil,
        startDate: Date? = nil,
        recurrenceRule: RecurrenceRule? = nil,
        timeZoneIdentifier: String? = nil,
        weekdayMask: Int16 = 0,
        isActive: Bool = true,
        isAllDay: Bool = false,
        recurrenceEndType: RecurrenceEndType = .never,
        reminder: NestedReminderPolicy = NestedReminderPolicy(),
        focusEnabled: Bool = false,
        focusWorkDurationMinutes: Int = 0,
        focusShortBreakDurationMinutes: Int = 0,
        focusLongBreakDurationMinutes: Int = 0,
        focusPomodorosUntilLongBreak: Int = 0,
        focusAutoContinue: Bool = true
    ) {
        self.id = id
        self.fireDate = fireDate
        self.startDate = startDate
        self.recurrenceRule = recurrenceRule
        self.timeZoneIdentifier = timeZoneIdentifier
        self.weekdayMask = weekdayMask
        self.isActive = isActive
        self.isAllDay = isAllDay
        self.recurrenceEndType = recurrenceEndType
        self.reminder = reminder
        self.focusEnabled = focusEnabled
        self.focusWorkDurationMinutes = focusWorkDurationMinutes
        self.focusShortBreakDurationMinutes = focusShortBreakDurationMinutes
        self.focusLongBreakDurationMinutes = focusLongBreakDurationMinutes
        self.focusPomodorosUntilLongBreak = focusPomodorosUntilLongBreak
        self.focusAutoContinue = focusAutoContinue
    }

    static func == (lhs: ScheduleConfigDraft, rhs: ScheduleConfigDraft) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var hasConcreteFocusRecipe: Bool {
        focusWorkDurationMinutes > 0
            && focusShortBreakDurationMinutes > 0
            && focusLongBreakDurationMinutes > 0
            && focusPomodorosUntilLongBreak > 0
    }

    mutating func applyFocusRecipe(_ recipe: FocusRecipe) {
        focusWorkDurationMinutes = recipe.workDurationMinutes
        focusShortBreakDurationMinutes = recipe.shortBreakDurationMinutes
        focusLongBreakDurationMinutes = recipe.longBreakDurationMinutes
        focusPomodorosUntilLongBreak = recipe.pomodorosUntilLongBreak
        focusAutoContinue = recipe.autoContinue
    }
}

// MARK: - Conversions

extension ScheduleConfigDraft {
    /// Converts draft to persistent model
    func toModel(memory: Memory? = nil) -> ScheduleConfig {
        ScheduleConfig(
            id: id,
            fireDate: fireDate,
            startDate: startDate,
            recurrenceRule: recurrenceRule,
            timeZoneIdentifier: timeZoneIdentifier,
            weekdayMask: weekdayMask,
            isActive: isActive,
            isAllDay: isAllDay,
            recurrenceEndType: recurrenceEndType,
            reminder: reminder,
            focusEnabled: focusEnabled,
            focusWorkDurationMinutes: focusWorkDurationMinutes,
            focusShortBreakDurationMinutes: focusShortBreakDurationMinutes,
            focusLongBreakDurationMinutes: focusLongBreakDurationMinutes,
            focusPomodorosUntilLongBreak: focusPomodorosUntilLongBreak,
            focusAutoContinue: focusAutoContinue,
            memory: memory
        )
    }

    /// Creates draft from persistent model
    static func from(_ model: ScheduleConfig) -> ScheduleConfigDraft {
        ScheduleConfigDraft(
            id: model.id,
            fireDate: model.fireDate,
            startDate: model.startDate,
            recurrenceRule: model.recurrenceRule,
            timeZoneIdentifier: model.timeZoneIdentifier,
            weekdayMask: model.weekdayMask,
            isActive: model.isActive,
            isAllDay: model.isAllDay,
            recurrenceEndType: model.recurrenceEndType,
            reminder: model.reminder,
            focusEnabled: model.focusEnabled,
            focusWorkDurationMinutes: model.focusWorkDurationMinutes,
            focusShortBreakDurationMinutes: model.focusShortBreakDurationMinutes,
            focusLongBreakDurationMinutes: model.focusLongBreakDurationMinutes,
            focusPomodorosUntilLongBreak: model.focusPomodorosUntilLongBreak,
            focusAutoContinue: model.focusAutoContinue
        )
    }

    /// Creates a default draft for 1 hour from now
    static func createDefault(from date: Date = Date()) -> ScheduleConfigDraft {
        let fireDate = date.addingTimeInterval(3600)
        return ScheduleConfigDraft(
            fireDate: fireDate,
            startDate: fireDate,
            timeZoneIdentifier: TimeZone.current.identifier,
            isActive: true
        )
    }
}
