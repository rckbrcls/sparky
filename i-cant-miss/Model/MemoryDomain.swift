//
//  MemoryDomain.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import Foundation

typealias MemoryTriggerModel = ReminderTriggerModel
typealias MemoryTriggerDraft = ReminderTriggerDraft

enum MemoryStatus: String, CaseIterable, Identifiable, Codable {
    case active
    case completed
    case archived

    var id: String { rawValue }

    var isTerminal: Bool { self == .archived }
}

enum MemoryPriority: Int16, CaseIterable, Identifiable, Codable {
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

struct MemoryModel: Identifiable, Hashable {
    struct AttachmentKind: RawRepresentable, Hashable, Codable {
        let rawValue: String

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        static let photo = AttachmentKind(rawValue: "photo")
        static let link = AttachmentKind(rawValue: "link")
    }

    struct Attachment: Identifiable, Hashable {
        let id: UUID
        var kind: AttachmentKind
        var data: Data
        var createdAt: Date
        var url: URL?

        init(id: UUID = UUID(),
             kind: AttachmentKind,
             data: Data,
             createdAt: Date,
             url: URL? = nil) {
            self.id = id
            self.kind = kind
            self.data = data
            self.createdAt = createdAt
            self.url = url
        }

        static func == (lhs: Attachment, rhs: Attachment) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    struct Metadata: Hashable {
        enum Origin: Hashable {
            case reminder(UUID)
            case note(UUID)
            case todoList(UUID)
        }

        var origin: Origin?
        var legacyStatus: ReminderStatus?
        var legacyAudience: FolderAudience?
        var autoCompleteOnChecklistCompletion: Bool

        init(origin: Origin? = nil,
             legacyStatus: ReminderStatus? = nil,
             legacyAudience: FolderAudience? = nil,
             autoCompleteOnChecklistCompletion: Bool = false) {
            self.origin = origin
            self.legacyStatus = legacyStatus
            self.legacyAudience = legacyAudience
            self.autoCompleteOnChecklistCompletion = autoCompleteOnChecklistCompletion
        }
    }

    let id: UUID
    var title: String
    var body: String?
    var createdAt: Date
    var updatedAt: Date
    var status: MemoryStatus
    var isPinned: Bool
    var priority: MemoryPriority?
    var dueDate: Date?
    var space: SpaceModel
    var triggers: [MemoryTriggerModel]
    var checkItems: [CheckItemModel]
    var snoozeCount: Int
    var lastCompletionDate: Date?
    var metadata: Metadata
    var attachments: [Attachment]

    var hasChecklist: Bool {
        !checkItems.isEmpty
    }

    var hasTriggers: Bool {
        triggers.contains { $0.isActive }
    }

    var hasRecurringTriggers: Bool {
        triggers.contains { $0.recurrenceRule != nil }
    }

    var hasAttachments: Bool {
        !attachments.isEmpty
    }

    var isCompleted: Bool {
        status == .completed
    }

    func nextFireDate(referenceDate: Date = Date()) -> Date? {
        let activeTriggers = triggers.filter { $0.isActive }
        guard !activeTriggers.isEmpty else { return nil }

        var nextDates: [Date] = []
        for trigger in activeTriggers {
            if let date = trigger.nextFireDate(after: referenceDate) {
                nextDates.append(date)
            }
        }

        return nextDates.min()
    }

    func shouldAutoCompleteChecklist(autoCompleteEnabled: Bool) -> Bool {
        metadata.autoCompleteOnChecklistCompletion || autoCompleteEnabled
    }
}

struct CheckItemModel: Identifiable, Hashable {
    let id: UUID
    var title: String
    var detail: String?
    var isCompleted: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
}

struct CheckItemDraft: Identifiable, Hashable {
    let id: UUID
    var title: String
    var detail: String
    var isCompleted: Bool
    var sortOrder: Int
    var createdAt: Date
    var completedAt: Date?

    init(id: UUID = UUID(),
         title: String = "",
         detail: String = "",
         isCompleted: Bool = false,
         sortOrder: Int = 0,
         createdAt: Date = Date(),
         completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

struct SpaceModel: Identifiable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String?
    var iconName: String?
    var sortOrder: Int
    var parentID: UUID?
    var childIDs: [UUID]
    var isDefault: Bool
    var legacyFolder: FolderModel?

    init(id: UUID,
         name: String,
         colorHex: String? = nil,
         iconName: String? = nil,
         sortOrder: Int = 0,
         parentID: UUID? = nil,
         childIDs: [UUID] = [],
         isDefault: Bool = false,
         legacyFolder: FolderModel? = nil) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.parentID = parentID
        self.childIDs = childIDs
        self.isDefault = isDefault
        self.legacyFolder = legacyFolder
    }

    var isRoot: Bool { parentID == nil }
    var hasChildren: Bool { !childIDs.isEmpty }
}

extension SpaceModel {
    static let allSpacesIdentifier = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    static let inboxIdentifier = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    static var allSpaces: SpaceModel {
        SpaceModel(
            id: allSpacesIdentifier,
            name: "All",
            colorHex: nil,
            iconName: "square.grid.2x2",
            sortOrder: Int.min,
            parentID: nil,
            childIDs: [],
            isDefault: true,
            legacyFolder: nil
        )
    }

