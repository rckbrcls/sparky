//
//  MeView.swift
//  sparky
//
//  Created by Codex on 07/12/25.
//

import SwiftUI
import SwiftData

struct MeView: View {
    @ObservedObject private var environment: AppEnvironment
    @Binding private var settingsNavigationPath: NavigationPath

    @StateObject private var viewModel: MeViewModel

    private enum Route: Hashable {
        case settings
    }

    init(
        environment: AppEnvironment,
        settingsNavigationPath: Binding<NavigationPath>
    ) {
        self.environment = environment
        _settingsNavigationPath = settingsNavigationPath
        _viewModel = StateObject(
            wrappedValue: MeViewModel(memoryService: environment.memoryService)
        )
    }

    var body: some View {
        NavigationStack(path: $settingsNavigationPath) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    MeSummaryCard(
                        streakDays: viewModel.metrics.streakDays,
                        completionCount: viewModel.metrics.totalCompletionCount
                    )
                    ContributionCalendarCard(
                        activityDays: viewModel.metrics.activityDays
                    )
                    WeeklyActivityCard(
                        activityDays: viewModel.metrics.weeklyActivityDays
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
                #if os(macOS)
                .frame(
                    maxWidth: DesktopLayoutMetrics.primaryContentMaxWidth,
                    alignment: .leading
                )
                #endif
                .frame(maxWidth: .infinity)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    #if os(macOS)
                    SettingsLink {
                        Label("Open settings", systemImage: "gearshape")
                            .labelStyle(.iconOnly)
                    }
                    .neutralToolbarItemStyle()
                    .help("Settings")
                    .accessibilityLabel("Open settings")
                    #else
                    Button {
                        settingsNavigationPath.append(Route.settings)
                    } label: {
                        Label("Open settings", systemImage: "gearshape")
                            .labelStyle(.iconOnly)
                    }
                    .neutralToolbarItemStyle()
                    .accessibilityLabel("Open settings")
                    #endif
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .settings:
                    SettingsView(
                        navigationPath: $settingsNavigationPath,
                        embedsInNavigationStack: false,
                        focusSettings: environment.focusSettings,
                        focusFeedback: environment.focusFeedbackService
                    )
                }
            }
            .background(Color.Theme.secondaryBackground.ignoresSafeArea())
        }
    }
}

#Preview("Populated") {
    let controller = DataController(inMemory: true)
    let now = Date()
    let calendar = Calendar.current

    for index in 0..<8 {
        let completedAt = calendar.date(
            byAdding: .hour,
            value: -(index * 17),
            to: now
        ) ?? now
        controller.modelContext.insert(
            Memory(
                title: "Completed memory \(index + 1)",
                statusRaw: MemoryStatus.completed.rawValue,
                createdAt: completedAt.addingTimeInterval(-3_600),
                updatedAt: completedAt,
                completedAt: completedAt
            )
        )
    }
    controller.save()

    let environment = AppEnvironment(dataController: controller)
    environment.bootstrap()
    return MeView(
        environment: environment,
        settingsNavigationPath: .constant(NavigationPath())
    )
    .environmentObject(environment)
}

#Preview("No Memories") {
    let environment = AppEnvironment(
        dataController: DataController(inMemory: true)
    )
    environment.bootstrap()
    return MeView(
        environment: environment,
        settingsNavigationPath: .constant(NavigationPath())
    )
    .environmentObject(environment)
}

#Preview("Active Only") {
    let controller = DataController(inMemory: true)
    controller.modelContext.insert(Memory(title: "Plan the next release"))
    controller.save()

    let environment = AppEnvironment(dataController: controller)
    environment.bootstrap()
    return MeView(
        environment: environment,
        settingsNavigationPath: .constant(NavigationPath())
    )
    .environmentObject(environment)
}
