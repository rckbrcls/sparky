import Testing
@testable import sparky

struct MeProgressMilestoneTests {
    @Test func streakTargetsUseFixedAndRepeatingMilestones() {
        #expect(MeProgressMilestone.streakTarget(for: 0) == 3)
        #expect(MeProgressMilestone.streakTarget(for: 3) == 3)
        #expect(MeProgressMilestone.streakTarget(for: 4) == 7)
        #expect(MeProgressMilestone.streakTarget(for: 14) == 14)
        #expect(MeProgressMilestone.streakTarget(for: 30) == 30)
        #expect(MeProgressMilestone.streakTarget(for: 31) == 60)
        #expect(MeProgressMilestone.streakTarget(for: 60) == 60)
        #expect(MeProgressMilestone.streakTarget(for: 61) == 90)
    }

    @Test func completionTargetsUseFixedAndRepeatingMilestones() {
        #expect(MeProgressMilestone.completionTarget(for: 0) == 7)
        #expect(MeProgressMilestone.completionTarget(for: 7) == 7)
        #expect(MeProgressMilestone.completionTarget(for: 8) == 25)
        #expect(MeProgressMilestone.completionTarget(for: 50) == 50)
        #expect(MeProgressMilestone.completionTarget(for: 100) == 100)
        #expect(MeProgressMilestone.completionTarget(for: 101) == 200)
        #expect(MeProgressMilestone.completionTarget(for: 200) == 200)
        #expect(MeProgressMilestone.completionTarget(for: 201) == 300)
    }

    @Test func progressIsClampedToTheAvailableRange() {
        #expect(MeProgressMilestone.progress(value: -1, target: 7) == 0)
        #expect(MeProgressMilestone.progress(value: 3, target: 7) == 3.0 / 7.0)
        #expect(MeProgressMilestone.progress(value: 7, target: 7) == 1)
        #expect(MeProgressMilestone.progress(value: 8, target: 7) == 1)
        #expect(MeProgressMilestone.progress(value: 8, target: 0) == 0)
    }
}
