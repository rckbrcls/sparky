import Testing
@testable import sparky

struct MeCharacterMoodTests {
    @Test func streakMoodUsesBalancedThresholds() {
        #expect(MeCharacterMood.streak(for: -1) == .sad)
        #expect(MeCharacterMood.streak(for: 0) == .sad)
        #expect(MeCharacterMood.streak(for: 1) == .hopeful)
        #expect(MeCharacterMood.streak(for: 6) == .hopeful)
        #expect(MeCharacterMood.streak(for: 7) == .happy)
        #expect(MeCharacterMood.streak(for: 29) == .happy)
        #expect(MeCharacterMood.streak(for: 30) == .euphoric)
    }

    @Test func completedMoodUsesBalancedThresholds() {
        #expect(MeCharacterMood.completed(for: -1) == .sad)
        #expect(MeCharacterMood.completed(for: 0) == .sad)
        #expect(MeCharacterMood.completed(for: 1) == .hopeful)
        #expect(MeCharacterMood.completed(for: 24) == .hopeful)
        #expect(MeCharacterMood.completed(for: 25) == .happy)
        #expect(MeCharacterMood.completed(for: 99) == .happy)
        #expect(MeCharacterMood.completed(for: 100) == .euphoric)
    }

    @Test func moodsResolveToTheExpectedAssets() {
        #expect(
            MeCharacterMood.allCases.map(\.streakImageName)
                == [
                    "MeStreakSad",
                    "MeStreakHopeful",
                    "MeStreakHappy",
                    "MeStreakEuphoric"
                ]
        )
        #expect(
            MeCharacterMood.allCases.map(\.completedImageName)
                == [
                    "MeCompletedSad",
                    "MeCompletedHopeful",
                    "MeCompletedHappy",
                    "MeCompletedEuphoric"
                ]
        )
    }
}
