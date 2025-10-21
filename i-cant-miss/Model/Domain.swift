//
//  Domain.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import CoreData

enum ReminderStatus: String, CaseIterable, Identifiable {
    case active
    case completed
    case overdue
    case archived

    var id: String { rawValue }
}

enum ReminderPriority: Int16, CaseIterable, Identifiable {
    case low = 0
    case medium = 1
    case high = 2

    var id: Int16 { rawValue }

    var iconName: String {
        switch self {
        case .low: return "exclamationmark"
        case .medium: return "exclamationmark.2"
        case .high: return "exclamationmark.3"
        }
    }
}

enum ReminderTriggerType: String, CaseIterable, Identifiable {
    case time
    case dayOfWeek
    case location
    case person

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .time: return "clock"
        case .dayOfWeek: return "calendar"
        case .location: return "mappin.and.ellipse"
        case .person: return "person.crop.circle"
        }
    }

    var label: String {
        switch self {
        case .time: return "Time"
        case .dayOfWeek: return "Weekday"
        case .location: return "Location"
        case .person: return "Person"
        }
    }
}

enum LocationEvent: String, CaseIterable, Identifiable {
    case onEntry
    case onExit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .onEntry: return "Arrive"
        case .onExit: return "Leave"
        }
    }
}

struct RecurrenceRule: Hashable, Codable {
    enum Frequency: String, Codable, CaseIterable {
        case daily
        case weekly
        case monthly
        case yearly
    }

    var frequency: Frequency
    var interval: Int
    var endDate: Date?
    var occurrenceCount: Int?

    init(frequency: Frequency, interval: Int = 1, endDate: Date? = nil, occurrenceCount: Int? = nil) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.endDate = endDate
        self.occurrenceCount = occurrenceCount
    }
}

extension RecurrenceRule.Frequency {
    var title: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

struct SpacedRepetitionSchedule: Hashable, Codable {
    let stages: [Int]
    var currentStageIndex: Int
    var lastReviewDate: Date?

    init(stages: [Int] = [1, 3, 7, 14, 30, 60, 90],
         currentStageIndex: Int = 0,
         lastReviewDate: Date? = nil) {
        self.stages = stages
        self.currentStageIndex = min(max(0, currentStageIndex), stages.count - 1)
        self.lastReviewDate = lastReviewDate
    }

    var currentIntervalDays: Int {
        stages[currentStageIndex]
    }

    func nextReviewDate(from referenceDate: Date = Date()) -> Date {
        let days = Double(currentIntervalDays)
        return Calendar.current.date(byAdding: .day, value: Int(days), to: referenceDate) ?? referenceDate
    }
}

struct ReminderTriggerModel: Identifiable, Hashable {
    let id: UUID
    let type: ReminderTriggerType
    var fireDate: Date?
    var startDate: Date?
    var recurrenceRule: RecurrenceRule?
    var timeZoneIdentifier: String?
    var weekdayMask: Int16
    var isActive: Bool
    var location: TriggerLocation?
    var person: TriggerPerson?
    var spacedStage: Int
    var lastReviewDate: Date?
    var ignoreCount: Int

    struct TriggerLocation: Hashable {
        var latitude: Double
        var longitude: Double
        var radius: Double
        var name: String?
        var event: LocationEvent
    }

    struct TriggerPerson: Hashable {
        var name: String
        var contactIdentifier: String?
    }
}

struct ReminderModel: Identifiable, Hashable {
    let id: UUID
    var title: String
    var notes: String?
    var status: ReminderStatus
    var priority: ReminderPriority
    var folder: FolderModel?
    var createdAt: Date
    var updatedAt: Date
    var lastCompletionDate: Date?
    var snoozeCount: Int
    var triggers: [ReminderTriggerModel]

    var isArchived: Bool {
        status == .archived
    }
}

struct ReminderSnoozeModel: Identifiable, Hashable {
    let id: UUID
    var originalFireDate: Date
    var newFireDate: Date
    var createdAt: Date
}

struct ReminderTriggerDraft: Identifiable {
    let id: UUID
    var type: ReminderTriggerType
    var fireDate: Date?
    var startDate: Date?
    var recurrenceRule: RecurrenceRule?
    var timeZoneIdentifier: String?
    var weekdayMask: Int16
    var isActive: Bool
    var location: ReminderTriggerModel.TriggerLocation?
    var person: ReminderTriggerModel.TriggerPerson?
    var spacedStage: Int
    var lastReviewDate: Date?
    var ignoreCount: Int

