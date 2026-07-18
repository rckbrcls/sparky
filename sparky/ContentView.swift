//
//  ContentView.swift
//  sparky
//
//  Created by Erick Barcelos on 13/10/25.
//

import SwiftUI
import Combine
import UIKit

enum CustomTab: String, CaseIterable {
    case calendar = "Calendar"
    case mind = "Mind"
    case focus = "Focus"
    case me = "Me"

    var symbol: String {
        switch self {
        case .calendar:
            return "calendar"
        case .mind:
            return "mind"
        case .focus:
            return "timer"
        case .me:
            return "me"
        }
    }

    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}


struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var environment: AppEnvironment
    @State private var editorRoute: MemoryEditorRoute?
    @State private var mindComposerRequest: MindComposerRequest?
    @State private var activeTab: CustomTab = .calendar
    @State private var calendarNavigationPath = NavigationPath()
    @State private var triggersNavigationPath = NavigationPath()
    @State private var mindsNavigationPath = NavigationPath()
    @State private var meNavigationPath = NavigationPath()
    @State private var showingOnboarding = false
    @State private var isMultiSelectionActive = false
    @State private var isSearchActive = false
    @State private var currentMindContext: Mind?
    @State private var quickMemoryRequest: QuickMemoryRequest?
    @State private var longPressTimer: Timer?
    @State private var hasTriggeredLongPress = false
    @State private var unavailableMemoryAlertMessage: String?
    @State private var focusSessionRoute: FocusSessionRoute?
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    init(environment: AppEnvironment) {
        _environment = ObservedObject(wrappedValue: environment)
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        VStack{
            TabView(selection: $activeTab){
                Tab.init(value: .calendar) {
                    MemoryTimelineView(
                        memoryService: environment.memoryService,
                        onSelectMemory: handleMemorySelection,
                        onEditMemory: handleMemoryEdit,
                        onMultiSelectionChange: handleMultiSelectionChange,
                        navigationPath: $calendarNavigationPath,
                        embedsInNavigationStack: true
                    )
                    .tabBarSpacer()
                }

                Tab.init(value: .mind){
                    MindRootView(
                        mindService: environment.mindService,
                        memoryService: environment.memoryService,
                        navigationPath: $mindsNavigationPath,
                        onSelectMemory: handleMemorySelection,
                        onEditMemory: handleMemoryEdit,
                        onCreateMind: {
                            presentMindCreation()
                        },
                        onEditMind: { mind in
                            presentMindEdit(for: mind)
                        },
                        onMultiSelectionChange: handleMultiSelectionChange,
                        onMindContextChange: { mind in
                            currentMindContext = mind
                        },
                        onSearchActiveChange: handleSearchActiveChange
                    )
                    .tabBarSpacer()
                }

                Tab.init(value: .focus) {
                    FocusTabView(environment: environment)
                        .tabBarSpacer()
                }

                Tab.init(value: .me){
                    MeView(environment: environment, settingsNavigationPath: $meNavigationPath)
                        .tabBarSpacer()
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaBar(edge: .bottom, spacing: 0){
                Group {
                    if isMultiSelectionActive {
                        Color.clear.frame(height: 0)
                    } else {
                CustomTabBarView()
                    .padding(.horizontal, 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isMultiSelectionActive)
        .animation(.easeInOut(duration: 0.2), value: isSearchActive)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .fullScreenCover(item: $editorRoute) { route in
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
        .fullScreenCover(item: $mindComposerRequest, onDismiss: {
            mindComposerRequest = nil
        }) { request in
            MindComposerView(
                environment: environment,
                mindToEdit: request.mindToEdit
            )
        }
        .sheet(item: $quickMemoryRequest, onDismiss: {
            quickMemoryRequest = nil
        }) { request in
            QuickMemorySheet(
                environment: environment,
                mind: request.mind,
                onExpandToEditor: { mind, title in
                    editorRoute = MemoryEditorRoute(
                        mode: .create(mind: mind, template: .blank),
                        initialTitle: title
                    )
                },
                onQuickCreate: { mind, title, reminderMinutes in
                    Task {
                        var scheduleDraft: ScheduleConfigDraft?
                        if let minutes = reminderMinutes {
                            let fireDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
                            scheduleDraft = ScheduleConfigDraft(
                                fireDate: fireDate,
                                startDate: fireDate,
                                timeZoneIdentifier: TimeZone.current.identifier,
                                isActive: true
                            )
                        }

                        let draft = MemoryDraft(
                            id: UUID(),
                            title: title,
                            status: .active,
                            isPinned: false,
                            dueDate: nil,
                            mindID: mind?.id,
                            scheduleConfig: scheduleDraft,
                            note: nil,
                            checkItems: [],
                            photoAttachmentIDs: [],
                            linkAttachmentIDs: [],
                            audioAttachmentIDs: [],
                            fileAttachmentIDs: [],
                            attachments: [],
                            autoCompleteOnChecklistCompletion: false
                        )
                        _ = try? await environment.memoryService.createMemory(from: draft)
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingFlowView(environment: environment) {
                environment.completeOnboarding()
                showingOnboarding = false
            }
        }
        .fullScreenCover(item: $focusSessionRoute, onDismiss: {
            focusSessionRoute = nil
        }) { _ in
            FocusSessionView(
                timer: environment.focusTimer,
                onClose: {
                    // Dismiss only — session continues in Focus tab.
                    focusSessionRoute = nil
                    activeTab = .focus
                }
            )
        }
        .onAppear {
            UITabBar.appearance().isHidden = true
            showingOnboarding = !environment.hasCompletedOnboarding
            tryConsumePendingMemoryOpenRequest()
            tryConsumePendingFocusOpenRequest()
        }
        .onChange(of: environment.hasCompletedOnboarding) { _, completed in
            guard completed else { return }
            withAnimation(.easeInOut) {
                showingOnboarding = false
            }
        }
        .onChange(of: environment.pendingMemoryOpenRequest) { _, _ in
            tryConsumePendingMemoryOpenRequest()
        }
        .onChange(of: environment.pendingFocusOpenRequest) { _, _ in
            tryConsumePendingFocusOpenRequest()
        }
        .onChange(of: hasBlockingPresentation) { _, _ in
            tryConsumePendingMemoryOpenRequest()
            tryConsumePendingFocusOpenRequest()
        }
        .onChange(of: environment.hasBootstrapped) { _, _ in
            tryConsumePendingMemoryOpenRequest()
            tryConsumePendingFocusOpenRequest()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                environment.focusTimer.refreshFromWallClock()
            }
            tryConsumePendingMemoryOpenRequest()
            tryConsumePendingFocusOpenRequest()
        }
        .onReceive(environment.memoryService.$lastRefreshed.receive(on: RunLoop.main)) { _ in
            tryConsumePendingMemoryOpenRequest()
            tryConsumePendingFocusOpenRequest()
        }
        .onChange(of: activeTab) { _, newTab in
            // Clear context when switching away from mind tab
            if newTab != .mind {
                currentMindContext = nil
            }
        }
        .alert("Memory unavailable", isPresented: Binding(
            get: { unavailableMemoryAlertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    unavailableMemoryAlertMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(unavailableMemoryAlertMessage ?? "")
        }
        .onDisappear {
            // Limpa o timer quando a view desaparece
            longPressTimer?.invalidate()
            longPressTimer = nil
        }
    }

    @ViewBuilder
    func CustomTabBarView () -> some View {
        GlassEffectContainer(spacing: 10){
            HStack(spacing: 0){
                GeometryReader{
                    CustomTabBar(
                        size: $0.size,
                        activeTint: Color.Theme.accentForeground,
                        inactiveTint: Color.Theme.textSecondary,
                        barTint: Color.accentColor,
                        activeTab: $activeTab,
                        tabItemView: { tab in
                        VStack(spacing: 3){
                            if tab == .mind || tab == .me {
                                Image(tab.symbol)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 24)
                            } else {
                                Image(systemName: tab.symbol)
                                    .font(.title3)
                            }

                            Text(tab.rawValue)
                                .font(.system(size: 10))
                                .fontWeight(.medium)
                        }
                        .symbolVariant(.fill)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(tab == .focus ? "Focus" : tab.rawValue)
                    },
                        onTabReselected: handleTabReselection
                    )
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .contentShape(Rectangle())
                }

                Color.clear
                    .frame(width: 10)
                    .contentShape(Rectangle())
                    .onTapGesture {
                    }

                addMemoryButton
            }
        }
        .frame(height: 55)
    }

    private func prepareMemoryCreation(for mind: Mind?) {
        quickMemoryRequest = QuickMemoryRequest(mind: mind)
    }

    private func openMemoryEditorDirectly() {
        feedbackGenerator.impactOccurred()
        editorRoute = MemoryEditorRoute(
            mode: .create(mind: targetMindForCreation(), template: .blank)
        )
    }

    private func handleMemorySelection(_ memory: Memory) {
        editorRoute = MemoryEditorRoute(mode: .edit(memory: memory))
    }

    private func handleMemoryEdit(_ memory: Memory) {
        var route = MemoryEditorRoute(mode: .edit(memory: memory))
        route.startEditing = true
        editorRoute = route
    }

    private func presentMindCreation() {
        mindComposerRequest = MindComposerRequest(mindToEdit: nil)
    }

    private func presentMindEdit(for mind: Mind) {
        mindComposerRequest = MindComposerRequest(mindToEdit: mind)
    }

    private func handleTabReselection(_ tab: CustomTab) {
        switch tab {
        case .calendar:
            calendarNavigationPath = NavigationPath()
        case .mind:
            if !mindsNavigationPath.isEmpty {
                mindsNavigationPath.removeLast()
            }
        case .focus:
            break
        case .me:
            meNavigationPath = NavigationPath()
        }
    }

    private var tabBarVisibility: Visibility {
        (isMultiSelectionActive || isSearchActive) ? .hidden : .visible
    }

    private var shouldShowAddButton: Bool {
        !isMultiSelectionActive && !isSearchActive
    }

    private var bottomSafeInset: CGFloat {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = scene.windows.first(where: { $0.isKeyWindow })
        else { return 0 }
        return window.safeAreaInsets.bottom
    }

    private var addMemoryButton: some View {
        Image(systemName: "brain.fill")
            .foregroundColor(.elementBorder)
            .font(.system(size: 22, weight: .medium))
            .frame(width: 60, height: 60)
            .contentShape(Rectangle())
            .glassEffect(.regular.interactive().tint(Color.accent), in: .circle)
            .accessibilityLabel("Create new memory")
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        // Quando começa a pressionar, inicia o timer se ainda não iniciou
                        if longPressTimer == nil {
                            hasTriggeredLongPress = false
                            longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                // Após 0.5 segundos, executa o long press
                                hasTriggeredLongPress = true
                                openMemoryEditorDirectly()
                                longPressTimer?.invalidate()
                                longPressTimer = nil
                            }
                        }
                    }
                    .onEnded { _ in
                        // Quando solta
                        let wasLongPress = hasTriggeredLongPress
                        longPressTimer?.invalidate()
                        longPressTimer = nil
                        hasTriggeredLongPress = false

                        // Se não foi long press, executa ação normal
                        if !wasLongPress {
                            prepareMemoryCreation(for: targetMindForCreation())
                        }
                    }
            )
    }

    private func handleMultiSelectionChange(_ isSelecting: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            isMultiSelectionActive = isSelecting
        }
    }

    private func handleSearchActiveChange(_ isSearching: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSearchActive = isSearching
        }
    }

    private var hasBlockingPresentation: Bool {
        showingOnboarding
            || mindComposerRequest != nil
            || quickMemoryRequest != nil
            || editorRoute != nil
            || focusSessionRoute != nil
    }

    private func tryConsumePendingMemoryOpenRequest() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                tryConsumePendingMemoryOpenRequest()
            }
            return
        }

        guard let request = environment.pendingMemoryOpenRequest else { return }
        guard scenePhase == .active else { return }
        guard !hasBlockingPresentation else { return }

        if let memory = environment.memoryService.memory(id: request.memoryID) {
            environment.pendingMemoryOpenRequest = nil
            editorRoute = MemoryEditorRoute(mode: .preview(memory: memory))
            return
        }

        guard environment.hasBootstrapped else { return }
        environment.pendingMemoryOpenRequest = nil
        unavailableMemoryAlertMessage = "This memory is no longer available."
    }

    private func tryConsumePendingFocusOpenRequest() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                tryConsumePendingFocusOpenRequest()
            }
            return
        }

        guard let request = environment.pendingFocusOpenRequest else { return }
        guard scenePhase == .active else { return }
        // Focus can present over editor, but not onboarding.
        guard !showingOnboarding else { return }

        if let memory = environment.memoryService.memory(id: request.memoryID),
           memory.hasFocus {
            environment.pendingFocusOpenRequest = nil
            if let recipe = memory.focusRecipe() {
                if environment.focusTimer.activeMemoryID != memory.id || !environment.focusTimer.isSessionActive {
                    if environment.focusTimer.wouldReplaceSession(withMemoryID: memory.id) {
                        environment.focusTimer.endSession()
                    }
                    environment.focusTimer.beginSession(
                        memoryID: memory.id,
                        memoryTitle: memory.title,
                        recipe: recipe
                    )
                }
            }
            activeTab = .focus
            // Optional cover when coming from notification while another modal is up.
            if editorRoute != nil {
                focusSessionRoute = FocusSessionRoute()
            }
            return
        }

        guard environment.hasBootstrapped else { return }
        environment.pendingFocusOpenRequest = nil
    }

    private func targetMindForCreation() -> Mind? {
        guard activeTab == .mind else { return nil }
        if let context = currentMindContext {
            return context
        }
        return nil
    }
}

private struct MemoryEditorRoute: Identifiable {
    enum Mode {
        case create(mind: Mind?, template: MemoryEditorTemplate)
        case preview(memory: Memory)
        case edit(memory: Memory)
    }

    let id = UUID()
    let mode: Mode
    var initialTitle: String = ""
    var startEditing: Bool = false
}

private struct MindComposerRequest: Identifiable {
    let id = UUID()
    let mindToEdit: Mind?
}

private struct QuickMemoryRequest: Identifiable {
    let id = UUID()
    let mind: Mind?
}

private struct FocusSessionRoute: Identifiable {
    let id = UUID()
}

extension View{
    @ViewBuilder
    func blurFade(_ status: Bool ) -> some View {
        self
            .compositingGroup()
            .blur(radius: status ? 0 : 10)
            .opacity(status ? 1 : 0)
    }
}

#Preview {
    let environment = AppEnvironment(dataController: DataController.preview)
    environment.bootstrap()
    return ContentView(environment: environment)
        .environmentObject(environment)
}
