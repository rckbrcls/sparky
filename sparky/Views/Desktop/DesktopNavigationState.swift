#if os(macOS)
//
//  DesktopNavigationState.swift
//  sparky
//
//  Mac navigation and presentation state.
//  Calendar mode is remembered between launches.
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
    private enum Keys {
        static let calendarMode = "desktop.calendarMode"
    }

    private let defaults: UserDefaults

    @Published var selectedSection: DesktopSection = .calendar
    @Published var mindsPath = NavigationPath()
    @Published var mePath = NavigationPath()
    @Published var calendarMode: DesktopCalendarMode {
        didSet {
            defaults.set(calendarMode.rawValue, forKey: Keys.calendarMode)
        }
    }
    @Published var calendarAnchorDate = Date()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Keys.calendarMode) ?? ""
        self.calendarMode = DesktopCalendarMode(rawValue: stored) ?? .day
    }

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
