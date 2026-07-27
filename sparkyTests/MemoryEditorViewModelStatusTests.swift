import Foundation
import Testing
@testable import sparky

@MainActor
struct MemoryEditorViewModelStatusTests {
    @Test func statusToggleUpdatesChecklistAndPersists() async throws {
        let fixture = try makeFixture(
            suite: "MemoryEditorStatus.success",
            includesChecklist: true
        )
        let viewModel = makeViewModel(
            environment: fixture.environment,
            memory: fixture.memory
        )

        let success = await viewModel.toggleStatusAndSave()

        #expect(success)
        #expect(viewModel.status == .completed)
        #expect(viewModel.checkItems.allSatisfy(\.isCompleted))

        let persisted = try #require(
            fixture.environment.memoryService.memory(id: fixture.memory.id)
        )
        #expect(persisted.status == .completed)
        #expect(persisted.checkItems.allSatisfy(\.isCompleted))

        let reopened = makeViewModel(
            environment: fixture.environment,
            memory: persisted
        )
        #expect(reopened.status == .completed)
        #expect(reopened.checkItems.allSatisfy(\.isCompleted))
    }

    @Test func optimisticToggleBlocksRepeatedActivation() async throws {
        let fixture = try makeFixture(
            suite: "MemoryEditorStatus.repeat",
            includesChecklist: false
        )
        let gate = SaveGate()
        let viewModel = makeViewModel(
            environment: fixture.environment,
            memory: fixture.memory,
            metadataSaveOperation: { draft in
                gate.attemptCount += 1
                await gate.wait()
                fixture.memory.status = draft.status
                return fixture.memory
            }
        )

        let firstSave = Task {
            await viewModel.toggleStatusAndSave()
        }
        while !gate.hasStarted {
            await Task.yield()
        }

        #expect(viewModel.status == .completed)
        #expect(viewModel.isSaving)

        let repeatedSave = await viewModel.toggleStatusAndSave()

        #expect(!repeatedSave)
        #expect(gate.attemptCount == 1)

        gate.release()
        let firstSaveSucceeded = await firstSave.value
        #expect(firstSaveSucceeded)
        #expect(!viewModel.isSaving)
    }

    @Test func failedToggleRestoresAuthoritativeStatusAndChecklist() async throws {
        let fixture = try makeFixture(
            suite: "MemoryEditorStatus.failure",
            includesChecklist: true
        )
        let viewModel = makeViewModel(
            environment: fixture.environment,
            memory: fixture.memory,
            metadataSaveOperation: { _ in
                throw SaveFailure.expected
            }
        )

        let success = await viewModel.toggleStatusAndSave()

        #expect(!success)
        #expect(viewModel.status == .active)
        #expect(viewModel.checkItems.allSatisfy { !$0.isCompleted })
        #expect(viewModel.errorMessage == "Unable to save memory.")
        #expect(!viewModel.isSaving)
    }

    private func makeFixture(
        suite: String,
        includesChecklist: Bool
    ) throws -> Fixture {
        let controller = DataController(inMemory: true)
        let memory = Memory(title: "Reliable preview")

        if includesChecklist {
            let item = CheckItemModel(
                title: "Confirm persistence",
                memory: memory
            )
            memory.checkItems = [item]
        }

        controller.modelContext.insert(memory)
        controller.save()

        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let environment = AppEnvironment(
            dataController: controller,
            focusSettings: FocusSettings(defaults: defaults)
        )
        let loadedMemory = try #require(
            environment.memoryService.memory(id: memory.id)
        )
        return Fixture(
            environment: environment,
            memory: loadedMemory
        )
    }

    private func makeViewModel(
        environment: AppEnvironment,
        memory: Memory,
        metadataSaveOperation: MemoryEditorViewModel.MetadataSaveOperation? = nil
    ) -> MemoryEditorViewModel {
        MemoryEditorViewModel(
            environment: environment,
            attachmentStore: environment.attachmentStore,
            memory: memory,
            defaultMind: nil,
            template: .blank,
            metadataSaveOperation: metadataSaveOperation
        )
    }

    private struct Fixture {
        let environment: AppEnvironment
        let memory: Memory
    }

    private final class SaveGate {
        var attemptCount = 0
        private(set) var hasStarted = false
        private var continuation: CheckedContinuation<Void, Never>?

        func wait() async {
            hasStarted = true
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        }

        func release() {
            continuation?.resume()
            continuation = nil
        }
    }

    private enum SaveFailure: Error {
        case expected
    }
}
