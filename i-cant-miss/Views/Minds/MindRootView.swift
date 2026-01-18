//
//  MindRootView.swift
//  i-cant-miss
//

import SwiftUI

struct MindRootView: View {
    @ObservedObject var mindService: MindService
    @ObservedObject var spaceService: SpaceService
    @ObservedObject var memoryService: MemoryService
    @Binding var navigationPath: NavigationPath

    let onSelectMemory: (MemoryModel) -> Void
    let onCreateMind: () -> Void
    let onEditMind: ((MindModel) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    let onSpaceContextChange: (SpaceModel?) -> Void
    let onMindContextChange: ((MindModel?) -> Void)?
    let onSearchActiveChange: (Bool) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Minds")
                        .appLargeTitleStyle()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(displayMinds) { mind in
                            NavigationLink(value: mind) {
                                MindGridItemView(
                                    mind: mind,
                                    count: spaceCounts(for: mind),
                                    mindService: mindService,
                                    spaceService: spaceService,
                                    onEdit: onEditMind
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityHint("Opens details for \(mind.name)")
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 70)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onCreateMind()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create Mind")
                }
            }
            .navigationDestination(for: MindModel.self) { mind in
                MindDetailView(
                    mind: mind,
                    mindService: mindService,
                    spaceService: spaceService,
                    memoryService: memoryService,
                    onSelectMemory: onSelectMemory,
                    onEditMind: onEditMind,
                    onMultiSelectionChange: onMultiSelectionChange,
                    onSpaceContextChange: onSpaceContextChange,
                    onMindContextChange: onMindContextChange,
                    onSearchActiveChange: onSearchActiveChange
                )
            }
        }
        .onAppear {
            onMultiSelectionChange(false)
            onSpaceContextChange(nil)
            onMindContextChange?(nil)
        }
        .onChange(of: navigationPath) { oldPath, newPath in
            if newPath.isEmpty {
                onSpaceContextChange(nil)
                onMindContextChange?(nil)
            }
        }
    }

    private var displayMinds: [MindModel] {
        let sortedMinds = mindService.minds
            .filter { !$0.isDefault } // Filter out the default "All Minds" since we have the virtual "All"
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        return [MindModel.allMinds] + sortedMinds
    }

    private func spaceCounts(for mind: MindModel) -> Int {
        if mind.isAllMinds {
            return spaceService.spaces.count
        } else {
            return spaceService.spaces.filter { space in
                guard let mindID = space.mind?.id else { return false }
                return mindID == mind.id
            }.count
        }
    }

    private func refresh() async {
        async let minds = mindService.refresh(force: true)
        async let spaces = spaceService.refresh(force: true)
        _ = await (minds, spaces)
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MindRootView(
        mindService: environment.mindService,
        spaceService: environment.spaceService,
        memoryService: environment.memoryService,
        navigationPath: .constant(NavigationPath()),
        onSelectMemory: { _ in },
        onCreateMind: { },
        onEditMind: nil,
        onMultiSelectionChange: { _ in },
        onSpaceContextChange: { _ in },
        onMindContextChange: nil,
        onSearchActiveChange: { _ in }
    )
}
