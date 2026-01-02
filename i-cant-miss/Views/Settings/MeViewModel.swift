//
//  MeViewModel.swift
//  i-cant-miss
//
//  Created by Codex on 2024-03-24.
//

import SwiftUI
import Combine

@MainActor
final class MeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var streakDays: Int = 0
    @Published var heatmapData: [Date: Int] = [:]
    @Published var memberSince: String = ""
    @Published var quoteOfTheDay: Quote = Quote.defaultQuote
    @Published var completionRate: Double = 0.0

    // MARK: - Models
    struct Quote {
        let text: String
        let author: String

        static let defaultQuote = Quote(text: "The best way to predict the future is to create it.", author: "Peter Drucker")
    }

    // MARK: - Private Properties
    private var memoryService: MemoryService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init(memoryService: MemoryService) {
        self.memoryService = memoryService

        // Listen to changes in memories to update stats
        memoryService.$memories
            .receive(on: RunLoop.main)
            .sink { [weak self] memories in
                self?.calculateStats(memories: memories)
            }
            .store(in: &cancellables)

        // Initial calculation
        calculateStats(memories: memoryService.memories)
        updateQuote()
    }

    // MARK: - Logic

    private func calculateStats(memories: [MemoryModel]) {
        calculateMemberSince(memories: memories)

        let allCompletionDates = extractCompletionDates(from: memories)
        calculateStreak(completionDates: allCompletionDates)
        generateHeatmapData(completionDates: allCompletionDates)
        calculateCompletionRate(memories: memories)
    }

    private func extractCompletionDates(from memories: [MemoryModel]) -> Set<Date> {
        var dates = Set<Date>()
        let calendar = Calendar.current

        for memory in memories {
            // For recurring memories
            for date in memory.completedDates {
                dates.insert(calendar.startOfDay(for: date))
            }

            // For single memories that are completed
            if memory.status == .completed && !memory.hasRecurringTriggers {
                // Use updatedAt as a proxy for completion time for single items logic
                //Ideally we would have completedAt, but updatedAt is close enough for single toggle
                dates.insert(calendar.startOfDay(for: memory.updatedAt))
            }
        }
        return dates
    }

    private func calculateMemberSince(memories: [MemoryModel]) {
        if let firstMemory = memories.min(by: { $0.createdAt < $1.createdAt }) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            memberSince = formatter.string(from: firstMemory.createdAt)
        } else {
            // Fallback if no memories, maybe use current date or generic
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            memberSince = formatter.string(from: Date())
        }
    }

    private func calculateStreak(completionDates: Set<Date>) {
        let sortedDates = completionDates.sorted(by: >)
        guard !sortedDates.isEmpty else {
            streakDays = 0
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Check if the streak is active (completed today or yesterday)
        let mostRecent = sortedDates.first!
        if !calendar.isDate(mostRecent, inSameDayAs: today) && !calendar.isDate(mostRecent, inSameDayAs: yesterday) {
            streakDays = 0
            return
        }

        var currentStreak = 0
        var checkDate = mostRecent

        // Count backwards
        for date in sortedDates {
            if calendar.isDate(date, inSameDayAs: checkDate) {
                currentStreak += 1
                // Prepare next expected date (previous day)
                if let prevDay = calendar.date(byAdding: .day, value: -1, to: checkDate) {
                    checkDate = prevDay
                } else {
                    break
                }
            } else if date > checkDate {
                // Duplicate or newer date, ignore
                continue
            } else {
                // Gap found
                break
            }
        }

        streakDays = currentStreak
    }

    private func generateHeatmapData(completionDates: Set<Date>) {
        // Simple map: Date -> 1 (completed something)
        // In a more complex version, Int could represent intensity (number of tasks)
        // For now, boolean existence is enough for level 1

        var map: [Date: Int] = [:]
        for date in completionDates {
            map[date] = 1 // 1 level of intensity
        }
        heatmapData = map
    }

    private func calculateCompletionRate(memories: [MemoryModel]) {
        guard !memories.isEmpty else {
            completionRate = 0.0
            return
        }

        // For recurring memories, it's tricky to define "total" vs "completed".
        // This is a simplified metric:
        // Rate = (Completed Memories + Active Recurring with some completions) / Total Active Memories?
        // Let's stick to the user Request "Taxa de Conclusão" for "Active Memories".
        // Maybe: Completed Memories / (Completed + Active)

        let completedCount = memories.filter { $0.status == .completed }.count
        // For recurring, we count them as completed if they were completed today? No, let's keep it global for now.
        // A better metric might be: Number of completed items vs total items.

        let total = memories.count
        guard total > 0 else {
            completionRate = 0.0
            return
        }

        completionRate = Double(completedCount) / Double(total)
    }

    private func updateQuote() {
        let quotes = [
            Quote(text: "Memory is the diary that we all carry about with us.", author: "Oscar Wilde"),
            Quote(text: "The true art of memory is the art of attention.", author: "Samuel Johnson"),
            Quote(text: "Focus on being productive instead of busy.", author: "Tim Ferriss"),
            Quote(text: "Small habits make a big difference.", author: "Anon"),
            Quote(text: "Consistency is key.", author: "Anon"),
            Quote(text: "Don't watch the clock; do what it does. Keep going.", author: "Sam Levenson"),
            Quote(text: "Your future is created by what you do today, not tomorrow.", author: "Robert Kiyosaki")
        ]

        // Stable random based on day of year
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = dayOfYear % quotes.count
        quoteOfTheDay = quotes[index]
    }
}
