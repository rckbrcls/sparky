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
        didSet { updateRemindersSnapshot() }
    }
    @Published private(set) var reminders: [ReminderModel] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let environment: AppEnvironment
    private var cancellables = Set<AnyCancellable>()

    init(environment: AppEnvironment) {
        self.environment = environment
        bind()
        updateRemindersSnapshot()
    }

    func refresh(force: Bool) {
        Task {
            isLoading = true
            defer { isLoading = false }
            await environment.reminderService.refresh(force: force)
            updateRemindersSnapshot()
        }
    }

    func complete(_ reminder: ReminderModel) {
        Task {
            do {
                _ = try await environment.reminderService.completeReminder(id: reminder.id)
                await environment.reminderService.refresh(force: true)
            } catch {
                errorMessage = "Failed to complete reminder."
            }
        }
    }

    func snooze(_ reminder: ReminderModel, minutes: Int) {
        Task {
            do {
                _ = try await environment.reminderService.snoozeReminder(id: reminder.id, by: TimeInterval(minutes * 60))
                await environment.reminderService.refresh(force: true)
            } catch {
                errorMessage = "Failed to snooze reminder."
            }
        }
    }

    func postpone(_ reminder: ReminderModel, hours: Int) {
        Task {
            do {
                _ = try await environment.reminderService.postponeReminder(id: reminder.id, by: TimeInterval(hours * 3600))
                await environment.reminderService.refresh(force: true)
            } catch {
                errorMessage = "Failed to postpone reminder."
            }
        }
    }

    func archive(_ reminder: ReminderModel) {
        Task {
            do {
                _ = try await environment.reminderService.archiveReminder(id: reminder.id)
                await environment.reminderService.refresh(force: true)
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