    init(
        id: UUID = UUID(),
        type: ReminderTriggerType,
        fireDate: Date? = nil,
        startDate: Date? = nil,
        recurrenceRule: RecurrenceRule? = nil,
        timeZoneIdentifier: String? = nil,
        weekdayMask: Int16 = 0,
        isActive: Bool = true,
        location: ReminderTriggerModel.TriggerLocation? = nil,
        person: ReminderTriggerModel.TriggerPerson? = nil,
        spacedStage: Int = 0,
        lastReviewDate: Date? = nil,
        ignoreCount: Int = 0
    ) {
        self.id = id
        self.type = type
        self.fireDate = fireDate
        self.startDate = startDate
        self.recurrenceRule = recurrenceRule
        self.timeZoneIdentifier = timeZoneIdentifier
        self.weekdayMask = weekdayMask
        self.isActive = isActive
        self.location = location
        self.person = person
        self.spacedStage = spacedStage
        self.lastReviewDate = lastReviewDate
        self.ignoreCount = ignoreCount
    }
}

struct ReminderDraft {
    var id: UUID = UUID()
    var title: String
    var notes: String?
    var status: ReminderStatus = .active
    var priority: ReminderPriority = .medium
    var folderID: UUID?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var triggers: [ReminderTriggerDraft] = []
}

extension ReminderTriggerDraft {
    func toModel() -> ReminderTriggerModel {
        ReminderTriggerModel(
            id: id,
            type: type,
            fireDate: fireDate,
            startDate: startDate,
            recurrenceRule: recurrenceRule,
            timeZoneIdentifier: timeZoneIdentifier,
            weekdayMask: weekdayMask,
            isActive: isActive,
            location: location,
            person: person,
            spacedStage: spacedStage,
            lastReviewDate: lastReviewDate,
            ignoreCount: ignoreCount
        )
    }
}

struct NoteModel: Identifiable, Hashable {
    let id: UUID
    var title: String?
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var folder: FolderModel?
    var tags: [TagModel]
}

struct TodoItemModel: Identifiable, Hashable {
    let id: UUID
    var title: String
    var detail: String?
    var isCompleted: Bool
    var sortOrder: Int
    var createdAt: Date
    var completedAt: Date?
}

struct TodoListModel: Identifiable, Hashable {
    let id: UUID
    var title: String
    var notes: String?
    var dueDate: Date?
    var isPinned: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    var userOrder: Int
    var folder: FolderModel?
    var items: [TodoItemModel]

    var completionRate: Double {
        guard !items.isEmpty else { return 0 }
        let completedCount = items.filter(\.isCompleted).count
        return Double(completedCount) / Double(items.count)
    }

    var isCompleted: Bool {
        !items.isEmpty && items.allSatisfy(\.isCompleted)
    }

    var pendingItemCount: Int {
        items.filter { !$0.isCompleted }.count
    }

    var hasDueDate: Bool {
        dueDate != nil
    }
}

struct FolderModel: Identifiable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String?
    var iconName: String?
    var showInReminders: Bool
    var showInNotes: Bool
    var showInTodos: Bool
    var isDefault: Bool
    var sortOrder: Int
}

struct TagModel: Identifiable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String?
}

// MARK: - Mapping helpers

extension Reminder {
    var status: ReminderStatus {
        ReminderStatus(rawValue: statusRaw ?? "active") ?? .active
    }

    var triggerSet: Set<ReminderTrigger> {
        (triggers as? Set<ReminderTrigger>) ?? []
    }

    func setStatus(_ status: ReminderStatus) {
        statusRaw = status.rawValue
    }

    var priorityLevel: ReminderPriority {
        ReminderPriority(rawValue: priority) ?? .medium
    }

    func setPriority(_ priority: ReminderPriority) {
        self.priority = priority.rawValue
    }

    func toModel() -> ReminderModel {
        let triggerSet = self.triggerSet

        return ReminderModel(
            id: id ?? UUID(),
            title: title ?? "Untitled reminder",
            notes: notes,
            status: status,
            priority: priorityLevel,
            folder: folder?.toModel(),
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            lastCompletionDate: lastCompletionDate,
            snoozeCount: Int(snoozeCount),
            triggers: triggerSet
                .map { $0.toModel() }
                .sorted(by: { ($0.fireDate ?? .distantFuture) < ($1.fireDate ?? .distantFuture) })
        )
    }
}

