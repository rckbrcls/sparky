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
                    header

                    WeeklySparkCard(metrics: viewModel.metrics)
                    insightSections
                }
                .frame(maxWidth: 880, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
                .frame(maxWidth: .infinity)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    #if os(macOS)
                    SettingsLink {
                        Label("Open settings", systemImage: "gearshape")
                            .labelStyle(.iconOnly)
                    }
                    .help("Settings")
                    .accessibilityLabel("Open settings")
                    #else
                    Button {
                        settingsNavigationPath.append(Route.settings)
                    } label: {
                        Label("Open settings", systemImage: "gearshape")
                            .labelStyle(.iconOnly)
                    }
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
                        focusSettings: environment.focusSettings
                    )
                }
            }
            .background(Color.Theme.secondaryBackground.ignoresSafeArea())
        }
    }
}

private extension MeView {
    var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Your week")
                .appLargeTitleStyle()

            Text("Here’s your recent rhythm")
                .font(.body)
                .foregroundStyle(Color.Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    var insightSections: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                WeeklyActivityCard(
                    activityDays: viewModel.metrics.weeklyActivityDays
                )
                .frame(minWidth: 360)

                WeeklyRhythmCard(
                    rhythm: viewModel.metrics.rhythm,
                    completionRate: viewModel.metrics.completionRate,
                    insight: viewModel.metrics.insight
                )
                .frame(minWidth: 300)
            }

            VStack(spacing: 16) {
                WeeklyActivityCard(
                    activityDays: viewModel.metrics.weeklyActivityDays
                )

                WeeklyRhythmCard(
                    rhythm: viewModel.metrics.rhythm,
                    completionRate: viewModel.metrics.completionRate,
                    insight: viewModel.metrics.insight
                )
            }
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

#Preview("Waiting for Completion") {
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
