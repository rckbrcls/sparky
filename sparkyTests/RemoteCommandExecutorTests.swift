import Foundation
import SwiftData
import Testing
@testable import sparky

/// Remote tests deliberately avoid AppEnvironment, production attachments, settings and keychain.
@MainActor
final class RemoteTestFixture {
    let root: URL
    let data: DataController
    let minds: MindService
    let memories: MemoryService
    let attachments: MemoryAttachmentStore
    let builder: RemoteMirrorBuilder
    let executor: RemoteCommandExecutor
    var journal: URL { root.appendingPathComponent("commands.json") }

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("SparkyRemoteTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        data = DataController(inMemory: true)
        attachments = MemoryAttachmentStore(rootDirectory: root.appendingPathComponent("attachments"))
        minds = MindService(dataController: data)
        memories = MemoryService(dataController: data, mindService: minds, attachmentStore: attachments)
        builder = RemoteMirrorBuilder(minds: minds, memories: memories, attachments: attachments)
        executor = RemoteCommandExecutor(builder: builder, journalURL: root.appendingPathComponent("commands.json"))
    }

    func cleanup() { try? FileManager.default.removeItem(at: root) }

    func command(_ type: String, target: String? = nil, version: Date? = nil,
                 payload: [String: RemoteJSONValue] = [:], id: String = UUID().uuidString) -> CommandDTO {
        CommandDTO(id: id, type: type, targetId: target, baseVersion: version,
                   payload: .object(payload), createdAt: Date())
    }

    func decode<T: Decodable>(_ result: CommandResultDTO, key: String, as: T.Type) throws -> T {
        #expect(result.status == "done", "Command error: \(result.error ?? "none")")
        guard case .object(let fields) = result.result else { throw RemoteCommandError.invalid("Missing result object") }
        let value = try #require(fields[key])
        return try RemoteJSON.decoder().decode(T.self, from: RemoteJSON.encoder().encode(value))
    }

    func createMemory(_ fields: [String: RemoteJSONValue] = [:]) async throws -> MemoryDTO {
        var payload: [String: RemoteJSONValue] = ["title": .string("Remote memory")]
        payload.merge(fields) { _, new in new }
        return try decode(await executor.execute(command("memory.create", payload: payload)), key: "memory", as: MemoryDTO.self)
    }

    func createMind(_ name: String, parent: String? = nil) async throws -> MindDTO {
        var payload: [String: RemoteJSONValue] = ["name": .string(name)]
        if let parent { payload["parentId"] = .string(parent) }
        return try decode(await executor.execute(command("mind.create", payload: payload)), key: "mind", as: MindDTO.self)
    }

    func update(_ memory: MemoryDTO, _ patch: [String: RemoteJSONValue]) async throws -> MemoryDTO {
        try decode(await executor.execute(command("memory.update", target: memory.id, version: memory.updatedAt,
                                                 payload: ["patch": .object(patch)])), key: "memory", as: MemoryDTO.self)
    }

    func schedule(_ frequency: String = "daily", count: Int? = nil) throws -> RemoteJSONValue {
        .object([
            "fireDate": try .from(Date(timeIntervalSince1970: 1_709_251_200)), "isAllDay": .bool(false),
            "timeZone": .string("America/Sao_Paulo"), "isActive": .bool(false),
            "recurrence": .object([
                "frequency": .string(frequency), "interval": .number(2),
                "weekdays": .array(frequency == "weekly" ? [.string("mon"), .string("fri")] : []),
                "endDate": .null, "occurrenceCount": count.map { .number(Double($0)) } ?? .null
            ]),
            "focus": try .from(FocusDTO(enabled: true, workMinutes: 25, shortBreakMinutes: 5,
                                       longBreakMinutes: 15, pomodorosUntilLongBreak: 4, autoContinue: false))
        ])
    }
}

