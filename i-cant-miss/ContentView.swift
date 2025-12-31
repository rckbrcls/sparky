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
    case memories = "Memories"
    case me = "Me"

    var symbol: String {
        switch self {
        case .calendar:
            return "calendar"
        case .memories:
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
    @State private var spaceComposerRequest: SpaceComposerRequest?
    @State private var activeTab: CustomTab = .calendar
    @State private var calendarNavigationPath = NavigationPath()
    @State private var triggersNavigationPath = NavigationPath()
    @State private var spacesNavigationPath = NavigationPath()
    @State private var meNavigationPath = NavigationPath()
    @State private var showingOnboarding = false
    @State private var isMultiSelectionActive = false
    @State private var isSearchActive = false
    @State private var currentSpaceContext: SpaceModel?
    @State private var quickMemoryRequest: QuickMemoryRequest?

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

                Tab.init(value: .memories){
                    SpacesRootView(
                        spaceService: environment.spaceService,
                        memoryService: environment.memoryService,
                        navigationPath: $spacesNavigationPath,
                        onSelectMemory: handleMemorySelection,
                        onEditMemory: handleMemoryEdit,
                onCreateSpace: {
                    presentSpaceCreation()
                        },
                        onEditSpace: { space in
                            presentSpaceEdit(for: space)
                        },
                        onMultiSelectionChange: handleMultiSelectionChange,
                        onSpaceContextChange: { space in
                            // Update context immediately when space changes
                            currentSpaceContext = space
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
            case let .create(space, template):
                MemoryEditorView(
                    environment: environment,
                    mode: .create(space: space, template: template),
                    initialTitle: route.initialTitle
                )
            case let .edit(memory):
                MemoryEditorView(
                    environment: environment,
                    mode: .edit(memory: memory)
                )
            }
        }
        .sheet(item: $spaceComposerRequest, onDismiss: {
            spaceComposerRequest = nil
        }) { request in
            SpaceComposerView(
                environment: environment,
                spaceToEdit: request.spaceToEdit
            )
        }
        .sheet(item: $quickMemoryRequest, onDismiss: {
            quickMemoryRequest = nil
        }) { request in
            QuickMemorySheet(
                environment: environment,
                space: request.space,
                onExpandToEditor: { space, title in
                    editorRoute = MemoryEditorRoute(
                        mode: .create(space: space, template: .blank),
                        initialTitle: title
                    )
                },
                onQuickCreate: { space, title, reminderMinutes in
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
                            spaceID: space?.id,
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
            // Clear context when switching away from spaces tab
            if newTab != .memories {
                currentSpaceContext = nil
            }
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
                            if tab == .memories || tab == .me {
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

    private func prepareMemoryCreation(for space: SpaceModel?) {
        quickMemoryRequest = QuickMemoryRequest(space: space)
    }

    private func handleMemorySelection(_ memory: MemoryModel) {
        editorRoute = MemoryEditorRoute(mode: .edit(memory: memory))
    }

    private func handleMemoryEdit(_ memory: MemoryModel) {
        editorRoute = MemoryEditorRoute(mode: .edit(memory: memory))
    }

    private func presentSpaceCreation() {
        spaceComposerRequest = SpaceComposerRequest(spaceToEdit: nil)
    }

    private func presentSpaceEdit(for space: SpaceModel) {
        spaceComposerRequest = SpaceComposerRequest(spaceToEdit: space)
    }

    private func handleTabReselection(_ tab: CustomTab) {
        switch tab {
        case .calendar:
            calendarNavigationPath = NavigationPath()
        case .memories:
            spacesNavigationPath = NavigationPath()
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
        Button(action: { prepareMemoryCreation(for: targetSpaceForCreation()) }) {
            Image("plus")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
        }
        .buttonStyle(.plain)
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

    private func targetSpaceForCreation() -> SpaceModel? {
        guard activeTab == .memories else { return nil }
        // Use currentSpaceContext if available, otherwise try to extract from navigation path
        if let context = currentSpaceContext {
            return context
        }
        // Fallback: try to get the last space from navigation path
        // This is a workaround since NavigationPath doesn't expose its items directly
        // The SpaceDetailView should have already notified the context, but this is a safety net
        return extractLastSpaceFromNavigationPath()
    }

    private func extractLastSpaceFromNavigationPath() -> SpaceModel? {
        // NavigationPath doesn't expose items directly, so we rely on currentSpaceContext
        // which should be set by SpaceDetailView.onAppear
        // If it's nil here, it means we're at the root, so return nil
        return nil
    }
}

private struct MemoryEditorRoute: Identifiable {
    enum Mode {
        case create(space: SpaceModel?, template: MemoryEditorTemplate)
        case edit(memory: MemoryModel)
    }

    let id = UUID()
    let mode: Mode
    var initialTitle: String = ""
}

private struct SpaceComposerRequest: Identifiable {
    let id = UUID()
    let spaceToEdit: SpaceModel?
}

private struct QuickMemoryRequest: Identifiable {
    let id = UUID()
    let space: SpaceModel?
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
