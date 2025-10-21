//
//  TimelineViewModel.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import Combine

@MainActor
final class TimelineViewModel: ObservableObject {
    @Published var selectedFolderID: UUID? = nil {
        didSet {
            guard oldValue != selectedFolderID else { return }
            if filter != .all && count(for: filter) == 0 {
                suppressDefaultFilterWrite = true
                filter = .all
            } else {
                updateRemindersSnapshot()
            }
        }
    }
    @Published var filter: ReminderService.TimelineFilter = .today {
        didSet {
            if !suppressDefaultFilterWrite && settings.defaultTimelineFilter != filter {
                settings.defaultTimelineFilter = filter
            }
            suppressDefaultFilterWrite = false
            updateRemindersSnapshot()
        }
    }
    @Published var showCompleted: Bool = false {
        didSet {
            guard oldValue != showCompleted else { return }
            if filter != .all && count(for: filter) == 0 {
                suppressDefaultFilterWrite = true
                filter = .all
            } else {
                updateRemindersSnapshot()
            }
        }
    }
    @Published private(set) var reminders: [ReminderModel] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var folders: [FolderModel] = []

    var selectedFolder: FolderModel? {
        guard let selectedFolderID else { return nil }
        return folders.first(where: { $0.id == selectedFolderID })
    }

    var selectedFolderName: String {
        selectedFolder?.name ?? "All Reminders"
    }

    var availableFilters: [ReminderService.TimelineFilter] {
        ReminderService.TimelineFilter.allCases.filter { filter in
            filter == .all || count(for: filter) > 0
        }
    }

    private let environment: AppEnvironment
    private let settings: SettingsStore
    private var cancellables = Set<AnyCancellable>()
    private var suppressDefaultFilterWrite = false

    init(environment: AppEnvironment) {
        self.environment = environment
        self.settings = environment.settings
        self.filter = settings.defaultTimelineFilter
        self.folders = environment.folderService.folders

        // Don't initialize data here - let bind() handle it
        bind()

        // Force initial update after binding is set up
        updateRemindersSnapshot()
        observeSettings()
    }

    func refresh(force: Bool) {
        // Avoid duplicate refreshes if already loading
        guard !environment.isBootstrapping && !isLoading else { return }

        Task {
            isLoading = true
            defer { isLoading = false }
            await environment.reminderService.refresh(force: force)
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    func toggleShowCompleted() {
        showCompleted.toggle()
    }

    func count(for filter: ReminderService.TimelineFilter) -> Int {
        var filteredReminders = environment.reminderService.reminders(for: filter)

        if let folderID = selectedFolderID {
            filteredReminders = filteredReminders.filter { $0.folder?.id == folderID }
        }

        if !showCompleted {
            filteredReminders = filteredReminders.filter { $0.status != .completed }
        }

        return filteredReminders.count
    }

    func totalCount(for folderID: UUID?) -> Int {
        var filteredReminders = environment.reminderService.reminders

        if let folderID {
            filteredReminders = filteredReminders.filter { $0.folder?.id == folderID }
        }

        if !showCompleted {
            filteredReminders = filteredReminders.filter { $0.status != .completed }
        }

        return filteredReminders.count
    }

    func complete(_ reminder: ReminderModel) {
        Task {
            do {
                _ = try await environment.reminderService.completeReminder(id: reminder.id)
                // Force immediate refresh to update UI
                _ = await environment.reminderService.refresh(force: true)
            } catch {
                errorMessage = "Failed to complete reminder."
            }
        }
    }

    func snooze(_ reminder: ReminderModel, minutes: Int) {
        Task {
            do {
                _ = try await environment.reminderService.snoozeReminder(id: reminder.id, by: TimeInterval(minutes * 60))
                // Force immediate refresh to update UI
                _ = await environment.reminderService.refresh(force: true)
            } catch {
                errorMessage = "Failed to snooze reminder."
            }
        }
    }

    func postpone(_ reminder: ReminderModel, minutes: Int) {
        Task {
            do {
                _ = try await environment.reminderService.postponeReminder(id: reminder.id, by: TimeInterval(minutes * 60))
                // Force immediate refresh to update UI
                _ = await environment.reminderService.refresh(force: true)
            } catch {
                errorMessage = "Failed to postpone reminder."
            }
        }
    }

    func archive(_ reminder: ReminderModel) {
        Task {
            do {
                _ = try await environment.reminderService.archiveReminder(id: reminder.id)
                // Force immediate refresh to update UI
                _ = await environment.reminderService.refresh(force: true)
            } catch {
                errorMessage = "Failed to archive reminder."
            }
        }
    }

    func delete(_ reminder: ReminderModel) {
        Task {
            do {
                try await environment.reminderService.deleteReminder(id: reminder.id)
                // Force immediate refresh to update UI
                _ = await environment.reminderService.refresh(force: true)
            } catch {
                errorMessage = "Failed to delete reminder."
            }
        }
    }

    private func bind() {
        environment.reminderService.$reminders
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateRemindersSnapshot()
            }
            .store(in: &cancellables)

        environment.folderService.$folders
            .receive(on: RunLoop.main)
            .sink { [weak self] folders in
                self?.handleFolderUpdate(folders)
            }
            .store(in: &cancellables)
    }

    private func observeSettings() {
        settings.$defaultTimelineFilter
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                guard let self else { return }
                if self.filter != newValue {
                    self.filter = newValue
                }
            }
            .store(in: &cancellables)
    }

    private func updateRemindersSnapshot() {
        var filteredReminders = environment.reminderService.reminders(for: filter)

        if let folderID = selectedFolderID {
            filteredReminders = filteredReminders.filter { $0.folder?.id == folderID }
        }

        if !showCompleted {
            filteredReminders = filteredReminders.filter { $0.status != .completed }
        }

        if filter != .all && filteredReminders.isEmpty {
            suppressDefaultFilterWrite = true
            filter = .all
            return
        }

        reminders = filteredReminders
    }

    private func handleFolderUpdate(_ newFolders: [FolderModel]) {
        folders = newFolders

        if let selectedFolderID,
           !newFolders.contains(where: { $0.id == selectedFolderID }) {
            self.selectedFolderID = nil
            return
        }

        updateRemindersSnapshot()
    }
}
