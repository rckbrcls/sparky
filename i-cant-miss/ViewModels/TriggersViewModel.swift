//
//  TriggersViewModel.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import Combine

@MainActor
final class TriggersViewModel: ObservableObject {
    struct TriggerDisplay: Identifiable {
        let id: UUID
        let reminder: ReminderModel
        let trigger: ReminderTriggerModel
    }

    struct TriggerGroup: Identifiable {
        let id: ReminderTriggerType
        let items: [TriggerDisplay]
    }

    struct TriggerTypeFolder: Identifiable {
        let id: ReminderTriggerType
        var type: ReminderTriggerType { id }
        let items: [TriggerDisplay]
        var count: Int { items.count }
    }

    @Published private(set) var triggerTypeFolders: [TriggerTypeFolder] = []

    private let environment: AppEnvironment
    private var cancellables = Set<AnyCancellable>()

    init(environment: AppEnvironment) {
        self.environment = environment
        bind()
        organizeTriggers()
    }

    func refresh() {
        Task {
            await environment.reminderService.refresh(force: true)
        }
    }

    private func bind() {
        environment.reminderService.$reminders
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.organizeTriggers()
            }
            .store(in: &cancellables)
    }

    private func organizeTriggers() {
        var grouped: [ReminderTriggerType: [TriggerDisplay]] = [:]

        // Inicializa todos os tipos de triggers com arrays vazios
        for type in ReminderTriggerType.allCases {
            grouped[type] = []
        }

        // Popula com os triggers existentes
        for reminder in environment.reminderService.reminders {
            for trigger in reminder.triggers {
                grouped[trigger.type, default: []]
                    .append(TriggerDisplay(id: trigger.id, reminder: reminder, trigger: trigger))
            }
        }

        triggerTypeFolders = grouped
            .sorted(by: { lhs, rhs in lhs.key.label < rhs.key.label })
            .map { TriggerTypeFolder(id: $0.key, items: $0.value) }
    }
}
