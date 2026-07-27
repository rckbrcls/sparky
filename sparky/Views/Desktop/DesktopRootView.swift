#if os(macOS)
//
//  DesktopRootView.swift
//  sparky
//
//  Mac root shell with a unified toolbar and floating navigation.
//

import SwiftUI

struct DesktopRootView: View {
    @ObservedObject private var environment: AppEnvironment
    @StateObject private var nav = DesktopNavigationState()
    @State private var createMemoryRoute: MemoryEditorRoute?
    @State private var createMindRequest: MindComposerRequest?

    init(environment: AppEnvironment) {
        _environment = ObservedObject(wrappedValue: environment)
    }

    var body: some View {
        ZStack {
            desktopSurfaceColor
                .ignoresSafeArea()

            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 980, minHeight: 680)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DesktopFloatingNavigationBar(
                selection: $nav.selectedSection,
                createMemoryRoute: $createMemoryRoute,
                makeCreateMemoryRoute: {
                    MemoryEditorRoute(
                        mode: .create(
                            mind: nav.currentMindContext,
                            template: .blank
                        )
                    )
                }
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .containerBackground(desktopSurfaceColor, for: .window)
        .desktopMemoryEditorPopover(item: $nav.editorRoute)
        .popover(
            item: $nav.mindComposerRequest,
            attachmentAnchor: .rect(.bounds)
        ) { request in
            MindComposerView(
                environment: environment,
                mindToEdit: request.mindToEdit,
                presentationStyle: .desktopPopover
            )
            .frame(width: 440, height: 560)
        }
        .popover(
            isPresented: onboardingBinding,
            attachmentAnchor: .rect(.bounds)
        ) {
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
            if nav.selectedSection == .calendar {
                ToolbarItem(placement: .principal) {
                    Picker("Calendar view", selection: $nav.calendarMode) {
                        ForEach(DesktopCalendarMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel("Calendar view")
                }
            }

            ToolbarSpacer(.flexible)

            ToolbarItemGroup(placement: .primaryAction) {
                if nav.selectedSection == .calendar || nav.selectedSection == .mind {
                    Button {
                        nav.isSearchPresented.toggle()
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .keyboardShortcut("f", modifiers: [.command])
                    .help("Search Memories")
                    .popover(
                        isPresented: $nav.isSearchPresented,
                        arrowEdge: .top
                    ) {
                        DesktopMemorySearchPopover(
                            memoryService: environment.memoryService,
                            onSelect: handleSearchSelection
                        )
                    }
                }

                if nav.selectedSection == .mind && nav.mindsPath.isEmpty {
                    Button {
                        createMindRequest = MindComposerRequest(mindToEdit: nil)
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.Theme.textPrimary)
                    }
                    .help("Add Mind")
                    .accessibilityLabel("Add Mind")
                    .popover(
                        item: $createMindRequest,
                        attachmentAnchor: .rect(.bounds),
                        arrowEdge: .top
                    ) { request in
                        MindComposerView(
                            environment: environment,
                            mindToEdit: request.mindToEdit,
                            presentationStyle: .desktopPopover
                        )
                        .frame(width: 440, height: 560)
                    }
                }
            }
        }
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .onChange(of: nav.selectedSection) { _, section in
            if section != .calendar && section != .mind {
                nav.isSearchPresented = false
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

    private var desktopSurfaceColor: Color {
        Color.Theme.secondaryBackground
    }

    @ViewBuilder
    private var detailContent: some View {
        switch nav.selectedSection {
        case .calendar:
            DesktopCalendarView(
                memoryService: environment.memoryService,
                mode: $nav.calendarMode,
                anchorDate: $nav.calendarAnchorDate,
                onSelect: handleMemorySelection,
                onEdit: handleMemoryEdit
            )
        case .mind:
            MindRootView(
                mindService: environment.mindService,
                memoryService: environment.memoryService,
                navigationPath: $nav.mindsPath,
                onSelectMemory: handleMemorySelection,
                onEditMemory: handleMemoryEdit,
                onCreateMind: {
                    createMindRequest = MindComposerRequest(mindToEdit: nil)
                },
                onEditMind: { nav.presentMindEdit(for: $0) },
                onMultiSelectionChange: { _ in },
                onMindContextChange: { nav.currentMindContext = $0 },
                onSearchActiveChange: { _ in }
            )
        case .focus:
            FocusTabView(environment: environment)
        case .me:
            MeView(
                environment: environment,
                settingsNavigationPath: $nav.mePath
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

    private func handleSearchSelection(_ memory: Memory) {
        nav.isSearchPresented = false
        nav.selectedSection = .calendar
        handleMemorySelection(memory)
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
