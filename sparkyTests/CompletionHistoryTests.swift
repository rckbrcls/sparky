import Foundation
import Testing
@testable import sparky

struct CompletionHistoryTests {
    @MainActor
    @Test func statusTransitionsRecordAndClearCompletionDate() async throws {
        let environment = AppEnvironment(dataController: DataController(inMemory: true))
        let memory = try await environment.memoryService.createMemory(
            from: MemoryDraft(title: "Completion history")
        )

        #expect(memory.completedAt == nil)

        try await environment.memoryService.setStatus(memoryID: memory.id, status: .completed)
        let completed = environment.memoryService.memory(id: memory.id)
        #expect(completed?.completedAt != nil)
        let originalCompletion = completed?.completedAt

        let metadataDraft = MemoryDraft(
            id: memory.id,
            title: "Completion history updated",
            status: .completed
        )
        _ = try await environment.memoryService.updateMemory(from: metadataDraft)
        #expect(environment.memoryService.memory(id: memory.id)?.completedAt == originalCompletion)

        try await environment.memoryService.setStatus(memoryID: memory.id, status: .active)
        #expect(environment.memoryService.memory(id: memory.id)?.completedAt == nil)
    }

    @MainActor
    @Test func checklistAutoCompletionUpdatesCompletionDate() async throws {
        let environment = AppEnvironment(dataController: DataController(inMemory: true))
        let itemID = UUID()
        let memory = try await environment.memoryService.createMemory(
            from: MemoryDraft(
                title: "Checklist completion",
                checkItems: [CheckItemDraft(id: itemID, title: "Only item")]
            )
        )

        try await environment.memoryService.toggleChecklistItemCompletion(
            memoryID: memory.id,
            itemID: itemID
        )
        let completed = environment.memoryService.memory(id: memory.id)
        #expect(completed?.status == .completed)
        #expect(completed?.completedAt != nil)

        try await environment.memoryService.toggleChecklistItemCompletion(
            memoryID: memory.id,
            itemID: itemID
        )
        let reopened = environment.memoryService.memory(id: memory.id)
        #expect(reopened?.status == .active)
        #expect(reopened?.completedAt == nil)
    }

    @MainActor
    @Test func duplicateStartsWithFreshCompletionState() async throws {
        let environment = AppEnvironment(dataController: DataController(inMemory: true))
        let source = try await environment.memoryService.createMemory(
            from: MemoryDraft(title: "Completed source", status: .completed)
        )

        try await environment.memoryService.duplicateMemory(memoryID: source.id)

        let copy = environment.memoryService.memories.first { $0.id != source.id }
        #expect(copy?.status == .active)
        #expect(copy?.completedAt == nil)
    }

    @MainActor
    @Test func exportAndImportVersion2PreservesCurrentConfigs() async throws {
        let sourceEnvironment = AppEnvironment(dataController: DataController(inMemory: true))
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let fireDate = Date(timeIntervalSince1970: 1_700_003_600)
        _ = try await sourceEnvironment.memoryService.createMemory(
            from: MemoryDraft(
                title: "Portable completion",
                status: .completed,
                scheduleConfig: ScheduleConfigDraft(
                    fireDate: fireDate,
                    startDate: fireDate,
                    recurrenceRule: RecurrenceRule(frequency: .weekly, interval: 2),
                    recurrenceEndType: .never,
                    focusEnabled: true,
                    focusWorkDurationMinutes: 25,
                    focusShortBreakDurationMinutes: 5,
                    focusLongBreakDurationMinutes: 15,
                    focusPomodorosUntilLongBreak: 4
                ),
                locationConfig: LocationConfigDraft(
                    latitude: 37.33,
                    longitude: -122.01,
                    radius: 250,
                    name: "Office",
                    event: .onExit
                ),
                completedAt: completedAt
            )
        )

        let exporter = DataExportService(
            memoryService: sourceEnvironment.memoryService,
            mindService: sourceEnvironment.mindService,
            attachmentStore: sourceEnvironment.attachmentStore
        )
        let data = try await exporter.export(options: .withoutAttachments)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exported = try decoder.decode(SparkyExportFormat.self, from: data)
        #expect(exported.version == "2.0")

        let destinationEnvironment = AppEnvironment(dataController: DataController(inMemory: true))
        let importer = DataImportService(
            memoryService: destinationEnvironment.memoryService,
            mindService: destinationEnvironment.mindService,
            attachmentStore: destinationEnvironment.attachmentStore
        )
        let result = try await importer.importFromData(data)

        #expect(result.importedMemories == 1)
        let imported = destinationEnvironment.memoryService.memories.first
        #expect(imported?.completedAt == completedAt)
        #expect(imported?.scheduleConfig?.recurrenceRule?.frequency == .weekly)
        #expect(imported?.scheduleConfig?.focusWorkDurationMinutes == 25)
        #expect(imported?.locationConfig?.event == .onExit)
        #expect(imported?.locationConfig?.radius == 250)
    }

    @MainActor
    @Test func importRejectsVersion1() async throws {
        let environment = AppEnvironment(dataController: DataController(inMemory: true))
        let importer = DataImportService(
            memoryService: environment.memoryService,
            mindService: environment.mindService,
            attachmentStore: environment.attachmentStore
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(SparkyExportFormat(version: "1.0"))

        do {
            _ = try await importer.importFromData(data)
            Issue.record("Expected version 1.0 to be rejected")
        } catch DataImportService.ImportError.unsupportedVersion(let version) {
            #expect(version == "1.0")
        } catch {
            Issue.record("Unexpected import error: \(error)")
        }
    }
}