    static var inbox: SpaceModel {
        SpaceModel(
            id: inboxIdentifier,
            name: "Inbox",
            colorHex: nil,
            iconName: "tray",
            sortOrder: Int.min,
            parentID: nil,
            childIDs: [],
            isDefault: true,
            legacyFolder: nil
        )
    }

    var isAllSpaces: Bool {
        id == SpaceModel.allSpacesIdentifier
    }

    func isAncestor(of space: SpaceModel, using lookup: (UUID) -> SpaceModel?) -> Bool {
        guard let parentID else { return false }
        if parentID == space.id { return true }
        guard let parent = lookup(parentID) else { return false }
        return parent.isAncestor(of: space, using: lookup)
    }
}

extension FolderModel {
    func toSpace(parentID: UUID? = nil, childIDs: [UUID] = []) -> SpaceModel {
        SpaceModel(
            id: id,
            name: name,
            colorHex: colorHex,
            iconName: iconName,
            sortOrder: sortOrder,
            parentID: parentID ?? self.parentID,
            childIDs: childIDs.isEmpty ? self.childIDs : childIDs,
            isDefault: isDefault,
            legacyFolder: self
        )
    }
}

extension TodoItemModel {
    func toCheckItem() -> CheckItemModel {
        CheckItemModel(
            id: id,
            title: title,
            detail: detail,
            isCompleted: isCompleted,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: completedAt ?? createdAt,
            completedAt: completedAt
        )
    }
}

extension CheckItemDraft {
    func toModel(at index: Int) -> TodoItemModel {
        TodoItemModel(
            id: id,
            title: title,
            detail: detail.isEmpty ? nil : detail,
            isCompleted: isCompleted,
            sortOrder: index,
            createdAt: createdAt,
            completedAt: isCompleted ? (completedAt ?? Date()) : nil
        )
    }
}

private extension Sequence where Element == TodoItemModel {
    func toCheckItems() -> [CheckItemModel] {
        map { $0.toCheckItem() }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.createdAt < rhs.createdAt
            }
    }
}

extension ReminderModel {
    func toMemory(space: SpaceModel?) -> MemoryModel {
        let space = space ?? folder?.toSpace() ?? SpaceModel.allSpaces
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty ? "Untitled" : trimmedTitle
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasNotes = !(trimmedNotes?.isEmpty ?? true)
        return MemoryModel(
            id: id,
            title: resolvedTitle,
            body: hasNotes ? notes : nil,
            createdAt: createdAt,
            updatedAt: updatedAt,
            status: status == .archived ? .archived : (status == .completed ? .completed : .active),
            isPinned: false,
            priority: MemoryPriority(rawValue: priority.rawValue),
            dueDate: nil,
            space: space,
            triggers: triggers,
            checkItems: [],
            snoozeCount: snoozeCount,
            lastCompletionDate: lastCompletionDate,
            metadata: MemoryModel.Metadata(
                origin: .reminder(id),
                legacyStatus: status,
                legacyAudience: folder?.audience,
                autoCompleteOnChecklistCompletion: false
            ),
            attachments: []
        )
    }
}

extension NoteModel {
    func toMemory(space: SpaceModel?) -> MemoryModel {
        let resolvedSpace = space ?? folder?.toSpace() ?? SpaceModel.allSpaces
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle ?? (trimmedContent.isEmpty ? "Untitled" : trimmedContent)
        let hasContent = !trimmedContent.isEmpty
        return MemoryModel(
            id: id,
            title: resolvedTitle,
            body: hasContent ? content : nil,
            createdAt: createdAt,
            updatedAt: updatedAt,
            status: .active,
            isPinned: isPinned,
            priority: nil,
            dueDate: nil,
            space: resolvedSpace,
            triggers: [],
            checkItems: [],
            snoozeCount: 0,
            lastCompletionDate: nil,
            metadata: MemoryModel.Metadata(
                origin: .note(id),
                legacyAudience: folder?.audience,
                autoCompleteOnChecklistCompletion: false
            ),
            attachments: []
        )
    }
}

extension TodoListModel {
    func toMemory(space: SpaceModel?) -> MemoryModel {
        let resolvedSpace = space ?? folder?.toSpace() ?? SpaceModel.allSpaces
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty ? "Untitled" : trimmedTitle
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasNotes = !(trimmedNotes?.isEmpty ?? true)
        return MemoryModel(
            id: id,
            title: resolvedTitle,
            body: hasNotes ? notes : nil,
            createdAt: createdAt,
            updatedAt: updatedAt,
            status: isArchived ? .archived : (isCompleted ? .completed : .active),
            isPinned: isPinned,
            priority: nil,
            dueDate: dueDate,
            space: resolvedSpace,
            triggers: [],
            checkItems: items.toCheckItems(),
            snoozeCount: 0,
            lastCompletionDate: nil,
            metadata: MemoryModel.Metadata(
                origin: .todoList(id),
                legacyAudience: folder?.audience,
                autoCompleteOnChecklistCompletion: true
            ),
            attachments: []
        )
    }
}
