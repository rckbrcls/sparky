#if os(macOS)

import Testing
@testable import sparky

@MainActor
@Suite("Desktop navigation")
struct DesktopNavigationStateTests {
    @Test("Desktop exposes the same four primary destinations as mobile")
    func primarySections() {
        #expect(DesktopSection.allCases == [.calendar, .mind, .focus, .me])
        #expect(DesktopSection.mind.iconName == "mind")
        #expect(DesktopSection.me.iconName == "me")
        #expect(DesktopSection.mind.usesAssetIcon)
        #expect(DesktopSection.me.usesAssetIcon)
    }

    @Test("Calendar starts in Day and desktop destinations remain selectable")
    func defaultsAndDeepLinkDestination() {
        let state = DesktopNavigationState()

        #expect(DesktopCalendarMode.allCases == [.day, .month])
        #expect(DesktopCalendarMode.day.title == "Day")
        #expect(DesktopCalendarMode.month.title == "Month")
        #expect(state.calendarMode == .day)
        state.selectedSection = .focus
        #expect(state.selectedSection == .focus)
        state.selectedSection = .me
        #expect(state.selectedSection == .me)
        #expect(state.mePath.isEmpty)
    }

    @Test("Changing mode preserves the anchor and Today restores it explicitly")
    func anchorNavigationState() {
        let state = DesktopNavigationState()
        let anchor = Date(timeIntervalSince1970: 1_785_105_600)
        let now = Date(timeIntervalSince1970: 1_785_192_000)
        state.calendarAnchorDate = anchor

        state.calendarMode = .month
        #expect(state.calendarAnchorDate == anchor)

        state.calendarAnchorDate = now
        #expect(state.calendarMode == .month)
        #expect(state.calendarAnchorDate == now)
    }
}

#endif
