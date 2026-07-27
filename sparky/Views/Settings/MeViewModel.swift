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
    @Published private(set) var metrics: MeMetrics

    private let now: () -> Date
    private let calendar: Calendar
    private var cancellables = Set<AnyCancellable>()

    init(
        memoryService: MemoryService,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.now = now
        self.calendar = calendar
        self.metrics = MeMetrics.calculate(
            memories: memoryService.memories,
            now: now(),
            calendar: calendar
        )

        memoryService.$memories
            .receive(on: RunLoop.main)
            .sink { [weak self] memories in
                guard let self else { return }
                metrics = MeMetrics.calculate(
                    memories: memories,
                    now: self.now(),
                    calendar: self.calendar
                )
            }
            .store(in: &cancellables)
    }
}
