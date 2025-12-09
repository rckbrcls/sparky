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

    case map = "Map"
    case spaces = "Memories"
    case me = "Me"

    var symbol: String {
        switch self {
        case .calendar:
            return "calendar"

        case .map:
            return "map"
        case .spaces:
            return "bolt.circle"
        case .me:
            return "person.crop.circle"
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
    @State private var currentSpaceContext: SpaceModel?

    init(environment: AppEnvironment) {
        _environment = ObservedObject(wrappedValue: environment)
    }

    var body: some View {
        TabView(selection: $activeTab) {
            MemoryTimelineView(
                memoryService: environment.memoryService,
                onSelectMemory: handleMemorySelection,
                onEditMemory: handleMemoryEdit,
                onMultiSelectionChange: handleMultiSelectionChange,
                navigationPath: $calendarNavigationPath,
                embedsInNavigationStack: true
            )
            .tabItem {
                Label(CustomTab.calendar.rawValue, systemImage: CustomTab.calendar.symbol)
            }
            .tag(CustomTab.calendar)



            MemoriesMapView(
                memories: environment.memoryService.memoriesWithLocationOnly(),
                onSelectMemory: handleMemorySelection
            )
            .tabItem {
                Label(CustomTab.map.rawValue, systemImage: CustomTab.map.symbol)
            }
            .tag(CustomTab.map)

            SpacesRootView(
                spaceService: environment.spaceService,
                memoryService: environment.memoryService,
                navigationPath: $spacesNavigationPath,
                onSelectMemory: handleMemorySelection,
                onEditMemory: handleMemoryEdit,
                onCreateSpace: { parent in
                    presentSpaceCreation(for: parent)
                },
                onEditSpace: { space in
                    presentSpaceEdit(for: space)
                },
                onMultiSelectionChange: handleMultiSelectionChange,
                onSpaceContextChange: { space in
                    // Update context immediately when space changes
                    currentSpaceContext = space
                }
            )
            .tabItem {
                Label(CustomTab.spaces.rawValue, systemImage: CustomTab.spaces.symbol)
            }
            .tag(CustomTab.spaces)

            MeView(environment: environment, settingsNavigationPath: $meNavigationPath)
                .tabItem {
                    Label(CustomTab.me.rawValue, systemImage: CustomTab.me.symbol)
                }
                .tag(CustomTab.me)
        }
        .toolbar(tabBarVisibility, for: .tabBar)
        .overlay(alignment: .bottomTrailing) {
            if shouldShowAddButton {
                addMemoryButton
                    .padding(.trailing, 16)
                    .padding(.bottom, bottomSafeInset + 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isMultiSelectionActive)
        .ignoresSafeArea(.keyboard, edges: .bottom)
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
            SpaceComposerView(
                environment: environment,
                defaultParent: request.parent,
                spaceToEdit: request.spaceToEdit
            )
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingFlowView {
                environment.completeOnboarding()
                showingOnboarding = false
            }
        }
        .onAppear {
            showingOnboarding = !environment.hasCompletedOnboarding
        }
        .onChange(of: environment.hasCompletedOnboarding) { _, completed in
            withAnimation(.easeInOut) {
                showingOnboarding = !completed
            }
        }
        .onChange(of: activeTab) { _, newTab in
            // Clear context when switching away from spaces tab
            if newTab != .spaces {
                currentSpaceContext = nil
            }
        }
    }

    private func prepareMemoryCreation(for space: SpaceModel?) {
        editorRoute = MemoryEditorRoute(mode: .create(space: space, template: .blank))
    }

    private func handleMemorySelection(_ memory: MemoryModel) {
        editorRoute = MemoryEditorRoute(mode: .view(memory: memory))
    }

    private func handleMemoryEdit(_ memory: MemoryModel) {
        editorRoute = MemoryEditorRoute(mode: .edit(memory: memory))
    }

    private func presentSpaceCreation(for parent: SpaceModel?) {
        spaceComposerRequest = SpaceComposerRequest(parent: parent, spaceToEdit: nil)
    }

    private func presentSpaceEdit(for space: SpaceModel) {
        spaceComposerRequest = SpaceComposerRequest(parent: nil, spaceToEdit: space)
    }

    private var tabBarVisibility: Visibility {
        isMultiSelectionActive ? .hidden : .visible
    }

    private var shouldShowAddButton: Bool {
        !isMultiSelectionActive
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

    private func targetSpaceForCreation() -> SpaceModel? {
        guard activeTab == .spaces else { return nil }
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
        case view(memory: MemoryModel)
    }

    let id = UUID()
    let mode: Mode
}

private struct SpaceComposerRequest: Identifiable {
    let id = UUID()
    let parent: SpaceModel?
    let spaceToEdit: SpaceModel?
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
