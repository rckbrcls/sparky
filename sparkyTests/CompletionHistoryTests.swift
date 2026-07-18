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
    @Test func completionBackfillUsesBestAvailableLegacyDate() {
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let createdAt = updatedAt.addingTimeInterval(-3_600)
        let fallback = updatedAt.addingTimeInterval(3_600)
        let completed = Memory(
            title: "Legacy completed",
            statusRaw: MemoryStatus.completed.rawValue,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        let active = Memory(
            title: "Legacy active",
            statusRaw: MemoryStatus.active.rawValue,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        DataController.backfillCompletionHistory(
            in: [completed, active],
            fallbackDate: fallback
        )

        #expect(completed.completedAt == updatedAt)
        #expect(active.completedAt == nil)
    }

    @MainActor
    @Test func exportedMemoryDecodesWhenCompletedAtIsMissing() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exported = ExportedMemory(
            id: UUID(),
            title: "Legacy export",
            status: MemoryStatus.completed.rawValue,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_600),
            completedAt: Date(timeIntervalSince1970: 1_700_000_300)
        )

        let encoded = try encoder.encode(exported)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "completedAt")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try decoder.decode(ExportedMemory.self, from: legacyData)

        #expect(decoded.completedAt == nil)
    }

    @MainActor
    @Test func exportAndImportPreserveCompletionDate() async throws {
        let sourceEnvironment = AppEnvironment(dataController: DataController(inMemory: true))
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try await sourceEnvironment.memoryService.createMemory(
            from: MemoryDraft(
                title: "Portable completion",
                status: .completed,
                completedAt: completedAt
            )
        )

        let exporter = DataExportService(
            memoryService: sourceEnvironment.memoryService,
            mindService: sourceEnvironment.mindService,
            attachmentStore: sourceEnvironment.attachmentStore
        )
        let data = try await exporter.export(options: .withoutAttachments)

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
    }
}
