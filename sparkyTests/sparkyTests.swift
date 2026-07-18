import Foundation
import Testing
@testable import sparky

struct SparkyTests {
    @MainActor
    @Test func memoryServiceBasicOperations() async throws {
        let environment = AppEnvironment(dataController: DataController(inMemory: true))
        let memory = try await environment.memoryService.createMemory(
            from: MemoryDraft(title: "Test Memory")
        )

        #expect(memory.title == "Test Memory")
        #expect(memory.status == .active)

        try await environment.memoryService.togglePin(memoryID: memory.id)
        #expect(environment.memoryService.memory(id: memory.id)?.isPinned == true)

        try await environment.memoryService.toggleCompletion(memoryID: memory.id)
        #expect(environment.memoryService.memory(id: memory.id)?.status == .completed)
    }

    @MainActor
    @Test func memoryTimelineFiltering() async throws {
        let environment = AppEnvironment(dataController: DataController(inMemory: true))

        _ = try await environment.memoryService.createMemory(from: MemoryDraft(title: "Active Memory"))
        _ = try await environment.memoryService.createMemory(
            from: MemoryDraft(title: "Completed Memory", status: .completed)
        )

        let activeMemories = environment.memoryService.memories(in: nil, statuses: [.active])
        let completedMemories = environment.memoryService.memories(in: nil, statuses: [.completed])

        #expect(activeMemories.map(\.title) == ["Active Memory"])
        #expect(completedMemories.map(\.title) == ["Completed Memory"])
    }

    @MainActor
    @Test func scheduleRepeatAndLocationPersist() async throws {
        let environment = AppEnvironment(dataController: DataController(inMemory: true))
        let fireDate = Date().addingTimeInterval(3_600)
        let recurrence = RecurrenceRule(frequency: .daily, interval: 2, occurrenceCount: 5)

        let memory = try await environment.memoryService.createMemory(
            from: MemoryDraft(
                title: "Current triggers",
                scheduleConfig: ScheduleConfigDraft(
                    fireDate: fireDate,
                    startDate: fireDate,
                    recurrenceRule: recurrence,
                    timeZoneIdentifier: TimeZone.current.identifier,
                    recurrenceEndType: .afterCount
                ),
                locationConfig: LocationConfigDraft(
                    latitude: 37.33,
                    longitude: -122.01,
                    radius: 200,
                    name: "Office",
                    event: .onEntry
                )
            )
        )

        #expect(memory.scheduleConfig?.recurrenceRule == recurrence)
        #expect(memory.scheduleConfig?.recurrenceEndType == .afterCount)
        #expect(memory.locationConfig?.event == .onEntry)
        #expect(memory.hasTriggers)
    }

    @MainActor
    @Test func focusRequiresAndUsesConcreteRecipe() async throws {
        let environment = AppEnvironment(dataController: DataController(inMemory: true))
        let fireDate = Date().addingTimeInterval(600)

        let memory = try await environment.memoryService.createMemory(
            from: MemoryDraft(
                title: "Focus memory",
                scheduleConfig: ScheduleConfigDraft(
                    fireDate: fireDate,
                    startDate: fireDate,
                    isActive: true,
                    focusEnabled: true,
                    focusWorkDurationMinutes: 25,
                    focusShortBreakDurationMinutes: 5,
                    focusLongBreakDurationMinutes: 15,
                    focusPomodorosUntilLongBreak: 4,
                    focusAutoContinue: true
                )
            )
        )

        #expect(memory.focusRecipe()?.workDurationMinutes == 25)
        environment.startFocus(for: memory.id)
        #expect(environment.focusTimer.activeMemoryID == memory.id)
    }
}