@MainActor
struct RemoteCommandExecutorTests {
    @Test func memoryCRUDPreservesOmittedFieldsClearsNullsAndPersists() async throws {
        let f = try RemoteTestFixture(); defer { f.cleanup() }
        let mind = try await f.createMind("Research")
        let due = Date(timeIntervalSince1970: 1_800_000_000)
        var memory = try await f.createMemory([
            "title": .string("Unicode café 🧠"), "note": .string("Original note"), "isPinned": .bool(true),
            "priority": .number(2), "dueDate": try .from(due), "mindId": .string(mind.id),
            "schedule": try f.schedule("weekly"),
            "location": try .from(LocationDTO(name: "Office", latitude: -23.55, longitude: -46.63,
                                               radiusMeters: 250, event: "onEntry", isActive: false)),
            "links": try .from([LinkDTO(url: "https://example.com/reference", title: "Reference")])
        ])
        let initialVersion = memory.updatedAt
        memory = try await f.update(memory, ["title": .string("Renamed")])
        #expect(memory.note == "Original note")
        #expect(memory.priority == 2)
        #expect(memory.isPinned)
        #expect(memory.dueDate == due)
        #expect(memory.mindId == mind.id)
        #expect(memory.links.first?.title == "Reference")
        #expect(memory.schedule?.focus?.workMinutes == 25)
        #expect(memory.location?.radiusMeters == 250)
        #expect(memory.updatedAt >= initialVersion)
        memory = try await f.update(memory, ["note": .null, "priority": .null, "dueDate": .null, "mindId": .null,
                                            "schedule": .null, "location": .null, "links": .array([]), "isPinned": .bool(false)])
        #expect(memory.note == nil && memory.priority == nil && memory.dueDate == nil && memory.mindId == nil)
        #expect(memory.schedule == nil && memory.location == nil && memory.links.isEmpty)
        #expect(!memory.isPinned)
        memory = try await f.update(memory, ["mindId": .string(mind.id)])
        let persisted = try f.data.newBackgroundContext().fetch(FetchDescriptor<Memory>())
        #expect(persisted.contains { $0.id.uuidString.lowercased() == memory.id && $0.title == "Renamed" })
        for status in ["completed", "active"] {
            memory = try f.decode(await f.executor.execute(f.command("memory.setStatus", target: memory.id,
                version: memory.updatedAt, payload: ["status": .string(status)])), key: "memory", as: MemoryDTO.self)
            #expect(memory.status == status)
            #expect((memory.completedAt != nil) == (status == "completed"))
        }
        let deleted = await f.executor.execute(f.command("memory.delete", target: memory.id, version: memory.updatedAt))
        #expect(deleted.status == "done")
        let mirror = try await f.builder.build()
        #expect(!mirror.memories.contains { $0.id == memory.id })
        let attachments = await f.attachments.attachments(for: UUID(uuidString: memory.id)!)
        #expect(attachments.isEmpty)
    }

    @Test func memoryDefaultsAndExplicitCompletionMetadata() async throws {
        let f = try RemoteTestFixture(); defer { f.cleanup() }
        var memory = try await f.createMemory()
        #expect(memory.status == "active" && !memory.isPinned)
        #expect(memory.note == nil && memory.priority == nil && memory.dueDate == nil && memory.mindId == nil)
        #expect(memory.completedAt == nil && memory.completedDates.isEmpty)
        #expect(!memory.autoCompleteOnChecklistCompletion && memory.checklist.isEmpty)
        #expect(memory.schedule == nil && memory.location == nil && memory.links.isEmpty)
        let completedAt = Date(timeIntervalSince1970: 1_800_000_000)
        memory = try await f.update(memory, ["status": .string("completed"), "completedAt": try .from(completedAt),
            "completedDates": try .from([completedAt]), "autoCompleteOnChecklistCompletion": .bool(true)])
        #expect(memory.status == "completed" && memory.completedAt == completedAt)
        #expect(memory.completedDates == [completedAt] && memory.autoCompleteOnChecklistCompletion)
        memory = try await f.update(memory, ["status": .string("active"), "completedAt": .null,
                                             "completedDates": .array([]), "autoCompleteOnChecklistCompletion": .bool(false)])
        #expect(memory.status == "active" && memory.completedAt == nil && memory.completedDates.isEmpty)
        #expect(!memory.autoCompleteOnChecklistCompletion)
        let invalidStatus = await f.executor.execute(f.command("memory.setStatus", target: memory.id,
            version: memory.updatedAt, payload: ["status": .string("invalid")]))
        #expect(invalidStatus.status == "failed")
        let unsupportedPatch = await f.executor.execute(f.command("memory.update", target: memory.id,
            version: memory.updatedAt, payload: ["patch": .object(["createdAt": try .from(completedAt)])]))
        #expect(unsupportedPatch.status == "failed")
    }

