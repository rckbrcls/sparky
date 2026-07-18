#if os(macOS)
//
//  DesktopRootView.swift
//  sparky
//
//  Mac root shell: NavigationSplitView sidebar + detail.
//

import SwiftUI

struct DesktopRootView: View {
    @ObservedObject private var environment: AppEnvironment
    @StateObject private var nav = DesktopNavigationState()

    init(environment: AppEnvironment) {
        _environment = ObservedObject(wrappedValue: environment)
    }

    var body: some View {
        NavigationSplitView {
            DesktopSidebar(selection: $nav.selectedSection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(item: $nav.editorRoute) { route in
            editor(for: route)
                .frame(minWidth: 520, minHeight: 560)
        }
        .sheet(item: $nav.mindComposerRequest) { request in
            MindComposerView(
                environment: environment,
                mindToEdit: request.mindToEdit
            )
            .frame(minWidth: 420, minHeight: 360)
        }
        .sheet(isPresented: onboardingBinding) {
            OnboardingFlowView(environment: environment) {
                environment.completeOnboarding()
            }
            .frame(width: 560, height: 620)
            .interactiveDismissDisabled()
        }
        .alert(
            "Memory unavailable",
            isPresented: Binding(
                get: { nav.unavailableMemoryAlertMessage != nil },
                set: { if !$0 { nav.unavailableMemoryAlertMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    nav.unavailableMemoryAlertMessage = nil
                }
            },
            message: {
                Text(nav.unavailableMemoryAlertMessage ?? "")
            }
        )
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if nav.selectedSection == .mind {
                    Button {
                        nav.presentMindCreation()
                    } label: {
                        Label("New Mind", systemImage: "folder.badge.plus")
                    }
                    .help("New Mind")
                }

                Button {
                    nav.presentMemoryCreate()
                } label: {
                    Label("New Memory", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: [.command])
                .help("New Memory")
            }
        }
        .onChange(of: environment.pendingMemoryOpenRequest) { _, request in
            handlePendingMemoryOpen(request)
        }
        .onChange(of: environment.pendingFocusOpenRequest) { _, request in
            handlePendingFocusOpen(request)
        }
        .onChange(of: environment.hasBootstrapped) { _, ready in
            if ready {
                handlePendingMemoryOpen(environment.pendingMemoryOpenRequest)
                handlePendingFocusOpen(environment.pendingFocusOpenRequest)
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch nav.selectedSection {
        case .calendar:
            MemoryTimelineView(
                memoryService: environment.memoryService,
                onSelectMemory: handleMemorySelection,
                onEditMemory: handleMemoryEdit,
                onMultiSelectionChange: { _ in },
                navigationPath: $nav.calendarPath,
                embedsInNavigationStack: true
            )
        case .mind:
            MindRootView(
                mindService: environment.mindService,
                memoryService: environment.memoryService,
                navigationPath: $nav.mindsPath,
                onSelectMemory: handleMemorySelection,
                onEditMemory: handleMemoryEdit,
                onCreateMind: { nav.presentMindCreation() },
                onEditMind: { nav.presentMindEdit(for: $0) },
                onMultiSelectionChange: { _ in },
                onMindContextChange: { nav.currentMindContext = $0 },
                onSearchActiveChange: { _ in }
            )
        case .focus:
            FocusTabView(environment: environment)
        case .me:
            MeView(environment: environment, settingsNavigationPath: $nav.mePath)
        }
    }

    @ViewBuilder
    private func editor(for route: MemoryEditorRoute) -> some View {
        switch route.mode {
        case let .create(mind, template):
            MemoryEditorView(
                environment: environment,
                mode: .create(mind: mind, template: template),
                initialTitle: route.initialTitle
            )
        case let .preview(memory):
            MemoryEditorView(
                environment: environment,
                mode: .edit(memory: memory),
                startEditing: false
            )
        case let .edit(memory):
            MemoryEditorView(
                environment: environment,
                mode: .edit(memory: memory),
                startEditing: route.startEditing
            )
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: {
                environment.hasBootstrapped && !environment.hasCompletedOnboarding
            },
            set: { newValue in
                if !newValue {
                    environment.completeOnboarding()
                }
            }
        )
    }

    private func handleMemorySelection(_ memory: Memory) {
        nav.editorRoute = MemoryEditorRoute(mode: .preview(memory: memory))
    }

    private func handleMemoryEdit(_ memory: Memory) {
        nav.editorRoute = MemoryEditorRoute(mode: .edit(memory: memory), startEditing: true)
    }

    private func handlePendingMemoryOpen(_ request: PendingMemoryOpenRequest?) {
        guard let request, environment.hasBootstrapped else { return }
        environment.pendingMemoryOpenRequest = nil

        guard let memory = environment.memoryService.memory(id: request.memoryID) else {
            nav.handleMissingMemory()
            return
        }

        nav.selectedSection = .calendar
        nav.editorRoute = MemoryEditorRoute(mode: .preview(memory: memory))
    }

    private func handlePendingFocusOpen(_ request: PendingFocusOpenRequest?) {
        guard let request, environment.hasBootstrapped else { return }
        environment.pendingFocusOpenRequest = nil
        nav.selectedSection = .focus

        if let memory = environment.memoryService.memory(id: request.memoryID),
           memory.hasFocus {
            environment.startFocus(for: memory.id)
        }
    }
}

#Preview {
    let environment = AppEnvironment(dataController: DataController.preview)
    environment.bootstrap()
    return DesktopRootView(environment: environment)
        .environmentObject(environment)
}

#endif
