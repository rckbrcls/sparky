//
//  AppEnvironment.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AppEnvironment: ObservableObject {
    let persistence: PersistenceController
    let spaceService: SpaceService
    let memoryService: MemoryService
    let triggerExecutorCoordinator: TriggerExecutorCoordinator
    let settings: SettingsStore
    let attachmentStore: MemoryAttachmentStore

    // Mantidos para compatibilidade durante transição
    var notificationScheduler: ScheduledTriggerExecutor {
        triggerExecutorCoordinator.scheduled
    }
    var geofenceManager: LocationTriggerExecutor {
        triggerExecutorCoordinator.location
    }

    @Published var isBootstrapping = true
    @Published var hasBootstrapped = false
    @Published var hasCompletedOnboarding = false

    private var cancellables: Set<AnyCancellable> = []

    init(persistence: PersistenceController) {
        self.persistence = persistence
        self.settings = SettingsStore()
        self.attachmentStore = MemoryAttachmentStore()

        // Initialize services - they will load data synchronously in their init
        self.spaceService = SpaceService(persistence: persistence)
        self.memoryService = MemoryService(persistence: persistence,
                                           spaceService: spaceService,
                                           attachmentStore: attachmentStore)
        self.triggerExecutorCoordinator = TriggerExecutorCoordinator(settings: settings)

        self.hasCompletedOnboarding = settings.hasCompletedOnboarding

        memoryService.triggerExecutorCoordinator = triggerExecutorCoordinator

        settings.$hasCompletedOnboarding
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completed in
                self?.hasCompletedOnboarding = completed
            }
            .store(in: &cancellables)

        // Mark initialization as complete
        self.isBootstrapping = false
    }

    func bootstrap() {
        guard !hasBootstrapped else { return }

        Task {
            isBootstrapping = true

            // Perform a force refresh to ensure data is up-to-date
            async let spacesTask = spaceService.refresh(force: true)
            async let tagsTask = spaceService.refreshTags(force: true)
            async let memoriesTask = memoryService.refresh(force: true)

            _ = await (spacesTask, tagsTask, memoriesTask)

            await triggerExecutorCoordinator.scheduled.requestAuthorizationIfNeeded()

            hasBootstrapped = true
            isBootstrapping = false
        }
    }

    func completeOnboarding() {
#if DEBUG
        settings.hasCompletedOnboarding = false
        hasCompletedOnboarding = false
#else
        settings.hasCompletedOnboarding = true
#endif
    }
}
