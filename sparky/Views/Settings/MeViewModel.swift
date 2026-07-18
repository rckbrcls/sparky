//
//  MeViewModel.swift
//  sparky
//
//  Created by Codex on 2024-03-24.
//

import Combine
import Foundation

@MainActor
final class MeViewModel: ObservableObject {
    @Published var activityDays: [MeMetrics.ActivityDay] = []
    @Published var streakDays: Int = 0
    @Published var completionRate = MeMetrics.CompletionRate(
        completedOccurrences: 0,
        scheduledOccurrences: 0
    )
    @Published var insight = "Complete a memory to start seeing your rhythm."
    @Published var completionCountLast30Days = 0
    @Published var activeDaysLast30Days = 0

    private let memoryService: MemoryService
    private let now: () -> Date
    private let calendar: Calendar
    private var cancellables = Set<AnyCancellable>()

    init(
        memoryService: MemoryService,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.memoryService = memoryService
        self.now = now
        self.calendar = calendar

        memoryService.$memories
            .receive(on: RunLoop.main)
            .sink { [weak self] memories in
                self?.updateMetrics(memories: memories)
            }
            .store(in: &cancellables)

        updateMetrics(memories: memoryService.memories)
    }

    private func updateMetrics(memories: [Memory]) {
        let metrics = MeMetrics.calculate(
            memories: memories,
            now: now(),
            calendar: calendar
        )
        activityDays = metrics.activityDays
        streakDays = metrics.streakDays
        completionRate = metrics.completionRate
        insight = metrics.insight
        completionCountLast30Days = metrics.completionCountLast30Days
        activeDaysLast30Days = metrics.activeDaysLast30Days
    }
}