    @Test func hierarchyMoveDetachCyclesAndRecursiveDeletion() async throws {
        let f = try RemoteTestFixture(); defer { f.cleanup() }
        let root = try await f.createMind("Root")
        var child = try await f.createMind("Child", parent: root.id)
        let grandchild = try await f.createMind("Grandchild", parent: child.id)
        var memories: [MemoryDTO] = []
        for mind in [root, child, grandchild] { memories.append(try await f.createMemory(["mindId": .string(mind.id)])) }
        for parent in [root.id, grandchild.id] {
            let invalid = await f.executor.execute(f.command("mind.update", target: root.id, version: root.updatedAt,
                payload: ["patch": .object(["parentId": .string(parent)])]))
            #expect(invalid.status == "failed")
        }
        let missing = await f.executor.execute(f.command("mind.create", payload: ["name": .string("Missing parent"), "parentId": .string(UUID().uuidString)]))
        #expect(missing.status == "failed")
        child = try f.decode(await f.executor.execute(f.command("mind.update", target: child.id, version: child.updatedAt,
            payload: ["patch": .object(["name": .string("Renamed child"), "parentId": .null,
                                        "colorHex": .string("#112233"), "iconName": .string("star"), "sortOrder": .number(7)])])), key: "mind", as: MindDTO.self)
        #expect(child.parentId == nil && child.name == "Renamed child" && child.sortOrder == 7)
        #expect(child.colorHex == "#112233" && child.iconName == "star")
        child = try f.decode(await f.executor.execute(f.command("mind.update", target: child.id, version: child.updatedAt,
            payload: ["patch": .object(["parentId": .string(root.id), "colorHex": .null, "iconName": .null])])), key: "mind", as: MindDTO.self)
        #expect(child.parentId == root.id && child.colorHex == nil && child.iconName == nil)
        let deleted = await f.executor.execute(f.command("mind.delete", target: root.id, version: root.updatedAt))
        #expect(deleted.status == "done")
        let mirror = try await f.builder.build()
        #expect(!mirror.minds.contains { [root.id, child.id, grandchild.id].contains($0.id) })
        for original in memories {
            let inboxMemory = try #require(mirror.memories.first { $0.id == original.id })
            #expect(inboxMemory.mindId == nil)
            #expect(inboxMemory.updatedAt >= original.updatedAt)
        }
    }

    @Test func checklistIdentityEditOrderReplacementAndMissingIDs() async throws {
        let f = try RemoteTestFixture(); defer { f.cleanup() }
        var memory = try await f.createMemory(["checklist": .array([
            .object(["title": .string("First")]), .object(["title": .string("Second")])])])
        #expect(memory.checklist.count == 2)
        let first = memory.checklist[0].id
        let second = memory.checklist[1].id
        #expect(UUID(uuidString: first) != nil && first != second)
        #expect(memory.checklist.map(\.sortOrder) == [0, 1])
        memory = try await f.update(memory, ["note": .string("Preserve checklist")])
        #expect(memory.checklist.map(\.id) == [first, second])
        memory = try await f.update(memory, ["checklist": .array([
            .object(["id": .string(first), "title": .string("Edited"), "detail": .string("Detail"), "sortOrder": .number(3)]),
            .object(["id": .string(second), "title": .string("Second"), "sortOrder": .number(0)]),
            .object(["title": .string("Third"), "sortOrder": .number(1)])])])
        #expect(memory.checklist.map(\.title) == ["Second", "Third", "Edited"])
        #expect(memory.checklist.last?.id == first && memory.checklist.last?.detail == "Detail")
        let missing = await f.executor.execute(f.command("memory.toggleCheckItem", target: memory.id, version: memory.updatedAt,
                                                       payload: ["itemId": .string(UUID().uuidString)]))
        #expect(missing.status == "failed")
        let duplicate = await f.executor.execute(f.command("memory.update", target: memory.id, version: memory.updatedAt,
            payload: ["patch": .object(["checklist": .array([
                .object(["id": .string(first), "title": .string("A")]),
                .object(["id": .string(first), "title": .string("B")])])])]))
        #expect(duplicate.status == "failed")
        memory = try await f.update(memory, ["checklist": .array([.object(["title": .string("Replacement")])])])
        #expect(memory.checklist.count == 1 && memory.checklist[0].id != first)
        memory = try await f.update(memory, ["checklist": .array([])])
        #expect(memory.checklist.isEmpty)
    }

