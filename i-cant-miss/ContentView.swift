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

    init(environment: AppEnvironment) {
        _environment = ObservedObject(wrappedValue: environment)
    }

    var body: some View {
        TabView(selection: $tabRouter.selection) {
            MemoryTimelineView(
                memoryService: environment.memoryService,
                onCreateMemory: { prepareMemoryCreation(for: nil) },
                onSelectMemory: handleMemorySelection
            )
            .tabItem {
                Label("Timeline", systemImage: "list.bullet.rectangle")
            }
            .tag(TabRouter.Selection.timeline)

            SpacesRootView(
                spaceService: environment.spaceService,
                memoryService: environment.memoryService,
                onCreateMemory: { space in
                    prepareMemoryCreation(for: space)
                },
                onSelectMemory: handleMemorySelection,
                onCreateSpace: presentSpaceCreation
            )
            .tabItem {
                Label("Spaces", systemImage: "square.grid.2x2")
            }
            .tag(TabRouter.Selection.spaces)

            SettingsView(environment: environment)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(TabRouter.Selection.settings)
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
}

final class TabRouter: ObservableObject {
    enum Selection {
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
