//
//  MemoriesContainerView.swift
//  i-cant-miss
//
//  Created by Codex on 27/11/25.
//

import SwiftUI

struct MemoriesContainerView: View {
    enum ViewMode: String, CaseIterable, Identifiable {
        case list
        case calendar
        case map

        var id: String { rawValue }

        var title: String {
            switch self {
            case .list:
                return "List"
            case .calendar:
                return "Calendar"
            case .map:
                return "Map"
            }
        }

        var icon: String {
            switch self {
            case .list:
                return "list.bullet"
            case .calendar:
                return "calendar"
            case .map:
                return "map"
            }
        }
    }

    @ObservedObject var memoryService: MemoryService
    let onSelectMemory: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    @Binding var listNavigationPath: NavigationPath
    @Binding var calendarNavigationPath: NavigationPath

    @State private var viewMode: ViewMode = .list
    @State private var mapNavigationPath = NavigationPath()

    private var activeNavigationPath: Binding<NavigationPath> {
        switch viewMode {
        case .list:
            return $listNavigationPath
        case .calendar:
            return $calendarNavigationPath
        case .map:
            return $mapNavigationPath
        }
    }

    var body: some View {
        NavigationStack(path: activeNavigationPath) {
            ZStack {
                if viewMode == .list {
                    listView
                        .transition(.opacity)
                }

                if viewMode == .calendar {
                    calendarView
                        .transition(.opacity)
                }

                if viewMode == .map {
                    mapView
                        .transition(.opacity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    segmentedPicker
                }
            }
        }
    }

    private var segmentedPicker: some View {
        Picker("", selection: Binding(
            get: { viewMode },
            set: { newValue in
                withAnimation(.linear(duration: 0.08)) {
                    viewMode = newValue
                }
            }
        )) {
            ForEach(ViewMode.allCases) { mode in
                Label(mode.title, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 160)
    }

    private var listView: some View {
        MemoryTriggersView(
            memoryService: memoryService,
            onSelectMemory: onSelectMemory,
            onEditMemory: onEditMemory,
            onMultiSelectionChange: onMultiSelectionChange,
            navigationPath: $listNavigationPath,
            embedsInNavigationStack: false
        )
    }

    private var calendarView: some View {
        MemoryTimelineView(
            memoryService: memoryService,
            onSelectMemory: onSelectMemory,
            onEditMemory: onEditMemory,
            onMultiSelectionChange: onMultiSelectionChange,
            navigationPath: $calendarNavigationPath,
            embedsInNavigationStack: false
        )
    }

    private var mapView: some View {
        MemoriesMapView(
            memories: memoryService.memoriesWithLocationOnly(),
            onSelectMemory: onSelectMemory
        )
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MemoriesContainerView(
        memoryService: environment.memoryService,
        onSelectMemory: { _ in },
        onEditMemory: nil,
        onMultiSelectionChange: { _ in },
        listNavigationPath: .constant(NavigationPath()),
        calendarNavigationPath: .constant(NavigationPath())
    )
    .environmentObject(environment)
}
