import Testing
@testable import sparky

struct MindMemoryDisplayContentTests {
    @MainActor
    @Test func activePinnedMemoriesAreSeparatedWithoutChangingRemainingOrder() {
        let completedMemory = Memory(title: "Completed")
        completedMemory.status = .completed

        let activePinnedMemory = Memory(title: "Active pinned", isPinned: true)

        let completedPinnedMemory = Memory(title: "Completed pinned", isPinned: true)
        completedPinnedMemory.status = .completed

        let activeMemory = Memory(title: "Active")
        let orderedMemories = [
            completedMemory,
            activePinnedMemory,
            completedPinnedMemory,
            activeMemory
        ]

        let content = MindMemoryDisplayContent(memories: orderedMemories)

        #expect(content.pinnedMemories.map(\.title) == ["Active pinned"])
        #expect(
            content.remainingMemories.map(\.title)
                == ["Completed", "Completed pinned", "Active"]
        )

        let displayedIDs = (content.pinnedMemories + content.remainingMemories).map(\.id)
        #expect(Set(displayedIDs).count == orderedMemories.count)
    }
}
