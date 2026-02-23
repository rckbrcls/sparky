//
//  AppEnvironment.swift
//  sparky
//
//  Created by Codex on 13/10/25.
//

import Foundation
import SwiftUI
import Combine
import UserNotifications

struct PendingMemoryOpenRequest: Identifiable, Equatable {
    enum Source: String {
        case notification
    }

    let id = UUID()
    let memoryID: UUID
    let source: Source
}

@MainActor
final class AppEnvironment: ObservableObject {
    static let notificationDelegate = ForegroundNotificationDelegate()

    let dataController: DataController
    let mindService: MindService
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
    @Published var pendingMemoryOpenRequest: PendingMemoryOpenRequest?

    private var cancellables: Set<AnyCancellable> = []

    init(dataController: DataController) {
        self.dataController = dataController
        self.settings = SettingsStore()
        self.attachmentStore = MemoryAttachmentStore()

        // Initialize services - they will load data synchronously in their init
        self.mindService = MindService(dataController: dataController)
        self.memoryService = MemoryService(dataController: dataController,
                                           mindService: mindService,
                                           attachmentStore: attachmentStore)
        self.triggerExecutorCoordinator = TriggerExecutorCoordinator(settings: settings, memoryService: memoryService)

        self.hasCompletedOnboarding = settings.hasCompletedOnboarding

        memoryService.triggerExecutorCoordinator = triggerExecutorCoordinator

        // Allow notifications to appear even when the app is in the foreground.
        // The delegate is retained by this class; UNUserNotificationCenter holds an unowned ref.
        Self.notificationDelegate.onMemoryTapped = { [weak self] memoryID in
            self?.pendingMemoryOpenRequest = PendingMemoryOpenRequest(
                memoryID: memoryID,
                source: .notification
            )
        }
        UNUserNotificationCenter.current().delegate = Self.notificationDelegate

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
            async let mindsTask = mindService.refresh(force: true)
            async let tagsTask = mindService.refreshTags(force: true)
            async let memoriesTask = memoryService.refresh(force: true)

            _ = await (mindsTask, tagsTask, memoriesTask)

            if hasCompletedOnboarding {
                await triggerExecutorCoordinator.scheduled.requestAuthorizationIfNeeded()
            }

            hasBootstrapped = true
            isBootstrapping = false
        }
    }

    func completeOnboarding() {
        settings.hasCompletedOnboarding = true
    }
}

// MARK: - Foreground Notification Delegate

/// Enables notification banners, sounds, and badges while the app is in the foreground.
/// Without this delegate iOS silently suppresses notifications when the app is active.
@MainActor
final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    var onMemoryTapped: ((UUID) -> Void)? {
        didSet {
            flushBufferedTapsIfNeeded()
        }
    }
    private var bufferedMemoryIDs: [UUID] = []

    override init() {
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier else { return }
        let userInfo = response.notification.request.content.userInfo
        guard let idString = userInfo["memoryID"] as? String,
              let memoryID = UUID(uuidString: idString) else { return }
        handleMemoryTapOnMain(memoryID)
    }

    private func handleMemoryTapOnMain(_ memoryID: UUID) {
        if let onMemoryTapped {
            onMemoryTapped(memoryID)
            return
        }
        bufferedMemoryIDs.append(memoryID)
    }

    private func flushBufferedTapsIfNeeded() {
        guard let onMemoryTapped, !bufferedMemoryIDs.isEmpty else { return }
        let queued = bufferedMemoryIDs
        bufferedMemoryIDs.removeAll(keepingCapacity: true)
        for memoryID in queued {
            onMemoryTapped(memoryID)
        }
    }
}