    @Test(arguments: [true, false]) func checklistHonorsAutoCompletion(enabled: Bool) async throws {
        let f = try RemoteTestFixture(); defer { f.cleanup() }
        var memory = try await f.createMemory(["autoCompleteOnChecklistCompletion": .bool(enabled),
                                               "checklist": .array([.object(["title": .string("Only item")])])])
        let item = try #require(memory.checklist.first)
        memory = try f.decode(await f.executor.execute(f.command("memory.toggleCheckItem", target: memory.id,
            version: memory.updatedAt, payload: ["itemId": .string(item.id)])), key: "memory", as: MemoryDTO.self)
        #expect(memory.checklist[0].isCompleted)
        #expect(memory.status == (enabled ? "completed" : "active"))
        memory = try f.decode(await f.executor.execute(f.command("memory.toggleCheckItem", target: memory.id,
            version: memory.updatedAt, payload: ["itemId": .string(item.id)])), key: "memory", as: MemoryDTO.self)
        #expect(!memory.checklist[0].isCompleted && memory.status == "active")
    }

    @Test func occurrencesCompleteAndReopenIndependently() async throws {
        let f = try RemoteTestFixture(); defer { f.cleanup() }
        var memory = try await f.createMemory(["schedule": try f.schedule("hourly"),
            "checklist": .array([.object(["title": .string("Recurring item")])])])
        let first = Date(timeIntervalSince1970: 1_709_251_200)
        let second = first.addingTimeInterval(2 * 3600)
        for date in [first, second] {
            memory = try f.decode(await f.executor.execute(f.command("memory.setStatus", target: memory.id,
                version: memory.updatedAt, payload: ["status": .string("completed"), "occurrenceDate": try .from(date)])), key: "memory", as: MemoryDTO.self)
        }
        #expect(Set(memory.completedDates) == Set([first, second]))
        memory = try f.decode(await f.executor.execute(f.command("memory.setStatus", target: memory.id,
            version: memory.updatedAt, payload: ["status": .string("active"), "occurrenceDate": try .from(first)])), key: "memory", as: MemoryDTO.self)
        #expect(memory.completedDates == [second])
        #expect(memory.status == "active")
        let item = try #require(memory.checklist.first)
        memory = try f.decode(await f.executor.execute(f.command("memory.toggleCheckItem", target: memory.id,
            version: memory.updatedAt, payload: ["itemId": .string(item.id), "occurrenceDate": try .from(first)])), key: "memory", as: MemoryDTO.self)
        #expect(Set(memory.completedDates) == Set([first, second]))
        memory = try f.decode(await f.executor.execute(f.command("memory.toggleCheckItem", target: memory.id,
            version: memory.updatedAt, payload: ["itemId": .string(item.id), "occurrenceDate": try .from(first)])), key: "memory", as: MemoryDTO.self)
        #expect(memory.completedDates == [second])
    }

    @Test func persistedHourlyOccurrencesRemainIndependentAcrossMonthBoundary() async throws {
        let f = try RemoteTestFixture(); defer { f.cleanup() }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let first = try #require(calendar.date(from: DateComponents(year: 2024, month: 1, day: 31, hour: 23)))
        let second = first.addingTimeInterval(2 * 3600)
        let itemID = UUID()
        let memory = try await f.memories.createMemory(from: MemoryDraft(
            title: "Isolated hourly occurrences",
            scheduleConfig: ScheduleConfigDraft(fireDate: first, startDate: first,
                recurrenceRule: RecurrenceRule(frequency: .hourly, interval: 2, occurrenceCount: 3),
                timeZoneIdentifier: "UTC", isActive: false, recurrenceEndType: .afterCount),
            checkItems: [CheckItemDraft(id: itemID, title: "Recurring item")],
            autoCompleteOnChecklistCompletion: true))

        // Read the persisted model directly: the separate wire tests exercise the known missing-weekdays failure.
        func apply(_ type: String, _ fields: [String: RemoteJSONValue]) async {
            let version = RemoteJSON.version(updatedAt: memory.updatedAt, createdAt: memory.createdAt)
            let result = await f.executor.execute(f.command(type, target: memory.id.uuidString.lowercased(),
                version: version, payload: fields))
            #expect(result.status == "done", "Occurrence command error: \(result.error ?? "none")")
        }
        for date in [first, second] {
            await apply("memory.setStatus", ["status": .string("completed"), "occurrenceDate": try .from(date)])
        }
        #expect(Set(memory.completedDates) == Set([first, second]))
        await apply("memory.setStatus", ["status": .string("active"), "occurrenceDate": try .from(first)])
        #expect(memory.completedDates == [second])
        #expect(memory.status == .active)
        await apply("memory.toggleCheckItem", ["itemId": .string(itemID.uuidString), "occurrenceDate": try .from(first)])
        #expect(Set(memory.completedDates) == Set([first, second]))
        await apply("memory.toggleCheckItem", ["itemId": .string(itemID.uuidString), "occurrenceDate": try .from(first)])
        #expect(memory.completedDates == [second])
        let persisted = try f.data.newBackgroundContext().fetch(FetchDescriptor<Memory>())
        let persistedMemory = try #require(persisted.first { $0.id == memory.id })
        #expect(persistedMemory.completedDates == [second])
    }

