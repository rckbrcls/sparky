//
//  MindEmptyStateTests.swift
//  sparkyTests
//

import Testing
import Foundation
@testable import sparky

struct MindEmptyStateTests {

    // MARK: - Empty State Visibility Tests

    @Test func emptyStateShownWhenTrulyEmpty() {
        let shouldShow = MindDetailView.shouldShowEmptyState(
            childMindsCount: 0,
            unfilteredMemoriesCount: 0
        )
        #expect(shouldShow == true)
    }

    @Test func emptyStateHiddenWhenChildMindExists() {
        let shouldShow = MindDetailView.shouldShowEmptyState(
            childMindsCount: 1,
            unfilteredMemoriesCount: 0
        )
        #expect(shouldShow == false)
    }

    @Test func emptyStateHiddenWhenActiveMemoryExists() {
        let shouldShow = MindDetailView.shouldShowEmptyState(
            childMindsCount: 0,
            unfilteredMemoriesCount: 1
        )
        #expect(shouldShow == false)
    }

    @Test func emptyStateHiddenWhenCompletedMemoryExists() {
        // Completed memories in unfiltered count prevent empty state
        let shouldShow = MindDetailView.shouldShowEmptyState(
            childMindsCount: 0,
            unfilteredMemoriesCount: 1
        )
        #expect(shouldShow == false)
    }

    @Test func emptyStateVisibilityIsFilterIndependent() {
        // Even if active filter returns 0 rows, unfiltered count of 1 prevents empty state
        let unfilteredMemoriesCount = 1
        let filteredMemoriesCount = 0

        let shouldShow = MindDetailView.shouldShowEmptyState(
            childMindsCount: 0,
            unfilteredMemoriesCount: unfilteredMemoriesCount
        )
        #expect(filteredMemoriesCount == 0)
        #expect(shouldShow == false)
    }

    // MARK: - Target Mind Mapping Tests

    @MainActor
    @Test func targetMindMappingForRealMind() {
        let realMind = Mind(name: "Work Projects")
        let target = MindDetailView.targetMind(for: realMind)
        #expect(target?.id == realMind.id)
    }

    @MainActor
    @Test func targetMindMappingForAllMindsVirtualMind() {
        let allMinds = Mind.allMinds
        let target = MindDetailView.targetMind(for: allMinds)
        #expect(target == nil)
    }

}
