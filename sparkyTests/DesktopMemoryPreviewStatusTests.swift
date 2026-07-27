#if os(macOS)

import Testing
@testable import sparky

@MainActor
struct DesktopMemoryPreviewStatusTests {
    @Test func activeStatusUsesEmptyCompletionCircle() {
        #expect(MemoryStatus.active.desktopPreviewSystemImage == "circle")
        #expect(
            MemoryStatus.active.desktopPreviewActionLabel
                == "Complete Memory"
        )
    }

    @Test func completedStatusUsesFilledCheckedCircle() {
        #expect(
            MemoryStatus.completed.desktopPreviewSystemImage
                == "checkmark.circle.fill"
        )
        #expect(
            MemoryStatus.completed.desktopPreviewActionLabel
                == "Reopen Memory"
        )
    }
}

#endif
