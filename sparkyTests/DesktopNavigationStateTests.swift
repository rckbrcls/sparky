#if os(macOS)

import Foundation
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
        let state = DesktopNavigationState(defaults: isolatedDefaults("defaults"))

        #expect(DesktopCalendarMode.allCases == [.day, .week, .month])
        #expect(DesktopCalendarMode.day.title == "Day")
        #expect(DesktopCalendarMode.week.title == "Week")
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
        let state = DesktopNavigationState(defaults: isolatedDefaults("anchor"))
        let anchor = Date(timeIntervalSince1970: 1_785_105_600)
        let now = Date(timeIntervalSince1970: 1_785_192_000)
        state.calendarAnchorDate = anchor

        state.calendarMode = .month
        #expect(state.calendarAnchorDate == anchor)

        state.calendarAnchorDate = now
        #expect(state.calendarMode == .month)
        #expect(state.calendarAnchorDate == now)
    }

    @Test("Saved calendar mode is restored and later changes are stored")
    func calendarModePersists() {
        let defaults = isolatedDefaults("calendarMode")
        defaults.set(DesktopCalendarMode.week.rawValue, forKey: "desktop.calendarMode")

        let restored = DesktopNavigationState(defaults: defaults)
        #expect(restored.calendarMode == .week)

        restored.calendarMode = .month
        #expect(defaults.string(forKey: "desktop.calendarMode") == DesktopCalendarMode.month.rawValue)

        defaults.set("year", forKey: "desktop.calendarMode")
        let fallback = DesktopNavigationState(defaults: defaults)
        #expect(fallback.calendarMode == .day)
    }

    @Test("Reselecting Mind and Me returns their navigation to the root")
    func reselectingNestedSectionsReturnsToRoot() {
        let state = DesktopNavigationState(defaults: isolatedDefaults("roots"))
        state.mindsPath.append("parent mind")
        state.mindsPath.append("nested mind")
        state.currentMindContext = Mind(name: "Work")
        state.isSearchPresented = true

        state.returnToRoot(of: .mind)
        state.returnToRoot(of: .mind)

        #expect(state.mindsPath.isEmpty)
        #expect(state.currentMindContext == nil)
        #expect(!state.isSearchPresented)

        state.mePath.append("settings")
        state.mePath.append("focus settings")
        state.returnToRoot(of: .me)
        state.returnToRoot(of: .me)

        #expect(state.mePath.isEmpty)
    }

    @Test("Reselecting Calendar and Focus preserves active state")
    func reselectingSessionSectionsIsANoOp() {
        let state = DesktopNavigationState(defaults: isolatedDefaults("sessions"))
        let anchor = Date(timeIntervalSince1970: 1_785_105_600)
        state.calendarMode = .month
        state.calendarAnchorDate = anchor
        state.isSearchPresented = true

        state.returnToRoot(of: .calendar)
        state.returnToRoot(of: .focus)

        #expect(state.calendarMode == .month)
        #expect(state.calendarAnchorDate == anchor)
        #expect(state.isSearchPresented)
    }

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suite = "DesktopNavigationStateTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

#endif
