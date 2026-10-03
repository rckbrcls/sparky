import Foundation
import Testing
@testable import sparky

@MainActor
final class TriggerSyncRecorder: TriggerSyncing {
    enum Event: Equatable {
        case unregister(triggerID: UUID, memoryID: UUID)
        case unregisterAll(memoryID: UUID)
        case sync(memoryIDs: [UUID])
    }

    private(set) var events: [Event] = []

    func reset() {
        events.removeAll()
    }

    func unregister(triggerID: UUID, for memoryID: UUID) async {
        events.append(.unregister(triggerID: triggerID, memoryID: memoryID))
    }

    func unregisterAll(for memoryID: UUID) async {
        events.append(.unregisterAll(memoryID: memoryID))
    }

    func sync(memories: [Memory]) async {
        events.append(.sync(memoryIDs: memories.map(\.id)))
    }
}

@MainActor
@Suite("Trigger sync lifecycle")
struct TriggerSyncLifecycleTests {
    private let fire = Date().addingTimeInterval(3_600)

    @Test func createPersistsScheduleAndLocationAndSyncs() async throws {
        let (service, recorder) = try makeService()
        let memory = try await service.createMemory(from: draft(title: "Current triggers"))

        #expect(memory.scheduleConfig?.recurrenceRule == RecurrenceRule(frequency: .daily, interval: 2, occurrenceCount: 5))
        #expect(memory.scheduleConfig?.recurrenceEndType == .afterCount)
        #expect(memory.scheduleConfig?.weekdayMask == TriggerTestSupport.weekdayMask(2, 6))
        #expect(memory.scheduleConfig?.isActive == true)
        #expect(memory.locationConfig?.latitude == 37.33)
        #expect(memory.locationConfig?.longitude == -122.01)
        #expect(memory.locationConfig?.radius == 200)
        #expect(memory.locationConfig?.name == "Office")
        #expect(memory.locationConfig?.event == .onEntry)
        #expect(memory.hasTriggers)
        #expect(recorder.events == [.sync(memoryIDs: [memory.id])])
    }

    @Test func updateReplacesTriggerFieldsAndSyncs() async throws {
        let (service, recorder) = try makeService()
        let memory = try await service.createMemory(from: draft(title: "Current triggers"))
        recorder.reset()

        let updatedFire = fire.addingTimeInterval(7_200)
        let updated = try await service.updateMemory(
            from: MemoryDraft(
                id: memory.id,
                title: "Current triggers",
                scheduleConfig: ScheduleConfigDraft(
                    fireDate: updatedFire,
                    startDate: updatedFire,
                    recurrenceRule: RecurrenceRule(frequency: .weekly, interval: 2),
                    timeZoneIdentifier: "GMT",
                    weekdayMask: TriggerTestSupport.weekdayMask(2),
                    isActive: true,
                    recurrenceEndType: .never
                ),
                locationConfig: LocationConfigDraft(
                    latitude: 1,
                    longitude: 2,
                    radius: 350,
                    name: "Park",
                    event: .onExit,
                    isActive: true
                )
            )
        )

        #expect(updated.scheduleConfig?.recurrenceRule == RecurrenceRule(frequency: .weekly, interval: 2))
        #expect(updated.scheduleConfig?.weekdayMask == TriggerTestSupport.weekdayMask(2))
        #expect(updated.scheduleConfig?.fireDate == updatedFire)
        #expect(updated.locationConfig?.latitude == 1)
        #expect(updated.locationConfig?.longitude == 2)
        #expect(updated.locationConfig?.radius == 350)
        #expect(updated.locationConfig?.name == "Park")
        #expect(updated.locationConfig?.event == .onExit)
        #expect(recorder.events == [.sync(memoryIDs: [memory.id])])
    }

    @Test func updateCanRemoveScheduleOrLocation() async throws {
        let (service, recorder) = try makeService()
        let memory = try await service.createMemory(from: draft(title: "Current triggers"))
        let schedule = try #require(memory.scheduleConfig)
        recorder.reset()

        let scheduleOnly = try await service.updateMemory(
            from: MemoryDraft(
                id: memory.id,
                title: memory.title,
                scheduleConfig: ScheduleConfigDraft.from(schedule)
            )
        )
        #expect(scheduleOnly.scheduleConfig?.id == schedule.id)
        #expect(scheduleOnly.locationConfig == nil)
        #expect(scheduleOnly.hasSchedule)
        #expect(scheduleOnly.hasLocation == false)
        #expect(recorder.events == [.sync(memoryIDs: [memory.id])])

        recorder.reset()
        let location = LocationConfigDraft(
            latitude: 10,
            longitude: 20,
            radius: 80,
            name: "Home",
            event: .onExit
        )
        let locationOnly = try await service.updateMemory(
            from: MemoryDraft(
                id: memory.id,
                title: memory.title,
                locationConfig: location
            )
        )
        #expect(locationOnly.scheduleConfig == nil)
        #expect(locationOnly.locationConfig?.name == "Home")
        #expect(locationOnly.locationConfig?.event == .onExit)
        #expect(locationOnly.hasSchedule == false)
        #expect(locationOnly.hasLocation)
        #expect(recorder.events == [.sync(memoryIDs: [memory.id])])
    }

