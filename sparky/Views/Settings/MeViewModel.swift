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
    struct Quote: Hashable {
        let text: String
        let author: String

        static let defaultQuote = Quote(
            text: "The best way to predict the future is to create it.",
            author: "Peter Drucker"
        )
    }

    @Published var activityDays: [MeMetrics.ActivityDay] = []
    @Published var streakDays: Int = 0
    @Published var longestStreakDays: Int = 0
    @Published var totalCompletionCount: Int = 0
    @Published var topMindName: String?
    @Published var completionCountLast7Days: Int = 0
    @Published var activeDaysLast7Days: Int = 0
    @Published var completionRate = MeMetrics.CompletionRate(
        completedOccurrences: 0,
        scheduledOccurrences: 0
    )
    @Published var quoteOfTheDay = Quote.defaultQuote
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
        refreshQuote()
    }

    static func quote(for date: Date, calendar: Calendar = .current) -> Quote {
        let quotes: [Quote] = [
            .defaultQuote,
            Quote(text: "Memory is the diary that we all carry about with us.", author: "Oscar Wilde"),
            Quote(text: "The true art of memory is the art of attention.", author: "Samuel Johnson"),
            Quote(text: "Focus on being productive instead of busy.", author: "Tim Ferriss"),
            Quote(text: "Small habits make a big difference.", author: "Anon"),
            Quote(text: "Consistency is key.", author: "Anon"),
            Quote(text: "Don't watch the clock; do what it does. Keep going.", author: "Sam Levenson"),
            Quote(text: "Your future is created by what you do today, not tomorrow.", author: "Robert Kiyosaki"),
            Quote(text: "Small steps still move you forward.", author: "Anon"),
            Quote(text: "Make space for what matters.", author: "Anon"),
            Quote(text: "One clear intention can shape the day.", author: "Anon"),
            Quote(text: "Attention gives meaning to memory.", author: "Anon"),
            Quote(text: "A calm mind notices what matters.", author: "Anon"),
            Quote(text: "Keep the promise you made to yourself.", author: "Anon"),
            Quote(text: "A little progress changes the whole day.", author: "Anon"),
            Quote(text: "Return to what matters most.", author: "Anon"),
            Quote(text: "One finished thing is worth ten intentions.", author: "Anon"),
            Quote(text: "Today is enough for one meaningful step.", author: "Anon"),
            Quote(text: "Clarity grows when you begin.", author: "Anon"),
            Quote(text: "Quiet consistency creates lasting change.", author: "Anon")
        ]
        let referenceDay = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let selectedDay = calendar.startOfDay(for: date)
        let dayOffset = calendar.dateComponents([.day], from: referenceDay, to: selectedDay).day ?? 0
        let index = ((dayOffset % quotes.count) + quotes.count) % quotes.count
        return quotes[index]
    }

    private func updateMetrics(memories: [Memory]) {
        let metrics = MeMetrics.calculate(
            memories: memories,
            now: now(),
            calendar: calendar
        )
        activityDays = metrics.activityDays
        streakDays = metrics.streakDays
        longestStreakDays = metrics.longestStreakDays
        totalCompletionCount = metrics.totalCompletionCount
        topMindName = metrics.topMindName
        completionCountLast7Days = metrics.completionCountLast7Days
        activeDaysLast7Days = metrics.activeDaysLast7Days
        completionRate = metrics.completionRate
        completionCountLast30Days = metrics.completionCountLast30Days
        activeDaysLast30Days = metrics.activeDaysLast30Days
    }

    func refreshQuote() {
        quoteOfTheDay = Self.quote(for: now(), calendar: calendar)
    }
}
