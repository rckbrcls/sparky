import Foundation

@MainActor
final class RemoteMirrorBuilder {
    let minds: MindService
    let memories: MemoryService
    let attachments: MemoryAttachmentStore
    static let weekdays = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]

    init(minds: MindService, memories: MemoryService, attachments: MemoryAttachmentStore) {
        self.minds = minds
        self.memories = memories
        self.attachments = attachments
    }

    func build() async throws -> MirrorDTO {
        let mindDTOs = minds.minds.sorted { $0.id.uuidString < $1.id.uuidString }.map(mindDTO)
        var memoryDTOs: [MemoryDTO] = []
        for memory in memories.memories.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            memoryDTOs.append(try await memoryDTO(memory))
        }
        return MirrorDTO(syncedAt: Date(), minds: mindDTOs, memories: memoryDTOs)
    }

    func mindDTO(_ mind: Mind) -> MindDTO {
        MindDTO(id: mind.id.uuidString.lowercased(), name: mind.name, colorHex: mind.colorHex,
                iconName: mind.iconName, sortOrder: mind.sortOrder, isDefault: mind.isDefault,
                parentId: mind.parent?.id.uuidString.lowercased(), updatedAt: RemoteJSON.version(updatedAt: mind.updatedAt))
    }

    func memoryDTO(_ memory: Memory) async throws -> MemoryDTO {
        var schedule: ScheduleDTO?
        if let s = memory.scheduleConfig {
            guard let fireDate = s.fireDate else { throw RemoteCommandError.invalid("Schedule has no fire date") }
            let recurrence = s.recurrenceRule.map { r in
                RecurrenceDTO(frequency: r.frequency.rawValue, interval: r.interval,
                    weekdays: r.frequency == .weekly ? Self.weekdays.enumerated().compactMap {
                        s.weekdayMask & (1 << ($0.offset + 1)) != 0 ? $0.element : nil
                    } : [], endDate: s.recurrenceEndType == .untilDate ? r.endDate : nil,
                    occurrenceCount: s.recurrenceEndType == .afterCount ? r.occurrenceCount : nil)
            }
            let hasFocus = s.focusEnabled || s.focusWorkDurationMinutes != 0 || s.focusShortBreakDurationMinutes != 0
                || s.focusLongBreakDurationMinutes != 0 || s.focusPomodorosUntilLongBreak != 0 || !s.focusAutoContinue
            schedule = ScheduleDTO(fireDate: fireDate, isAllDay: s.isAllDay,
                timeZone: s.timeZoneIdentifier ?? TimeZone.current.identifier, isActive: s.isActive, recurrence: recurrence,
                focus: hasFocus ? FocusDTO(enabled: s.focusEnabled, workMinutes: s.focusWorkDurationMinutes,
                    shortBreakMinutes: s.focusShortBreakDurationMinutes, longBreakMinutes: s.focusLongBreakDurationMinutes,
                    pomodorosUntilLongBreak: s.focusPomodorosUntilLongBreak, autoContinue: s.focusAutoContinue) : nil)
        }
        let location = memory.locationConfig.map {
            LocationDTO(name: $0.name ?? "", latitude: $0.latitude, longitude: $0.longitude,
                        radiusMeters: $0.radius, event: $0.event.rawValue, isActive: $0.isActive)
        }
        let links = await attachments.attachments(for: memory.id).filter { $0.kind == .link }.compactMap { a in
            a.url.map { LinkDTO(url: $0.absoluteString, title: a.filename) }
        }
        return MemoryDTO(id: memory.id.uuidString.lowercased(), title: memory.title, note: memory.body,
            status: memory.status.rawValue, isPinned: memory.isPinned, priority: memory.priorityRaw,
            dueDate: memory.dueDate, mindId: memory.mind?.id.uuidString.lowercased(), completedAt: memory.completedAt,
            completedDates: memory.completedDates, autoCompleteOnChecklistCompletion: memory.autoCompleteOnChecklistCompletion,
            checklist: memory.checkItems.sorted { $0.sortOrder == $1.sortOrder ? $0.id.uuidString < $1.id.uuidString : $0.sortOrder < $1.sortOrder }.map {
                ChecklistItemDTO(id: $0.id.uuidString.lowercased(), title: $0.title, detail: $0.detail ?? "",
                                 isCompleted: $0.isCompleted, sortOrder: $0.sortOrder)
            }, schedule: schedule, location: location, links: links,
            createdAt: memory.createdAt ?? Date(timeIntervalSince1970: 0),
            updatedAt: RemoteJSON.version(updatedAt: memory.updatedAt, createdAt: memory.createdAt))
    }
}
