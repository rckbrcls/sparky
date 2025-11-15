//
//  ContentView.swift
//  i-cant-miss
//
//  Created by Erick Barcelos on 13/10/25.
//

import SwiftUI
import Combine

enum CustomTab: String, CaseIterable {
    case home = "Timeline"
    case spaces = "Spaces"
    case settings = "Settings"

    var symbol :String {
        switch self {
        case .home:
            return "list.bullet.rectangle"
        case .spaces:
            return "square.grid.2x2"
        case .settings:
            return "gearshape"
        }
    }

    var actionSymbol :String {
        switch self {
        case .home:
            return "plus"
        case .spaces:
            return "plus"
        case .settings:
            return "plus"
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
    @State private var activeTab: CustomTab = .home
    @State private var homeNavigationPath = NavigationPath()
    @State private var spacesNavigationPath = NavigationPath()
    @State private var settingsNavigationPath = NavigationPath()
    @State private var showingOnboarding = false
    @State private var isMultiSelectionActive = false
    @State private var currentSpaceContext: SpaceModel?

    init(environment: AppEnvironment) {
        _environment = ObservedObject(wrappedValue: environment)
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        VStack{
            TabView(selection: $activeTab){
                Tab.init(value: .home){
                    MemoryTimelineView(
                        memoryService: environment.memoryService,
                        onSelectMemory: handleMemorySelection,
                        onMultiSelectionChange: handleMultiSelectionChange,
                        navigationPath: $homeNavigationPath
                    )
                    .tabBarSpacer()
                }

                Tab.init(value: .spaces){
                    SpacesRootView(
                        spaceService: environment.spaceService,
                        memoryService: environment.memoryService,
                        navigationPath: $spacesNavigationPath,
                        onSelectMemory: handleMemorySelection,
                        onCreateSpace: { parent in
                            presentSpaceCreation(for: parent)
                        },
                        onMultiSelectionChange: handleMultiSelectionChange,
                        onSpaceContextChange: { space in
                            currentSpaceContext = space
                        }
                    )
                    .tabBarSpacer()
                }

                Tab.init(value: .settings){
                    SettingsView(environment: environment, navigationPath: $settingsNavigationPath)
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
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .fullScreenCover(item: $editorRoute) { route in
            switch route.mode {
            case let .create(space, template):
                MemoryEditorView(
                    environment: environment,
                    mode: .create(space: space, template: template)
                )
            case let .edit(memory):
                MemoryEditorView(
                    environment: environment,
                    mode: .edit(memory: memory)
                )
            case let .view(memory):
                MemoryEditorView(
                    environment: environment,
                    mode: .view(memory: memory)
                )
            }
        }
        .sheet(item: $spaceComposerRequest, onDismiss: {
            spaceComposerRequest = nil
        }) { request in
            SpaceComposerView(environment: environment, defaultParent: request.parent)
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
                            Image(systemName: tab.symbol)
                                .font(.title3)

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

                Button(action: { prepareMemoryCreation(for: targetSpaceForCreation()) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .frame(width: 60, height: 60)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive().tint(Color.accent), in: .capsule)
                .animation(.smooth(duration: 0.55 , extraBounce: 0), value: activeTab)
                .contentShape(Rectangle())
            }
        }
        .frame(height: 55)
    }

    private func prepareMemoryCreation(for space: SpaceModel?) {
        editorRoute = MemoryEditorRoute(mode: .create(space: space, template: .blank))
    }

    private func handleMemorySelection(_ memory: MemoryModel) {
        editorRoute = MemoryEditorRoute(mode: .view(memory: memory))
    }

    private func presentSpaceCreation(for parent: SpaceModel?) {
        spaceComposerRequest = SpaceComposerRequest(parent: parent)
    }

    private func handleTabReselection(_ tab: CustomTab) {
        switch tab {
        case .home:
            homeNavigationPath = NavigationPath()
        case .spaces:
            spacesNavigationPath = NavigationPath()
        case .settings:
            settingsNavigationPath = NavigationPath()
        }
    }

    private func handleMultiSelectionChange(_ isSelecting: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            isMultiSelectionActive = isSelecting
        }
    }

    private func targetSpaceForCreation() -> SpaceModel? {
        guard activeTab == .spaces else { return nil }
        return currentSpaceContext
    }
}

private struct MemoryEditorRoute: Identifiable {
    enum Mode {
        case create(space: SpaceModel?, template: MemoryEditorTemplate)
        case edit(memory: MemoryModel)
        case view(memory: MemoryModel)
    }

    let id = UUID()
    let mode: Mode
}

private struct SpaceComposerRequest: Identifiable {
    let id = UUID()
    let parent: SpaceModel?
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
