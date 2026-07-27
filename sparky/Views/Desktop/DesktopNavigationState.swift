#if os(macOS)
//
//  DesktopNavigationState.swift
//  sparky
//
//  Mac navigation and presentation state (ephemeral).
//

import SwiftUI
import Combine

enum DesktopSection: String, CaseIterable, Identifiable, Hashable {
    case calendar
    case mind
    case focus
    case me

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: return "Calendar"
        case .mind: return "Mind"
        case .focus: return "Focus"
        case .me: return "Me"
        }
    }

    var iconName: String {
        switch self {
        case .calendar: return "calendar"
        case .mind: return "mind"
        case .focus: return "timer"
        case .me: return "me"
        }
    }

    var usesAssetIcon: Bool {
        self == .mind || self == .me
    }
}

@MainActor
final class DesktopNavigationState: ObservableObject {
    @Published var selectedSection: DesktopSection = .calendar
    @Published var mindsPath = NavigationPath()
    @Published var mePath = NavigationPath()
    @Published var calendarMode: DesktopCalendarMode = .day
    @Published var calendarAnchorDate = Date()

    @Published var editorRoute: MemoryEditorRoute?
    @Published var mindComposerRequest: MindComposerRequest?
    @Published var isSearchPresented = false
    @Published var unavailableMemoryAlertMessage: String?
    @Published var currentMindContext: Mind?

    func openMemoryEditor(_ route: MemoryEditorRoute) {
        editorRoute = route
    }

    func presentMindCreation() {
        mindComposerRequest = MindComposerRequest(mindToEdit: nil)
    }

    func presentMindEdit(for mind: Mind) {
        mindComposerRequest = MindComposerRequest(mindToEdit: mind)
    }

    func handleMissingMemory() {
        unavailableMemoryAlertMessage = "This memory is no longer available."
    }

    func returnToRoot(of section: DesktopSection) {
        switch section {
        case .mind:
            mindsPath = NavigationPath()
            currentMindContext = nil
            isSearchPresented = false
        case .me:
            mePath = NavigationPath()
        case .calendar, .focus:
            break
        }
    }
}

#endif