    @Test func scheduleCalculationsCrossCalendarBoundariesAndRespectInclusiveEnd() throws {
        let calendar = Calendar.current
        let cases: [(RecurrenceFrequency, DateComponents, DateComponents)] = [
            (.hourly, DateComponents(year: 2026, month: 12, day: 31, hour: 23), DateComponents(year: 2027, month: 1, day: 1, hour: 0)),
            (.daily, DateComponents(year: 2024, month: 2, day: 28, hour: 12), DateComponents(year: 2024, month: 2, day: 29, hour: 12)),
            (.daily, DateComponents(year: 2024, month: 2, day: 29, hour: 12), DateComponents(year: 2024, month: 3, day: 1, hour: 12)),
            (.weekly, DateComponents(year: 2026, month: 12, day: 28, hour: 12), DateComponents(year: 2027, month: 1, day: 4, hour: 12)),
            (.monthly, DateComponents(year: 2024, month: 1, day: 31, hour: 12), DateComponents(year: 2024, month: 2, day: 29, hour: 12)),
            (.yearly, DateComponents(year: 2024, month: 2, day: 29, hour: 12), DateComponents(year: 2025, month: 2, day: 28, hour: 12))
        ]
        for (frequency, startParts, endParts) in cases {
            let start = try #require(calendar.date(from: startParts))
            let end = try #require(calendar.date(from: endParts))
            let schedule = ScheduleConfig(fireDate: start, startDate: start,
                recurrenceRule: RecurrenceRule(frequency: frequency, endDate: end),
                timeZoneIdentifier: calendar.timeZone.identifier, isActive: false, recurrenceEndType: .untilDate)
            #expect(schedule.nextFireDate(after: start) == end)
            #expect(schedule.nextFireDate(after: end.addingTimeInterval(1)) == nil)
        }
    }

    @Test func staleVersionsAndMissingBaseDoNotMutate() async throws {
        let f = try RemoteTestFixture(); defer { f.cleanup() }
        let memory = try await f.createMemory()
        for type in ["memory.update", "memory.delete", "memory.setStatus", "memory.toggleCheckItem"] {
            let stale = await f.executor.execute(f.command(type, target: memory.id,
                version: memory.updatedAt.addingTimeInterval(-1), payload: ["patch": .object(["title": .string("Overwrite")])]))
            #expect(stale.status == "conflict")
        }
        let missing = await f.executor.execute(f.command("memory.delete", target: memory.id))
        #expect(missing.status == "failed")
        let current = try await f.builder.build()
        #expect(current.memories.first { $0.id == memory.id }?.title == memory.title)
        let mind = try await f.createMind("Versioned mind")
        for type in ["mind.update", "mind.delete"] {
            let stale = await f.executor.execute(f.command(type, target: mind.id, version: mind.updatedAt.addingTimeInterval(-1)))
            #expect(stale.status == "conflict")
        }
        #expect(f.minds.mind(id: UUID(uuidString: mind.id)!)?.name == mind.name)
    }

    @Test func redeliveryAndJournalReopeningDoNotDuplicate() async throws {
        let f = try RemoteTestFixture(); defer { f.cleanup() }
        let command = f.command("memory.create", payload: ["title": .string("Once")])
        let original = await f.executor.execute(command)
        let repeated = await f.executor.execute(command)
        #expect(try RemoteJSON.encoder().encode(original) == RemoteJSON.encoder().encode(repeated))
        let reopened = RemoteCommandExecutor(builder: f.builder, journalURL: f.journal)
        let resumed = await reopened.execute(command)
        #expect(try RemoteJSON.encoder().encode(original) == RemoteJSON.encoder().encode(resumed))
        #expect(f.memories.memories.count == 1)
        #expect(reopened.pendingResults().count == 1)
        try reopened.markReported(command.id.lowercased())
        #expect(reopened.pendingResults().isEmpty)
        let afterReporting = RemoteCommandExecutor(builder: f.builder, journalURL: f.journal)
        #expect(afterReporting.pendingResults().isEmpty)
        let again = await afterReporting.execute(command)
        #expect(again.status == "done" && f.memories.memories.count == 1)
    }