extension ReminderTrigger {
    var triggerType: ReminderTriggerType {
        ReminderTriggerType(rawValue: typeRaw ?? ReminderTriggerType.time.rawValue) ?? .time
    }

    func setType(_ type: ReminderTriggerType) {
        typeRaw = type.rawValue
    }

    var locationEvent: LocationEvent? {
        guard let raw = locationEventRaw else { return nil }
        return LocationEvent(rawValue: raw)
    }

    func setLocationEvent(_ event: LocationEvent?) {
        locationEventRaw = event?.rawValue
    }

    var recurrence: RecurrenceRule? {
        guard let text = recurrenceRule, let data = text.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(RecurrenceRule.self, from: data)
    }

    func setRecurrence(_ rule: RecurrenceRule?) {
        guard let rule else {
            recurrenceRule = nil
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(rule) {
            recurrenceRule = String(data: data, encoding: .utf8)
        }
    }

    func toModel() -> ReminderTriggerModel {
        let location: ReminderTriggerModel.TriggerLocation? = {
            guard triggerType == .location else { return nil }
            return ReminderTriggerModel.TriggerLocation(
                latitude: locationLatitude,
                longitude: locationLongitude,
                radius: locationRadius,
                name: locationName,
                event: locationEvent ?? .onEntry
            )
        }()

        let person: ReminderTriggerModel.TriggerPerson? = {
            guard triggerType == .person else { return nil }
            guard let name = personName else { return nil }
            return ReminderTriggerModel.TriggerPerson(name: name, contactIdentifier: personContactIdentifier)
        }()

        return ReminderTriggerModel(
            id: id ?? UUID(),
            type: triggerType,
            fireDate: fireDate,
            startDate: startDate,
            recurrenceRule: recurrence,
            timeZoneIdentifier: timeZoneIdentifier,
            weekdayMask: weekdayMask,
            isActive: isActive,
            location: location,
            person: person,
            spacedStage: Int(spacedStage),
            lastReviewDate: lastReviewDate,
            ignoreCount: Int(ignoreCount)
        )
    }
}

extension ReminderSnooze {
    func toModel() -> ReminderSnoozeModel {
        ReminderSnoozeModel(
            id: id ?? UUID(),
            originalFireDate: originalFireDate ?? Date(),
            newFireDate: newFireDate ?? Date(),
            createdAt: createdAt ?? Date()
        )
    }
}

extension Note {
    func toModel() -> NoteModel {
        let tagSet = (tags as? Set<Tag>) ?? []

        return NoteModel(
            id: id ?? UUID(),
            title: title,
            content: content ?? "",
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            isPinned: isPinned,
            folder: folder?.toModel(),
            tags: tagSet.map { $0.toModel() }.sorted(by: { $0.name < $1.name })
        )
    }
}

extension TodoList {
    var itemSet: Set<TodoItem> {
        (items as? Set<TodoItem>) ?? []
    }

    func toModel() -> TodoListModel {
        TodoListModel(
            id: id ?? UUID(),
            title: title ?? "Todo",
            notes: notes,
            dueDate: dueDate,
            isPinned: isPinned,
            isArchived: isArchived,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            userOrder: Int(userOrder),
            folder: folder?.toModel(),
            items: itemSet
                .map { $0.toModel() }
                .sorted(by: { $0.sortOrder < $1.sortOrder })
        )
    }
}

extension TodoItem {
    func toModel() -> TodoItemModel {
        TodoItemModel(
            id: id ?? UUID(),
            title: title ?? "Item",
            detail: detail,
            isCompleted: isCompleted,
            sortOrder: Int(sortOrder),
            createdAt: createdAt ?? Date(),
            completedAt: completedAt
        )
    }
}

extension Folder {
    func toModel() -> FolderModel {
        FolderModel(
            id: id ?? UUID(),
            name: name ?? "Folder",
            colorHex: colorHex,
            iconName: iconName,
            showInReminders: showInReminders,
            showInNotes: showInNotes,
            showInTodos: showInTodos,
            isDefault: isDefault,
            sortOrder: Int(sortOrder)
        )
    }
}

extension Tag {
    func toModel() -> TagModel {
        TagModel(id: id ?? UUID(), name: name ?? "Tag", colorHex: colorHex)
    }
}

// MARK: - ReminderModel Extensions

extension ReminderModel {
    func nextFireDate() -> Date? {
        let activeTriggers = triggers.filter { $0.isActive }
        guard !activeTriggers.isEmpty else { return nil }
        
        let now = Date()
        var nextDates: [Date] = []
        
        for trigger in activeTriggers {
            if let date = trigger.nextFireDate(after: now) {
                nextDates.append(date)
            }
        }
        
        return nextDates.min()
    }
    
