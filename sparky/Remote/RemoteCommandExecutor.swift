import Foundation

enum RemoteCommandError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): message }
    }
}

@MainActor
final class RemoteCommandExecutor {
    private struct Receipt: Codable {
        var id: String
        var date: Date
        var result: CommandResultDTO
        var pending: Bool
    }
    private let builder: RemoteMirrorBuilder
    private let journalURL: URL
    private var receipts: [Receipt] = []
    private var loadError: Error?
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(builder: RemoteMirrorBuilder, journalURL: URL? = nil) {
        self.builder = builder
        self.journalURL = journalURL ?? (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("SparkyRemoteSync/commands.json")
        do {
            if FileManager.default.fileExists(atPath: self.journalURL.path) {
                receipts = try RemoteJSON.decoder().decode([Receipt].self, from: Data(contentsOf: self.journalURL))
            }
            let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
            receipts = Array(receipts.filter { $0.date >= cutoff }.suffix(500))
        } catch { loadError = error }
    }

    private func acquire() async {
        if busy { await withCheckedContinuation { waiters.append($0) } }
        else { busy = true }
    }
    private func release() {
        if waiters.isEmpty { busy = false }
        else { waiters.removeFirst().resume() }
    }

    private func save() throws {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        receipts = Array(receipts.filter { $0.date >= cutoff }.suffix(500))
        try FileManager.default.createDirectory(at: journalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try RemoteJSON.encoder().encode(receipts).write(to: journalURL, options: .atomic)
    }

    func pendingResults() -> [(String, CommandResultDTO)] {
        receipts.filter(\.pending).map { ($0.id, $0.result) }
    }

    func markReported(_ id: String) throws {
        if let index = receipts.firstIndex(where: { $0.id == id }) {
            receipts[index].pending = false
            try save()
        }
    }

    func execute(_ command: CommandDTO) async -> CommandResultDTO {
        do { return try await executeStored(command) }
        catch {
            return CommandResultDTO(status: "failed", result: .object([:]),
                error: "Command history is unavailable; inspect the current entity before retrying")
        }
    }

    private func executeStored(_ command: CommandDTO) async throws -> CommandResultDTO {
        await acquire()
        defer { release() }
        if let loadError { throw loadError }
        guard let uuid = UUID(uuidString: command.id) else { throw RemoteCommandError.invalid("Invalid command ID") }
        let id = uuid.uuidString.lowercased()
        if let receipt = receipts.first(where: { $0.id == id }) { return receipt.result }
        // Persist an intent before mutation. After an interrupted application, fail closed rather than execute twice.
        let interrupted = CommandResultDTO(status: "failed", result: .object([:]),
            error: "Command application was interrupted; inspect the current entity before retrying")
        receipts.append(Receipt(id: id, date: Date(), result: interrupted, pending: true))
        try save()
        let result: CommandResultDTO
        do { result = try await apply(command) }
        catch { result = CommandResultDTO(status: "failed", result: .object([:]), error: error.localizedDescription) }
        if let index = receipts.firstIndex(where: { $0.id == id }) { receipts[index].result = result }
        try save()
        return result
    }

    private func result<T: Encodable>(_ key: String, _ value: T, status: String = "done") throws -> CommandResultDTO {
        CommandResultDTO(status: status, result: .object([key: try .from(value)]), error: nil)
    }

    private func object(_ value: RemoteJSONValue) throws -> [String: RemoteJSONValue] {
        guard case .object(let object) = value else { throw RemoteCommandError.invalid("Expected an object") }
        return object
    }
    private func decode<T: Decodable>(_ value: RemoteJSONValue, as type: T.Type = T.self) throws -> T {
        try RemoteJSON.decoder().decode(type, from: RemoteJSON.encoder().encode(value))
    }
    private func parent(_ id: String?) throws -> Mind? {
        guard let id else { return nil }
        guard let uuid = UUID(uuidString: id), let mind = builder.minds.mind(id: uuid) else {
            throw RemoteCommandError.invalid("Mind not found")
        }
        return mind
    }

    private func apply(_ command: CommandDTO) async throws -> CommandResultDTO {
        let payload = try object(command.payload)
        if command.type == "memory.create" {
            var fields = try object(.from(MemoryDTO(id: UUID().uuidString.lowercased(), title: "", note: nil,
                status: "active", isPinned: false, priority: nil, dueDate: nil, mindId: nil, completedAt: nil,
                completedDates: [], autoCompleteOnChecklistCompletion: false, checklist: [], schedule: nil,
                location: nil, links: [], createdAt: Date(), updatedAt: Date())))
            let allowed: Set<String> = ["title", "note", "isPinned", "priority", "dueDate", "mindId",
                "autoCompleteOnChecklistCompletion", "checklist", "schedule", "location", "links"]
            guard Set(payload.keys).isSubset(of: allowed) else { throw RemoteCommandError.invalid("Unsupported memory create field") }
            fields.merge(payload) { _, new in new }
            try normalizeChecklist(&fields)
            let dto: MemoryDTO = try decode(.object(fields))
            let draft = try makeDraft(dto, attachments: [])
            let memory = try await builder.memories.createMemory(from: draft)
            if dto.priority != nil { try await builder.memories.setRemoteMetadata(memoryID: memory.id, priority: dto.priority) }
            return try await result("memory", builder.memoryDTO(memory))
        }
        if command.type == "mind.create" {
            guard let nameValue = payload["name"] else { throw RemoteCommandError.invalid("Mind name is required") }
            let name: String = try decode(nameValue)
            let color: String? = try payload["colorHex"].map { try decode($0, as: String?.self) } ?? nil
            let icon: String? = try payload["iconName"].map { try decode($0, as: String?.self) } ?? nil
            let parentID: String? = try payload["parentId"].map { try decode($0, as: String?.self) } ?? nil
            let sortOrder: Int? = try payload["sortOrder"].map { try decode($0) }
            let mind = try await builder.minds.createMind(name: name, colorHex: color, iconName: icon,
                                                         isDefault: false, parent: parent(parentID))
            if let sortOrder {
                mind.sortOrder = sortOrder
                _ = try await builder.minds.updateMind(mind)
            }
            return try result("mind", builder.mindDTO(mind))
        }
        guard let target = command.targetId.flatMap(UUID.init(uuidString:)) else {
            throw RemoteCommandError.invalid("Target not found")
        }
        if command.type.hasPrefix("memory.") {
            guard let memory = builder.memories.memory(id: target) else { throw RemoteCommandError.invalid("Target not found") }
            guard let baseVersion = command.baseVersion else { throw RemoteCommandError.invalid("Base version is required") }
            if RemoteJSON.version(updatedAt: memory.updatedAt, createdAt: memory.createdAt) != baseVersion {
                return try await result("memory", builder.memoryDTO(memory), status: "conflict")
            }
            switch command.type {
            case "memory.update":
                let patch = try object(payload["patch"] ?? .null)
                let allowed: Set<String> = ["title", "note", "status", "isPinned", "priority", "dueDate", "mindId",
                    "completedAt", "completedDates", "autoCompleteOnChecklistCompletion", "checklist", "schedule", "location", "links"]
                guard Set(patch.keys).isSubset(of: allowed) else { throw RemoteCommandError.invalid("Unsupported memory patch field") }
                let current = try await builder.memoryDTO(memory)
                var fields = try object(.from(current))
                fields.merge(patch) { _, new in new }
                try normalizeChecklist(&fields)
                let dto: MemoryDTO = try decode(.object(fields))
                let attachments = await builder.attachments.attachments(for: target)
                var draft = try makeDraft(dto, attachments: attachments, replaceLinks: patch["links"] != nil)
                // Preserve fields that the wire contract cannot represent when they were not patched.
                if patch["schedule"] == nil { draft.scheduleConfig = memory.scheduleConfig.map(ScheduleConfigDraft.from) }
                if patch["location"] == nil { draft.locationConfig = memory.locationConfig.map(LocationConfigDraft.from) }
                if patch["checklist"] == nil {
                    draft.checkItems = memory.checkItems.map { CheckItemDraft(id: $0.id, title: $0.title, detail: $0.detail ?? "",
                        isCompleted: $0.isCompleted, sortOrder: $0.sortOrder, createdAt: $0.createdAt, completedAt: $0.completedAt) }
                }
                _ = try await builder.memories.updateMemory(from: draft)
                if patch["priority"] != nil || patch["completedAt"] != nil {
                    try await builder.memories.setRemoteMetadata(memoryID: target, priority: dto.priority,
                        completedAt: dto.completedAt, replaceCompletedAt: patch["completedAt"] != nil)
                }
            case "memory.setStatus":
                let statusValue: String = try decode(payload["status"] ?? .null)
                guard let status = MemoryStatus(rawValue: statusValue) else { throw RemoteCommandError.invalid("Invalid status") }
                let date: Date? = try payload["occurrenceDate"].map { try decode($0, as: Date?.self) } ?? nil
                if let date {
                    let calendar = Calendar.current
                    let completed = memory.completedDates.contains {
                        calendar.isDate($0, inSameDayAs: date) && (!memory.hasIntraDayRecurrence ||
                            (calendar.component(.hour, from: $0) == calendar.component(.hour, from: date) &&
                             calendar.component(.minute, from: $0) == calendar.component(.minute, from: date)))
                    }
                    if completed != (status == .completed) {
                        try await builder.memories.toggleCompletionForDate(memoryID: target, date: date)
                    } else {
                        // Even an already satisfied command must advance the entity version.
                        try await builder.memories.setRemoteMetadata(memoryID: target, priority: memory.priorityRaw)
                    }
                } else { try await builder.memories.setStatus(memoryID: target, status: status) }
            case "memory.toggleCheckItem":
                let item: String = try decode(payload["itemId"] ?? .null)
                guard let itemID = UUID(uuidString: item), memory.checkItems.contains(where: { $0.id == itemID }) else {
                    throw RemoteCommandError.invalid("Checklist item not found")
                }
                let date: Date? = try payload["occurrenceDate"].map { try decode($0, as: Date?.self) } ?? nil
                try await builder.memories.toggleChecklistItemCompletion(memoryID: target, itemID: itemID, date: date)
            case "memory.delete":
                try await builder.memories.deleteMemory(id: target)
                return try result("deletedId", target.uuidString.lowercased())
            default: throw RemoteCommandError.invalid("Unknown command type")
            }
            return try await result("memory", builder.memoryDTO(memory))
        }
        guard command.type.hasPrefix("mind."), let mind = builder.minds.mind(id: target) else {
            throw RemoteCommandError.invalid("Target not found")
        }
        guard let baseVersion = command.baseVersion else { throw RemoteCommandError.invalid("Base version is required") }
        if RemoteJSON.version(updatedAt: mind.updatedAt) != baseVersion {
            return try result("mind", builder.mindDTO(mind), status: "conflict")
        }
        switch command.type {
        case "mind.update":
            let patch = try object(payload["patch"] ?? .null)
            guard Set(patch.keys).isSubset(of: ["name", "colorHex", "iconName", "sortOrder", "parentId"]) else {
                throw RemoteCommandError.invalid("Unsupported mind patch field")
            }
            var fields = try object(.from(builder.mindDTO(mind)))
            fields.merge(patch) { _, new in new }
            let dto: MindDTO = try decode(.object(fields))
            guard !dto.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RemoteCommandError.invalid("Mind name is required")
            }
            let newParent = try parent(dto.parentId)
            if let newParent, mind.allDescendantIDs.contains(newParent.id) { throw RemoteCommandError.invalid("Mind parent would create a cycle") }
            mind.name = dto.name
            mind.colorHex = dto.colorHex
            mind.iconName = dto.iconName
            mind.sortOrder = dto.sortOrder
            mind.parent = newParent
            _ = try await builder.minds.updateMind(mind)
            return try result("mind", builder.mindDTO(mind))
        case "mind.delete":
            try await builder.minds.deleteMind(mind)
            _ = await builder.memories.refresh(force: true)
            return try result("deletedId", target.uuidString.lowercased())
        default: throw RemoteCommandError.invalid("Unknown command type")
        }
    }

    private func normalizeChecklist(_ fields: inout [String: RemoteJSONValue]) throws {
        guard case .array(let items) = fields["checklist"] else { return }
        var ids: Set<UUID> = []
        fields["checklist"] = .array(try items.enumerated().map { index, value in
            var item = try object(value)
            if item["id"] == nil { item["id"] = .string(UUID().uuidString.lowercased()) }
            let id: String = try decode(item["id"] ?? .null)
            guard let uuid = UUID(uuidString: id), ids.insert(uuid).inserted else { throw RemoteCommandError.invalid("Invalid or duplicate checklist ID") }
            if item["detail"] == nil { item["detail"] = .string("") }
            if item["isCompleted"] == nil { item["isCompleted"] = .bool(false) }
            if item["sortOrder"] == nil { item["sortOrder"] = .number(Double(index)) }
            return .object(item)
        })
    }

    private func makeDraft(_ dto: MemoryDTO, attachments: [Memory.Attachment], replaceLinks: Bool = true) throws -> MemoryDraft {
        guard let id = UUID(uuidString: dto.id), let status = MemoryStatus(rawValue: dto.status),
              !dto.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RemoteCommandError.invalid("Invalid memory") }
        let mind = try parent(dto.mindId)
        var allAttachments = attachments
        if replaceLinks {
            allAttachments.removeAll { $0.kind == .link }
            for link in dto.links {
                guard let url = URL(string: link.url), url.scheme != nil else { throw RemoteCommandError.invalid("Invalid link URL") }
                allAttachments.append(Memory.Attachment(kind: .link, data: Data(), createdAt: Date(), url: url, filename: link.title))
            }
        }
        var schedule: ScheduleConfigDraft?
        if let s = dto.schedule {
            guard TimeZone(identifier: s.timeZone) != nil else { throw RemoteCommandError.invalid("Invalid time zone") }
            var rule: RecurrenceRule?
            var mask: Int16 = 0
            var endType: RecurrenceEndType = .never
            if let r = s.recurrence {
                guard let frequency = RecurrenceFrequency(rawValue: r.frequency), r.interval > 0,
                      !(r.endDate != nil && r.occurrenceCount != nil), r.occurrenceCount.map({ $0 > 0 }) ?? true,
                      r.weekdays.allSatisfy(RemoteMirrorBuilder.weekdays.contains),
                      frequency == .weekly || r.weekdays.isEmpty else { throw RemoteCommandError.invalid("Invalid recurrence") }
                for day in r.weekdays {
                    if let index = RemoteMirrorBuilder.weekdays.firstIndex(of: day) { mask |= 1 << (index + 1) }
                }
                rule = RecurrenceRule(frequency: frequency, interval: r.interval, endDate: r.endDate, occurrenceCount: r.occurrenceCount)
                endType = r.endDate != nil ? .untilDate : r.occurrenceCount != nil ? .afterCount : .never
            }
            if let f = s.focus {
                guard f.workMinutes >= 0, f.shortBreakMinutes >= 0, f.longBreakMinutes >= 0, f.pomodorosUntilLongBreak >= 0 else {
                    throw RemoteCommandError.invalid("Invalid focus configuration")
                }
            }
            schedule = ScheduleConfigDraft(fireDate: s.fireDate, startDate: s.fireDate, recurrenceRule: rule,
                timeZoneIdentifier: s.timeZone, weekdayMask: mask, isActive: s.isActive, isAllDay: s.isAllDay,
                recurrenceEndType: endType, focusEnabled: s.focus?.enabled ?? false, focusWorkDurationMinutes: s.focus?.workMinutes ?? 0,
                focusShortBreakDurationMinutes: s.focus?.shortBreakMinutes ?? 0, focusLongBreakDurationMinutes: s.focus?.longBreakMinutes ?? 0,
                focusPomodorosUntilLongBreak: s.focus?.pomodorosUntilLongBreak ?? 0, focusAutoContinue: s.focus?.autoContinue ?? true)
        }
        var location: LocationConfigDraft?
        if let l = dto.location {
            guard let event = LocationEvent(rawValue: l.event), (-90...90).contains(l.latitude),
                  (-180...180).contains(l.longitude), l.radiusMeters > 0 else { throw RemoteCommandError.invalid("Invalid location") }
            location = LocationConfigDraft(latitude: l.latitude, longitude: l.longitude, radius: l.radiusMeters,
                                           name: l.name.isEmpty ? nil : l.name, event: event, isActive: l.isActive)
        }
        return MemoryDraft(id: id, title: dto.title, status: status, isPinned: dto.isPinned, dueDate: dto.dueDate,
            mindID: mind?.id, scheduleConfig: schedule, locationConfig: location, note: dto.note,
            checkItems: try dto.checklist.map {
                guard let id = UUID(uuidString: $0.id) else { throw RemoteCommandError.invalid("Invalid checklist ID") }
                return CheckItemDraft(id: id, title: $0.title, detail: $0.detail, isCompleted: $0.isCompleted, sortOrder: $0.sortOrder)
            }, photoAttachmentIDs: allAttachments.filter { $0.kind == .photo }.map(\.id),
            linkAttachmentIDs: allAttachments.filter { $0.kind == .link }.map(\.id),
            audioAttachmentIDs: allAttachments.filter { $0.kind == .audio }.map(\.id),
            fileAttachmentIDs: allAttachments.filter { $0.kind == .file }.map(\.id), attachments: allAttachments,
            autoCompleteOnChecklistCompletion: dto.autoCompleteOnChecklistCompletion, completedAt: dto.completedAt, completedDates: dto.completedDates)
    }
}
