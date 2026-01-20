//
//  ContentView.swift
//  i-cant-miss
//
//  Created by Erick Barcelos on 13/10/25.
//

import SwiftUI
import Combine
import UIKit

enum CustomTab: String, CaseIterable {
    case calendar = "Calendar"
    case mind = "Mind"
    case me = "Me"

    var symbol: String {
        switch self {
        case .calendar:
            return "calendar"
        case .mind:
            return "mind"
        case .me:
            return "me"
        }
    }

    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}


struct ContentView: View {
    @ObservedObject private var environment: AppEnvironment
    @State private var editorRoute: MemoryEditorRoute?
    @State private var lobeComposerRequest: LobeComposerRequest?
    @State private var mindComposerRequest: MindComposerRequest?
    @State private var activeTab: CustomTab = .calendar
    @State private var calendarNavigationPath = NavigationPath()
    @State private var triggersNavigationPath = NavigationPath()
    @State private var spacesNavigationPath = NavigationPath()
    @State private var meNavigationPath = NavigationPath()
    @State private var showingOnboarding = false
    @State private var isMultiSelectionActive = false
    @State private var isSearchActive = false
    @State private var currentLobeContext: LobeModel?
    @State private var currentMindContext: MindModel?
    @State private var quickMemoryRequest: QuickMemoryRequest?
    @State private var longPressTimer: Timer?
    @State private var hasTriggeredLongPress = false
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    init(environment: AppEnvironment) {
        _environment = ObservedObject(wrappedValue: environment)
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        VStack{
            TabView(selection: $activeTab){
                Tab.init(value: .calendar){
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
                        lobeService: environment.lobeService,
                        memoryService: environment.memoryService,
                        navigationPath: $spacesNavigationPath,
                        onSelectMemory: handleMemorySelection,
                        onEditMemory: handleMemoryEdit,
                        onCreateMind: {
                            presentMindCreation()
                        },
                        onEditMind: { mind in
                            presentMindEdit(for: mind)
                        },
                        onAddLobe: { mind in
                            presentLobeCreation(for: mind)
                        },
                        onMultiSelectionChange: handleMultiSelectionChange,
                        onLobeContextChange: { lobe in
                            currentLobeContext = lobe
                        },
                        onMindContextChange: { mind in
                            currentMindContext = mind
                        },
                        onSearchActiveChange: handleSearchActiveChange
                    )
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
            case let .create(lobe, template):
                MemoryEditorView(
                    environment: environment,
                    mode: .create(lobe: lobe, template: template),
                    initialTitle: route.initialTitle
                )
            case let .edit(memory):
                MemoryEditorView(
                    environment: environment,
                    mode: .edit(memory: memory),
                    startEditing: route.startEditing
                )
            }
        }
        .sheet(item: $lobeComposerRequest, onDismiss: {
            lobeComposerRequest = nil
        }) { request in
            LobeComposerView(
                environment: environment,
                lobeToEdit: request.lobeToEdit,
                mindID: request.mindID
            )
        }
        .sheet(item: $mindComposerRequest, onDismiss: {
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
                lobe: request.lobe,
                onExpandToEditor: { lobe, title in
                    editorRoute = MemoryEditorRoute(
                        mode: .create(lobe: lobe, template: .blank),
                        initialTitle: title
                    )
                },
                onQuickCreate: { lobe, title, reminderMinutes in
                    Task {
                        // Create triggers array with single alarm if selected
                        var triggers: [MemoryTriggerModel] = []
                        if let minutes = reminderMinutes {
                            let alarmTrigger = MemoryModel.createSingleAlarmTrigger(
                                minutes: minutes,
                                fromDate: Date()
                            )
                            triggers.append(alarmTrigger)
                        }

                        let draft = MemoryDraft(
                            id: UUID(),
                            title: title,
                            status: .active,
                            isPinned: false,
                            dueDate: nil,
                            lobeID: lobe?.id,
                            triggers: triggers,
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
            OnboardingFlowView {
                environment.completeOnboarding()
                showingOnboarding = false
            }
        }
        .onAppear {
            UITabBar.appearance().isHidden = true
            showingOnboarding = !environment.hasCompletedOnboarding
        }
        .onChange(of: environment.hasCompletedOnboarding) { _, completed in
            withAnimation(.easeInOut) {
                showingOnboarding = !completed
            }
        }
        .onChange(of: activeTab) { _, newTab in
            // Clear context when switching away from mind tab
            if newTab != .mind {
                currentLobeContext = nil
                currentMindContext = nil
            }
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
                        activeTint: Color.accent,
                        barTint: Color.gray.opacity(0.15),
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

    private func prepareMemoryCreation(for lobe: LobeModel?) {
        quickMemoryRequest = QuickMemoryRequest(lobe: lobe)
    }

    private func openMemoryEditorDirectly() {
        feedbackGenerator.impactOccurred()
        editorRoute = MemoryEditorRoute(
            mode: .create(lobe: targetLobeForCreation(), template: .blank)
        )
    }

    private func handleMemorySelection(_ memory: MemoryModel) {
        editorRoute = MemoryEditorRoute(mode: .edit(memory: memory))
    }

    private func handleMemoryEdit(_ memory: MemoryModel) {
        var route = MemoryEditorRoute(mode: .edit(memory: memory))
        route.startEditing = true
        editorRoute = route
    }

    private func presentLobeCreation() {
        lobeComposerRequest = LobeComposerRequest(lobeToEdit: nil, mindID: nil)
    }

    private func presentLobeEdit(for lobe: LobeModel) {
        lobeComposerRequest = LobeComposerRequest(lobeToEdit: lobe, mindID: nil)
    }

    private func presentLobeCreation(for mind: MindModel) {
        lobeComposerRequest = LobeComposerRequest(lobeToEdit: nil, mindID: mind.id)
    }

    private func presentMindCreation() {
        mindComposerRequest = MindComposerRequest(mindToEdit: nil)
    }

    private func presentMindEdit(for mind: MindModel) {
        mindComposerRequest = MindComposerRequest(mindToEdit: mind)
    }

    private func handleTabReselection(_ tab: CustomTab) {
        switch tab {
        case .calendar:
            calendarNavigationPath = NavigationPath()
        case .mind:
            // Se estiver em LobeDetailView (tem currentLobeContext), fazer pop até MindDetailView
            // Se estiver em MindDetailView (tem currentMindContext mas não currentLobeContext), limpar e ir para MindRootView
            // Se já estiver em MindRootView (não tem currentMindContext), não fazer nada
            if currentLobeContext != nil {
                // Está em LobeDetailView, fazer pop até MindDetailView
                spacesNavigationPath.removeLast()
            } else if currentMindContext != nil {
                // Está em MindDetailView, limpar e ir para MindRootView
                spacesNavigationPath = NavigationPath()
                currentMindContext = nil
            }
            // Se não tem currentMindContext, já está em MindRootView, não faz nada
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
        Image("plus")
            .resizable()
            .scaledToFit()
            .frame(width: 60, height: 60)
            .contentShape(Rectangle())
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
                            prepareMemoryCreation(for: targetLobeForCreation())
                        }
                    }
            )
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
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

    private func targetLobeForCreation() -> LobeModel? {
        guard activeTab == .mind else { return nil }
        // Use currentLobeContext if available, otherwise try to extract from navigation path
        if let context = currentLobeContext {
            return context
        }
        // Fallback: try to get the last lobe from navigation path
        // This is a workaround since NavigationPath doesn't expose its items directly
        // The LobeDetailView should have already notified the context, but this is a safety net
        return extractLastLobeFromNavigationPath()
    }

    private func extractLastLobeFromNavigationPath() -> LobeModel? {
        // NavigationPath doesn't expose items directly, so we rely on currentLobeContext
        // which should be set by LobeDetailView.onAppear
        // If it's nil here, it means we're at the root, so return nil
        return nil
    }
}

private struct MemoryEditorRoute: Identifiable {
    enum Mode {
        case create(lobe: LobeModel?, template: MemoryEditorTemplate)
        case edit(memory: MemoryModel)
    }

    let id = UUID()
    let mode: Mode
    var initialTitle: String = ""
    var startEditing: Bool = false
}

private struct LobeComposerRequest: Identifiable {
    let id = UUID()
    let lobeToEdit: LobeModel?
    let mindID: UUID?
}

private struct MindComposerRequest: Identifiable {
    let id = UUID()
    let mindToEdit: MindModel?
}

private struct QuickMemoryRequest: Identifiable {
    let id = UUID()
    let lobe: LobeModel?
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
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return ContentView(environment: environment)
        .environmentObject(environment)
}