    @Test func duplicateAssignsNewTriggerIDs() async throws {
        let (service, recorder) = try makeService()
        let memory = try await service.createMemory(from: draft(title: "Copy me"))
        let originalScheduleID = try #require(memory.scheduleConfig?.id)
        let originalLocationID = try #require(memory.locationConfig?.id)
        recorder.reset()

        try await service.duplicateMemory(memoryID: memory.id)

        let copies = service.memories.filter { $0.title == "Copy me" }
        #expect(copies.count == 2)
        let copy = try #require(copies.first { $0.id != memory.id })
        #expect(copy.scheduleConfig?.id != originalScheduleID)
        #expect(copy.locationConfig?.id != originalLocationID)
        #expect(service.memory(id: memory.id)?.scheduleConfig?.id == originalScheduleID)
        #expect(service.memory(id: memory.id)?.locationConfig?.id == originalLocationID)
        #expect(copy.scheduleConfig?.recurrenceRule == memory.scheduleConfig?.recurrenceRule)
        #expect(copy.locationConfig?.latitude == memory.locationConfig?.latitude)
        #expect(copy.locationConfig?.event == .onEntry)
        #expect(recorder.events.map(\.syncedIDs).contains { $0.contains(copy.id) })
    }

    @Test func completingMemoryUnregistersThenSyncs() async throws {
        let (service, recorder) = try makeService()
        let memory = try await service.createMemory(from: draft(title: "Finish"))
        recorder.reset()

        try await service.toggleCompletion(memoryID: memory.id)

        #expect(service.memory(id: memory.id)?.status == .completed)
        #expect(recorder.events == [
            .unregisterAll(memoryID: memory.id),
            .sync(memoryIDs: [memory.id])
        ])
    }

    @Test func completingTheChecklistUnregistersWhenTheMemoryCompletes() async throws {
        let (service, recorder) = try makeService()
        let itemID = UUID()
        let memory = try await service.createMemory(
            from: draft(
                title: "Checklist",
                checkItems: [CheckItemDraft(id: itemID, title: "Step")],
                autoCompleteOnChecklistCompletion: true,
                recurring: false
            )
        )
        recorder.reset()

        try await service.toggleChecklistItemCompletion(memoryID: memory.id, itemID: itemID)

        #expect(service.memory(id: memory.id)?.status == .completed)
        #expect(recorder.events == [
            .unregisterAll(memoryID: memory.id),
            .sync(memoryIDs: [memory.id])
        ])
    }

    @Test func deleteUnregistersBeforeTheFollowingSync() async throws {
        let (service, recorder) = try makeService()
        let memory = try await service.createMemory(from: draft(title: "Delete"))
        recorder.reset()

        try await service.deleteMemory(id: memory.id)

        #expect(service.memory(id: memory.id) == nil)
        #expect(recorder.events == [
            .unregisterAll(memoryID: memory.id),
            .sync(memoryIDs: [])
        ])
    }

    @Test func reactivatingDoesNotUnregisterBeforeSync() async throws {
        let (service, recorder) = try makeService()
        let memory = try await service.createMemory(from: draft(title: "Resume"))
        try await service.toggleCompletion(memoryID: memory.id)
        recorder.reset()

        try await service.toggleCompletion(memoryID: memory.id)

        #expect(service.memory(id: memory.id)?.status == .active)
        #expect(recorder.events == [.sync(memoryIDs: [memory.id])])
    }

    private func makeService() throws -> (MemoryService, TriggerSyncRecorder) {
        let environment = AppEnvironment(dataController: DataController(inMemory: true))
        let recorder = TriggerSyncRecorder()
        environment.memoryService.triggerExecutorCoordinator = recorder
        return (environment.memoryService, recorder)
    }

    private func draft(
        title: String,
        checkItems: [CheckItemDraft] = [],
        autoCompleteOnChecklistCompletion: Bool = false,
        recurring: Bool = true
    ) -> MemoryDraft {
        MemoryDraft(
            title: title,
            scheduleConfig: ScheduleConfigDraft(
                fireDate: fire,
                startDate: fire,
                recurrenceRule: recurring
                    ? RecurrenceRule(frequency: .daily, interval: 2, occurrenceCount: 5)
                    : nil,
                timeZoneIdentifier: TimeZone.current.identifier,
                weekdayMask: recurring ? TriggerTestSupport.weekdayMask(2, 6) : 0,
                isActive: true,
                recurrenceEndType: recurring ? .afterCount : .never
            ),
            locationConfig: LocationConfigDraft(
                latitude: 37.33,
                longitude: -122.01,
                radius: 200,
                name: "Office",
                event: .onEntry
            ),
            checkItems: checkItems,
            autoCompleteOnChecklistCompletion: autoCompleteOnChecklistCompletion
        )
    }
}

private extension TriggerSyncRecorder.Event {
    var syncedIDs: [UUID] {
        if case .sync(let memoryIDs) = self {
            return memoryIDs
        }
        return []
    }
}
