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

    @Published var selectedType: ReminderTriggerType? {
        didSet { regroupTriggers() }
    }
    @Published private(set) var groups: [TriggerGroup] = []

    private let environment: AppEnvironment
    private var cancellables = Set<AnyCancellable>()

    init(environment: AppEnvironment) {
        self.environment = environment
        bind()
        regroupTriggers()
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
                self?.regroupTriggers()
            }
            .store(in: &cancellables)
    }

    private func regroupTriggers() {
        var grouped: [ReminderTriggerType: [TriggerDisplay]] = [:]
        for reminder in environment.reminderService.reminders {
            for trigger in reminder.triggers {
                if let filterType = selectedType, trigger.type != filterType {
                    continue
                }
                grouped[trigger.type, default: []]
                    .append(TriggerDisplay(id: trigger.id, reminder: reminder, trigger: trigger))
            }
        }

        groups = grouped
            .sorted(by: { lhs, rhs in lhs.key.label < rhs.key.label })
            .map { TriggerGroup(id: $0.key, items: $0.value) }
    }
}
