//
//  ContentView.swift
//  i-cant-miss
//
//  Created by Erick Barcelos on 13/10/25.
//

import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject private var environment: AppEnvironment
    @StateObject private var tabRouter = TabRouter()
    @State private var editorRoute: MemoryEditorRoute?
    @State private var showSpaceComposer = false
    @State private var showTerminalSheet = false
    @State private var terminalInput: String = ""
    @State private var terminalSheetDetent: PresentationDetent = .fraction(0.4)

    init(environment: AppEnvironment) {
        _environment = ObservedObject(wrappedValue: environment)
    }

    var body: some View {
        currentTab
            .safeAreaInset(edge: .bottom) {
                CustomTabBar(
                    items: tabItems,
                    selection: $tabRouter.selection,
                    isTerminalActive: showTerminalSheet,
                    onTerminalTap: presentTerminalSheet
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
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

    private func prepareMemoryCreation(for space: SpaceModel?) {
        editorRoute = MemoryEditorRoute(mode: .create(space: space, template: .blank))
    }

    private func handleMemorySelection(_ memory: MemoryModel) {
        editorRoute = MemoryEditorRoute(mode: .edit(memory: memory))
    }

    private func presentSpaceCreation() {
        showSpaceComposer = true
    }

    private var currentTab: some View {
        Group {
            switch tabRouter.selection {
            case .timeline:
                MemoryTimelineView(
                    memoryService: environment.memoryService,
                    onCreateMemory: { prepareMemoryCreation(for: nil) },
                    onSelectMemory: handleMemorySelection
                )
            case .spaces:
                SpacesRootView(
                    spaceService: environment.spaceService,
                    memoryService: environment.memoryService,
                    onCreateMemory: { space in
                        prepareMemoryCreation(for: space)
                    },
                    onSelectMemory: handleMemorySelection,
                    onCreateSpace: presentSpaceCreation
                )
            case .settings:
                SettingsView(environment: environment)
            }
        }
    }

    private var tabItems: [CustomTabBar.Item] {
        [
            .init(title: "Timeline", icon: "list.bullet.rectangle", selection: .timeline),
            .init(title: "Spaces", icon: "square.grid.2x2", selection: .spaces),
            .init(title: "Settings", icon: "gearshape", selection: .settings)
        ]
    }

    private func presentTerminalSheet() {
        showTerminalSheet = true
    }

    private func dismissTerminalSheet() {
        showTerminalSheet = false
    }
}

final class TabRouter: ObservableObject {
    enum Selection: CaseIterable {
        case timeline
        case spaces
        case settings
    }

    @Published var selection: Selection = .timeline
}

private struct MemoryEditorRoute: Identifiable {
    enum Mode {
        case create(space: SpaceModel?, template: MemoryEditorTemplate)
        case edit(memory: MemoryModel)
    }

    let id = UUID()
    let mode: Mode
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return ContentView(environment: environment)
}
