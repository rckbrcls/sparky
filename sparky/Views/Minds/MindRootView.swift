//
//  MindRootView.swift
//  sparky
//

import SwiftUI

struct MindRootView: View {
    @ObservedObject var mindService: MindService
    @ObservedObject var lobeService: LobeService
    @ObservedObject var memoryService: MemoryService
    @Binding var navigationPath: NavigationPath

    let onSelectMemory: (Memory) -> Void
    let onEditMemory: ((Memory) -> Void)?
    let onCreateMind: () -> Void
    let onEditMind: ((Mind) -> Void)?
    let onEditLobe: ((Space) -> Void)?
    let onAddLobe: ((Mind) -> Void)?
    let onAddLobeWithoutMind: (() -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    let onLobeContextChange: (Space?) -> Void
    let onMindContextChange: ((Mind?) -> Void)?
    let onSearchActiveChange: (Bool) -> Void

    enum Tab {
        case minds
        case memories
    }

    @State private var selectedTab: Tab = .minds

    var body: some View {
        NavigationStack(path: $navigationPath) {
            TabView(selection: $selectedTab) {
                MindsTab(
                    mindService: mindService,
                    lobeService: lobeService,
                    memoryService: memoryService,
                    onEditMind: onEditMind
                )
                .tag(Tab.minds)

                LobesTab(
                    lobeService: lobeService,
                    mindService: mindService,
                    memoryService: memoryService,
                    onEditLobe: onEditLobe
                )
                .tag(Tab.memories)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .toolbarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 70)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $selectedTab) {
                        Label("Minds", systemImage: "brain.head.profile").tag(Tab.minds)
                        Label("Lobes", systemImage: "brain").tag(Tab.memories)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            onCreateMind()
                        } label: {
                            Label("Add Mind", systemImage: "brain.head.profile")
                        }

                        Button {
                            onAddLobeWithoutMind?()
                        } label: {
                            Label("Add Lobe", systemImage: "brain.fill")
                        }
                        .disabled(onAddLobeWithoutMind == nil)
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("Add")
                }
            }
            .navigationDestination(for: Mind.self) { mind in
                MindDetailView(
                    mind: mind,
                    mindService: mindService,
                    lobeService: lobeService,
                    memoryService: memoryService,
                    onSelectMemory: onSelectMemory,
                    onEditMemory: onEditMemory,
                    onEditMind: onEditMind,
                    onAddLobe: onAddLobe,
                    onMultiSelectionChange: onMultiSelectionChange,
                    onLobeContextChange: onLobeContextChange,
                    onMindContextChange: onMindContextChange,
                    onSearchActiveChange: onSearchActiveChange
                )
            }
            .navigationDestination(for: Space.self) { lobe in
                LobeDetailView(
                    lobe: lobe,
                    lobeService: lobeService,
                    memoryService: memoryService,
                    onSelectMemory: onSelectMemory,
                    onEditMemory: onEditMemory,
                    onEditLobe: onEditLobe,
                    onMultiSelectionChange: onMultiSelectionChange,
                    onLobeContextChange: { newLobe in
                        onLobeContextChange(newLobe)
                    },
                    onSearchActiveChange: onSearchActiveChange
                )
                .onAppear {
                    onLobeContextChange(lobe)
                }
            }
        }
        .onAppear {
            onMultiSelectionChange(false)
            onLobeContextChange(nil)
            onMindContextChange?(nil)
        }
        .onChange(of: navigationPath) { oldPath, newPath in
            if newPath.isEmpty {
                onLobeContextChange(nil)
                onMindContextChange?(nil)
            }
        }
    }

    private func refresh() async {
        async let minds = mindService.refresh(force: true)
        async let lobes = lobeService.refresh(force: true)
        _ = await (minds, lobes)
    }
}

#Preview {
    let environment = AppEnvironment(dataController: DataController.preview)
    environment.bootstrap()
    return MindRootView(
        mindService: environment.mindService,
        lobeService: environment.lobeService,
        memoryService: environment.memoryService,
        navigationPath: .constant(NavigationPath()),
        onSelectMemory: { _ in },
        onEditMemory: nil,
        onCreateMind: { },
        onEditMind: nil,
        onEditLobe: nil,
        onAddLobe: nil,
        onAddLobeWithoutMind: nil,
        onMultiSelectionChange: { _ in },
        onLobeContextChange: { _ in },
        onMindContextChange: nil,
        onSearchActiveChange: { _ in }
    )
}
