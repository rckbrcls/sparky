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
            return "apple.terminal.fill"
        case .spaces:
            return "trash"
        case .settings:
            return "tray.full.fill"
        }
    }

    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}


struct ContentView: View {
    @ObservedObject private var environment: AppEnvironment
    @State private var editorRoute: MemoryEditorRoute?
    @State private var viewerRoute: MemoryViewerRoute?
    @State private var showSpaceComposer = false
    @State private var showTerminalSheet = false
    @State private var terminalInput: String = ""
    @State private var terminalSheetDetent: PresentationDetent = .fraction(0.4)
    @State private var activeTab: CustomTab = .home
    @Namespace private var transition

    init(environment: AppEnvironment) {
        _environment = ObservedObject(wrappedValue: environment)
    }

    var body: some View {
        VStack{
            TabView(selection: $activeTab){
                Tab.init(value: .home){
                    MemoryTimelineView(
                        memoryService: environment.memoryService,
                        onCreateMemory: { prepareMemoryCreation(for: nil) },
                        onSelectMemory: handleMemorySelection,
                        transition: transition
                    )
                    .toolbarVisibility(.hidden, for: .tabBar)
                }

                Tab.init(value: .spaces){
                    SpacesRootView(
                        spaceService: environment.spaceService,
                        memoryService: environment.memoryService,
                        onCreateMemory: { space in
                            prepareMemoryCreation(for: space)
                        },
                        onSelectMemory: handleMemorySelection,
                        onCreateSpace: presentSpaceCreation,
                        transition: transition
                    )
                    .toolbarVisibility(.hidden, for: .tabBar)
                }

                Tab.init(value: .settings){
                    SettingsView(environment: environment)
                        .toolbarVisibility(.hidden, for: .tabBar)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0){
                CustomTabBarView()
                    .padding(.horizontal, 20)
            }
        }
        .sheet(item: $viewerRoute) { route in
            MemoryDetailView(
                memory: route.memory,
                onClose: { viewerRoute = nil },
                onEdit: handleMemoryEditRequest
            )
            .navigationTransition(.zoom(sourceID: route.transitionSourceID, in: transition))
        }
        .sheet(item: $editorRoute) { route in
            switch route.mode {
            case let .create(space, template):
                MemoryEditorView(
                    environment: environment,
                    defaultSpace: space,
                    template: template
                )
            case let .edit(memory):
                MemoryEditorView(
                    environment: environment,
                    memory: memory,
                    defaultSpace: memory.space,
                    template: .blank
                )
            }
        }
        .sheet(isPresented: $showSpaceComposer) {
            SpaceComposerView(environment: environment)
        }
        .sheet(isPresented: $showTerminalSheet) {
            TerminalSheetView(
                text: $terminalInput,
                onClose: dismissTerminalSheet
            )
            .presentationDetents([.fraction(0.35), .medium, .large], selection: $terminalSheetDetent)
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    func CustomTabBarView () -> some View {
        GlassEffectContainer(spacing: 10){
            HStack(spacing: 10){
                GeometryReader{
                    CustomTabBar(size: $0.size, activeTab: $activeTab){ tab in
                        VStack(spacing: 3){
                            Image(systemName: tab.symbol)
                                .font(.title3)

                            Text(tab.rawValue)
                                .font(.system(size: 10))
                                .fontWeight(.medium)
                        }
                        .symbolVariant(.fill)
                        .frame(maxWidth: .infinity)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }

                Button(action: { presentTerminalSheet() }) {
                    ZStack{
                        ForEach(CustomTab.allCases, id: \.rawValue){ tab in
                            Image(systemName: tab.actionSymbol)
                                .font(.system(size: 22, weight: .medium))
                                .blurFade(activeTab == tab)
                        }
                    }
                    .frame(width: 55, height: 55)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                .animation(.smooth(duration: 0.55 , extraBounce: 0), value: activeTab)
                .accessibilityLabel("Abrir terminal")
            }
        }
        .frame(height: 55)
    }

    private func prepareMemoryCreation(for space: SpaceModel?) {
        editorRoute = MemoryEditorRoute(mode: .create(space: space, template: .blank))
    }

    private func handleMemorySelection(_ memory: MemoryModel, transitionID: AnyHashable) {
        viewerRoute = MemoryViewerRoute(memory: memory, transitionSourceID: transitionID)
    }

    private func presentSpaceCreation() {
        showSpaceComposer = true
    }

    private func presentTerminalSheet() {
        showTerminalSheet = true
    }

    private func dismissTerminalSheet() {
        showTerminalSheet = false
    }

    private func handleMemoryEditRequest(_ memory: MemoryModel) {
        viewerRoute = nil
        DispatchQueue.main.async {
            editorRoute = MemoryEditorRoute(mode: .edit(memory: memory))
        }
    }
}

private struct MemoryEditorRoute: Identifiable {
    enum Mode {
        case create(space: SpaceModel?, template: MemoryEditorTemplate)
        case edit(memory: MemoryModel)
    }

    let id = UUID()
    let mode: Mode
}

private struct MemoryViewerRoute: Identifiable {
    let id = UUID()
    let memory: MemoryModel
    let transitionSourceID: AnyHashable
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
}
