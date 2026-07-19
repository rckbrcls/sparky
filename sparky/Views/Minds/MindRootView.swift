//
//  MindRootView.swift
//  sparky
//

import SwiftUI

struct MindRootView: View {
    @ObservedObject var mindService: MindService
    @ObservedObject var memoryService: MemoryService
    @Binding var navigationPath: NavigationPath

    let onSelectMemory: (Memory) -> Void
    let onEditMemory: ((Memory) -> Void)?
    let onCreateMind: () -> Void
    let onEditMind: ((Mind) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    let onMindContextChange: ((Mind?) -> Void)?
    let onSearchActiveChange: (Bool) -> Void

    var body: some View {
        NavigationStack(path: $navigationPath) {
            MindsTab(
                mindService: mindService,
                memoryService: memoryService,
                onEditMind: onEditMind
            )
            .background(Color.Theme.secondaryBackground.ignoresSafeArea())
            .toolbarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 70)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onCreateMind()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("Add Mind")
                }
            }
            .navigationDestination(for: Mind.self) { mind in
                MindDetailView(
                    mind: mind,
                    navigationPath: $navigationPath,
                    mindService: mindService,
                    memoryService: memoryService,
                    onSelectMemory: onSelectMemory,
                    onEditMemory: onEditMemory,
                    onEditMind: onEditMind,
                    onMultiSelectionChange: onMultiSelectionChange,
                    onMindContextChange: onMindContextChange,
                    onSearchActiveChange: onSearchActiveChange
                )
            }
        }
        .onAppear {
            onMultiSelectionChange(false)
            onMindContextChange?(nil)
        }
        .onChange(of: navigationPath) { oldPath, newPath in
            if newPath.isEmpty {
                onMindContextChange?(nil)
            }
        }
    }

    private func refresh() async {
        _ = await mindService.refresh(force: true)
    }
}

#Preview {
    let environment = AppEnvironment(dataController: DataController.preview)
    environment.bootstrap()
    return MindRootView(
        mindService: environment.mindService,
        memoryService: environment.memoryService,
        navigationPath: .constant(NavigationPath()),
        onSelectMemory: { _ in },
        onEditMemory: nil,
        onCreateMind: { },
        onEditMind: nil,
        onMultiSelectionChange: { _ in },
        onMindContextChange: nil,
        onSearchActiveChange: { _ in }
    )
}