    var hasRecurringTriggers: Bool {
        triggers.contains { $0.recurrenceRule != nil }
    }
    
    var primaryTriggerType: ReminderTriggerType? {
        triggers.first?.type
    }
    
    var hasActiveTriggers: Bool {
        triggers.contains { $0.isActive }
    }
}

extension ReminderTriggerModel {
    func nextFireDate(after date: Date = Date()) -> Date? {
        guard isActive else { return nil }
        
        switch type {
        case .time:
            return nextTimeTriggerDate(after: date)
        case .dayOfWeek:
            return nextWeekdayTriggerDate(after: date)
        case .location, .person:
            // Location and person triggers don't have specific fire dates
            return nil
        }
    }
    
    private func nextTimeTriggerDate(after date: Date) -> Date? {
        guard let fireDate = fireDate else { return nil }
        
        if let rule = recurrenceRule {
            return nextRecurringDate(from: fireDate, rule: rule, after: date)
        }
        
        return fireDate >= date ? fireDate : nil
    }
    
    private func nextWeekdayTriggerDate(after date: Date) -> Date? {
        guard let startDate = startDate else { return nil }
        guard weekdayMask > 0 else { return nil }
        
        let calendar = Calendar.current
        var searchDate = max(date, startDate)
        
        // Search up to 14 days ahead for the next matching weekday
        for _ in 0..<14 {
            let weekday = calendar.component(.weekday, from: searchDate)
            let weekdayBit = 1 << (weekday - 1)
            
            if (Int(weekdayMask) & weekdayBit) != 0 {
                // Match found
                let components = calendar.dateComponents([.year, .month, .day], from: searchDate)
                if let fireComponents = fireDate.map({ calendar.dateComponents([.hour, .minute, .second], from: $0) }),
                   let resultDate = calendar.date(from: DateComponents(
                    year: components.year,
                    month: components.month,
                    day: components.day,
                    hour: fireComponents.hour,
                    minute: fireComponents.minute,
                    second: fireComponents.second
                   )) {
                    if resultDate >= date {
                        return resultDate
                    }
                }
            }
            
            searchDate = calendar.date(byAdding: .day, value: 1, to: searchDate) ?? searchDate
        }
        
        return nil
    }
    
    private func nextRecurringDate(from baseDate: Date, rule: RecurrenceRule, after date: Date) -> Date? {
        let calendar = Calendar.current
        var currentDate = baseDate
        
        // If base date is in the future, return it
        if baseDate >= date {
            return baseDate
        }
        
        // Check end conditions
        if let endDate = rule.endDate, endDate < date {
            return nil
        }
        
        // Calculate next occurrence
        let component: Calendar.Component
        switch rule.frequency {
        case .daily: component = .day
        case .weekly: component = .weekOfYear
        case .monthly: component = .month
        case .yearly: component = .year
        }
        
        // Fast-forward to approximate next date
        let timeInterval = date.timeIntervalSince(baseDate)
        let approximateOccurrences: Int
        switch rule.frequency {
        case .daily: approximateOccurrences = Int(timeInterval / 86400)
        case .weekly: approximateOccurrences = Int(timeInterval / (86400 * 7))
        case .monthly: approximateOccurrences = Int(timeInterval / (86400 * 30))
        case .yearly: approximateOccurrences = Int(timeInterval / (86400 * 365))
        }
        
        let skipOccurrences = max(0, (approximateOccurrences / rule.interval) - 1) * rule.interval
        if skipOccurrences > 0,
           let fastForward = calendar.date(byAdding: component, value: skipOccurrences, to: currentDate) {
            currentDate = fastForward
        }
        
        // Find exact next date
        var iterations = 0
        let maxIterations = 100
        
        while currentDate < date && iterations < maxIterations {
            guard let next = calendar.date(byAdding: component, value: rule.interval, to: currentDate) else {
                return nil
            }
            currentDate = next
            iterations += 1
            
            if let endDate = rule.endDate, currentDate > endDate {
                return nil
            }
        }
        
        return currentDate >= date ? currentDate : nil
    }
}
