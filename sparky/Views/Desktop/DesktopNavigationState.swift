#if os(macOS)
//
//  DesktopNavigationState.swift
//  sparky
//
//  Mac sidebar navigation state (ephemeral).
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

    var systemImage: String {
        switch self {
        case .calendar: return "calendar"
        case .mind: return "brain.head.profile"
        case .focus: return "timer"
        case .me: return "person.crop.circle"
        }
    }
}

@MainActor
final class DesktopNavigationState: ObservableObject {
    @Published var selectedSection: DesktopSection = .calendar
    @Published var calendarPath = NavigationPath()
    @Published var mindsPath = NavigationPath()
    @Published var mePath = NavigationPath()

    @Published var editorRoute: MemoryEditorRoute?
    @Published var mindComposerRequest: MindComposerRequest?
    @Published var quickMemoryRequest: QuickMemoryRequest?
    @Published var unavailableMemoryAlertMessage: String?
    @Published var currentMindContext: Mind?

    func openMemoryEditor(_ route: MemoryEditorRoute) {
        editorRoute = route
    }

    func presentMemoryCreate(mind: Mind? = nil) {
        editorRoute = MemoryEditorRoute(
            mode: .create(mind: mind ?? currentMindContext, template: .blank)
        )
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
}

#endif
