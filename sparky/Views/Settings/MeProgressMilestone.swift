import Foundation

enum MeProgressMilestone {
    static func streakTarget(for value: Int) -> Int {
        target(
            for: value,
            fixedMilestones: [3, 7, 14, 30],
            repeatingStep: 30
        )
    }

    static func completionTarget(for value: Int) -> Int {
        target(
            for: value,
            fixedMilestones: [7, 25, 50, 100],
            repeatingStep: 100
        )
    }

    static func progress(value: Int, target: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(max(Double(value) / Double(target), 0), 1)
    }
}

private extension MeProgressMilestone {
    static func target(
        for value: Int,
        fixedMilestones: [Int],
        repeatingStep: Int
    ) -> Int {
        let value = max(value, 0)

        if let milestone = fixedMilestones.first(where: { $0 >= value }) {
            return milestone
        }

        let multiplier = Int(
            ceil(Double(value) / Double(repeatingStep))
        )
        return multiplier * repeatingStep
    }
}
