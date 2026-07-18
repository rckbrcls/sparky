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

struct PendingFocusOpenRequest: Identifiable, Equatable {
    let id = UUID()
    let memoryID: UUID
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
    let focusSettings: FocusSettings
    let focusTimer: FocusTimer

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
    @Published var pendingFocusOpenRequest: PendingFocusOpenRequest?

    private var cancellables: Set<AnyCancellable> = []

    init(
        dataController: DataController,
        focusSettings: FocusSettings? = nil
    ) {
        self.dataController = dataController
        self.settings = SettingsStore()
        self.attachmentStore = MemoryAttachmentStore()
        self.focusSettings = focusSettings ?? FocusSettings()
        let focusNotifications = FocusNotificationService(settings: settings)
        self.focusTimer = FocusTimer(settings: self.focusSettings, notifications: focusNotifications)

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
        Self.notificationDelegate.onStartFocus = { [weak self] memoryID in
            self?.pendingFocusOpenRequest = PendingFocusOpenRequest(memoryID: memoryID)
        }
        UNUserNotificationCenter.current().delegate = Self.notificationDelegate
        NotificationCategoryRegistrar.registerAll()

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

    func startFocus(for memoryID: UUID) {
        guard let memory = memoryService.memory(id: memoryID),
              memory.hasFocus,
              let recipe = memory.focusRecipe(settings: focusSettings) else {
            return
        }

        // Deep-link / editor intent is explicit: replace any other active target.
        if focusTimer.wouldReplaceSession(withMemoryID: memory.id) {
            focusTimer.endSession()
        }

        focusTimer.beginSession(memoryID: memory.id, memoryTitle: memory.title, recipe: recipe)
        pendingFocusOpenRequest = PendingFocusOpenRequest(memoryID: memory.id)
    }

    func startQuickFocus(workDurationMinutes: Int? = nil) {
        if focusTimer.wouldReplaceSession(withMemoryID: nil) {
            focusTimer.endSession()
        }
        focusTimer.beginQuickSession(workDurationMinutes: workDurationMinutes)
    }

    func startQuickFocus(recipe: FocusRecipe) {
        if focusTimer.wouldReplaceSession(withMemoryID: nil) {
            focusTimer.endSession()
        }
        focusTimer.beginQuickSession(recipe: recipe)
    }

    func canStartNewFocusTarget(memoryID: UUID?) -> Bool {
        !focusTimer.wouldReplaceSession(withMemoryID: memoryID)
    }

    func focusRecipe(for memory: Memory) -> FocusRecipe? {
        memory.focusRecipe(settings: focusSettings)
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
    var onStartFocus: ((UUID) -> Void)? {
        didSet {
            flushBufferedFocusIfNeeded()
        }
    }

    private var bufferedMemoryIDs: [UUID] = []
    private var bufferedFocusMemoryIDs: [UUID] = []

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
        let idString = (userInfo[NotificationUserInfoKey.memoryID] as? String)
            ?? (userInfo["memoryID"] as? String)
        guard let idString,
              let memoryID = UUID(uuidString: idString) else { return }

        if response.actionIdentifier == NotificationActionID.startFocus {
            handleFocusOnMain(memoryID)
            return
        }

        handleMemoryTapOnMain(memoryID)
    }

    private func handleMemoryTapOnMain(_ memoryID: UUID) {
        if let onMemoryTapped {
            onMemoryTapped(memoryID)
            return
        }
        bufferedMemoryIDs.append(memoryID)
    }

    private func handleFocusOnMain(_ memoryID: UUID) {
        if let onStartFocus {
            onStartFocus(memoryID)
            return
        }
        bufferedFocusMemoryIDs.append(memoryID)
    }

    private func flushBufferedTapsIfNeeded() {
        guard let onMemoryTapped, !bufferedMemoryIDs.isEmpty else { return }
        let queued = bufferedMemoryIDs
        bufferedMemoryIDs.removeAll(keepingCapacity: true)
        for memoryID in queued {
            onMemoryTapped(memoryID)
        }
    }

    private func flushBufferedFocusIfNeeded() {
        guard let onStartFocus, !bufferedFocusMemoryIDs.isEmpty else { return }
        let queued = bufferedFocusMemoryIDs
        bufferedFocusMemoryIDs.removeAll(keepingCapacity: true)
        for memoryID in queued {
            onStartFocus(memoryID)
        }
    }
}