    @Test func corruptAndUnwritableHistoryFailBeforeMutation() async throws {
        let f = try RemoteTestFixture(); defer { f.cleanup() }
        try Data("corrupt".utf8).write(to: f.journal)
        let corrupt = RemoteCommandExecutor(builder: f.builder, journalURL: f.journal)
        let rejected = await corrupt.execute(f.command("memory.create", payload: ["title": .string("Blocked")]))
        #expect(rejected.status == "failed")
        #expect(rejected.error?.contains("history is unavailable") == true)
        #expect(f.memories.memories.isEmpty)
        let blocker = f.root.appendingPathComponent("file-not-directory")
        try Data().write(to: blocker)
        let unwritable = RemoteCommandExecutor(builder: f.builder, journalURL: blocker.appendingPathComponent("commands.json"))
        let failed = await unwritable.execute(f.command("mind.create", payload: ["name": .string("Blocked")]))
        #expect(failed.status == "failed")
        #expect(!f.minds.minds.contains { $0.name == "Blocked" })
    }

    @Test func interruptedIntentFailsClosedWithoutReapplying() async throws {
        let f = try RemoteTestFixture(); defer { f.cleanup() }
        let command = f.command("memory.create", payload: ["title": .string("Interrupted")])
        let receipt = JournalReceipt(id: command.id.lowercased(), date: Date(),
            result: CommandResultDTO(status: "failed", result: .object([:]),
                error: "Command application was interrupted; inspect the current entity before retrying"), pending: true)
        try RemoteJSON.encoder().encode([receipt]).write(to: f.journal)
        let reopened = RemoteCommandExecutor(builder: f.builder, journalURL: f.journal)
        let result = await reopened.execute(command)
        #expect(result.status == "failed" && result.error?.contains("interrupted") == true)
        #expect(f.memories.memories.isEmpty)
        #expect(reopened.pendingResults().count == 1)
    }

    @Test func journalPrunesExpiredReceiptsAndCapsHistory() throws {
        let f = try RemoteTestFixture(); defer { f.cleanup() }
        let result = CommandResultDTO(status: "done", result: .object([:]), error: nil)
        let expiredID = UUID().uuidString.lowercased()
        var receipts = [JournalReceipt(id: expiredID, date: Date().addingTimeInterval(-31 * 24 * 3600), result: result, pending: true)]
        for _ in 0..<501 {
            receipts.append(JournalReceipt(id: UUID().uuidString.lowercased(), date: Date(), result: result, pending: true))
        }
        try RemoteJSON.encoder().encode(receipts).write(to: f.journal)
        let reopened = RemoteCommandExecutor(builder: f.builder, journalURL: f.journal)
        #expect(reopened.pendingResults().count == 500)
        #expect(!reopened.pendingResults().contains { $0.0 == expiredID })
        #expect(!reopened.pendingResults().contains { $0.0 == receipts[1].id })
        try reopened.markReported(receipts.last!.id)
        let stored = try RemoteJSON.decoder().decode([JournalReceipt].self, from: Data(contentsOf: f.journal))
        #expect(stored.count == 500)
        #expect(stored.last?.pending == false)
    }

    @Test func invalidCommandsRejectWithoutMutation() async throws {
        let f = try RemoteTestFixture(); defer { f.cleanup() }
        let invalidPayloads: [[String: RemoteJSONValue]] = [
            ["title": .string("")], ["title": .string(" \n\t")], ["title": .string("A"), "unknown": .bool(true)],
            ["title": .string("A"), "mindId": .string("not-uuid")],
            ["title": .string("A"), "dueDate": .string("2026-02-30T00:00:00.000Z")],
            ["title": .string("A"), "checklist": .array([.object(["id": .string("bad"), "title": .string("Item")])])],
            ["title": .string("A"), "links": .array([.object(["url": .string("relative/path")])])]
        ]
        for payload in invalidPayloads {
            let result = await f.executor.execute(f.command("memory.create", payload: payload))
            #expect(result.status == "failed", "Invalid payload must fail")
        }
        let invalidID = await f.executor.execute(f.command("memory.create", payload: ["title": .string("A")], id: "invalid"))
        #expect(invalidID.status == "failed")
        let unknown = await f.executor.execute(f.command("unknown", target: UUID().uuidString))
        #expect(unknown.status == "failed")
        #expect(f.memories.memories.isEmpty)
    }
}

private struct JournalReceipt: Codable {
    var id: String
    var date: Date
    var result: CommandResultDTO
    var pending: Bool
}
