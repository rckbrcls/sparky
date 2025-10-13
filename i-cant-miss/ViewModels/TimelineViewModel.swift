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
    @Published var filter: ReminderService.TimelineFilter = .today {
        didSet {
            updateRemindersSnapshot()
        }
    }
    @Published private(set) var reminders: [ReminderModel] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let environment: AppEnvironment
    private var cancellables = Set<AnyCancellable>()

    init(environment: AppEnvironment) {
        self.environment = environment

        // Don't initialize data here - let bind() handle it
        bind()

        // Force initial update after binding is set up
        updateRemindersSnapshot()
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

    func postpone(_ reminder: ReminderModel, hours: Int) {
        Task {
            do {
                _ = try await environment.reminderService.postponeReminder(id: reminder.id, by: TimeInterval(hours * 3600))
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

    private func bind() {
        environment.reminderService.$reminders
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateRemindersSnapshot()
            }
            .store(in: &cancellables)
    }

    private func updateRemindersSnapshot() {
        reminders = environment.reminderService.reminders(for: filter)
    }
}
