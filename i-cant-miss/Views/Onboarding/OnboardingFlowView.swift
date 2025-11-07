//
//  OnboardingFlowView.swift
//  i-cant-miss
//
//  Created by GPT-5 Codex on 07/11/25.
//

import SwiftUI

private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome, triggers, spaces, memories

    var id: Int { rawValue }
    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var isLast: Bool { next == nil }
}

struct OnboardingFlowView: View {
    let onFinish: () -> Void

    @EnvironmentObject private var environment: AppEnvironment
    @State private var currentStep: OnboardingStep = .welcome

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            VStack(spacing: 32) {
                header

                TabView(selection: $currentStep) {
                    ForEach(OnboardingStep.allCases) { step in
                        slide(for: step)
                            .tag(step)
                    }
                }
                .applyPageTabStyle()
                .animation(.easeInOut(duration: 0.3), value: currentStep)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
            }
            .padding(.vertical, 32)

        }
    }

    private var isLastStep: Bool {
        currentStep.isLast
    }

    @ViewBuilder
    private func slide(for step: OnboardingStep) -> some View {
        OnboardingSlide(
            title: step.title,
            message: step.message
        ) {
            step.visual(environment: environment)
        }
    }

    private var background: some View {
        RadialGradient(
            colors: [
                Color.accentColor.opacity(0.35),
                Color.accentColor.opacity(0.15),
                Color(.systemBackground)
            ],
            center: .center,
            startRadius: 120,
            endRadius: 620
        )
    }

    private var leadingBadge: some View {
        Label("I Can't Miss", systemImage: "sparkles")
            .font(.footnote.weight(.semibold))
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.12))
            )
            .foregroundStyle(.white.opacity(0.9))
    }

    private var header: some View {
        HStack {
            leadingBadge

            Spacer(minLength: 0)

            if !currentStep.isLast {
                Button("Skip") {
                    onFinish()
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 24)
    }

    private var footer: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases) { step in
                    Capsule()
                        .fill(step == currentStep ? Color.white : Color.white.opacity(0.35))
                        .frame(width: step == currentStep ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: currentStep)
                }
            }

            Button(action: continueAction) {
                Text(isLastStep ? "Get started" : "Continue")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.glassProminent)
            .shadow(color: Color.accentColor.opacity(0.2), radius: 16, y: 8)
        }
        .padding(.horizontal, 24)
    }

    private func continueAction() {
        guard let nextStep = currentStep.next else {
            onFinish()
            return
        }

        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = nextStep
        }
    }
}

private extension OnboardingStep {
    var title: String {
        switch self {
        case .welcome:
            return "Capture what matters"
        case .triggers:
            return "Smart triggers"
        case .spaces:
            return "Spaces for every plan"
        case .memories:
            return "Timeline of wins"
        }
    }

    var message: String {
        switch self {
        case .welcome:
            return "Turn commitments into living memories so the right trigger always finds you."
        case .triggers:
            return "Time, place, people for nudges right on cue."
        case .spaces:
            return "Group every promise into Spaces that stay organized and easy to scan."
        case .memories:
            return "Review notes, checklists, and media in a single, evolving storyline."
        }
    }

    @ViewBuilder
    func visual(environment: AppEnvironment) -> some View {
        switch self {
        case .welcome:
            VStack(spacing: 18) {
                Image(systemName: "sparkles")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.35), radius: 12, y: 4)

                VStack(spacing: 10) {
                    OnboardingHighlightRow(
                        icon: "pencil",
                        title: "Capture commitments and ideas",
                        accent: Color.white.opacity(0.85)
                    )
                    OnboardingHighlightRow(
                        icon: "bell.badge.fill",
                        title: "Stay aligned with personal alerts",
                        accent: Color.white.opacity(0.75)
                    )
                }
                .padding(16)
                .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }

        case .triggers:
            VStack(spacing: 16) {
                OnboardingMiniCard(
                    icon: "clock.badge.checkmark",
                    title: "Smart schedules",
                    description: "Pick one-off dates or simple repeats in seconds.",
                    accent: Color.blue
                )

                OnboardingMiniCard(
                    icon: "mappin.and.ellipse",
                    title: "Places that matter",
                    description: "Arrive or leave and get nudged right on time.",
                    accent: Color.green
                )

                OnboardingMiniCard(
                    icon: "person.2.wave.2.fill",
                    title: "Shared triggers",
                    description: "Loop in the right people to remember together.",
                    accent: Color.pink
                )
            }

        case .spaces:
            VStack(alignment: .leading, spacing: 18) {
                Text("Sample Spaces")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))

                VStack(spacing: 12) {
                    ForEach(OnboardingSampleData.spaces) { entry in
                        SpaceRowView(space: entry.space, count: entry.count)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .allowsHitTesting(false)
                    }
                }
                .padding(12)
                .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.black.opacity(0.25),
                                    Color.black.opacity(0.45)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 90)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 4)
                        .allowsHitTesting(false)
                        .blendMode(.softLight)
                }
                .allowsHitTesting(false)
            }

        case .memories:
            VStack(alignment: .leading, spacing: 16) {
                ForEach(OnboardingSampleData.memories) { memory in
                    MemoryCardView(memory: memory)
                        .environmentObject(environment)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 4)
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.black.opacity(0.25),
                                Color.black.opacity(0.45)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                    .allowsHitTesting(false)
                    .blendMode(.softLight)
            }
        }
    }
}

// MARK: - Sample Content

private enum OnboardingSampleData {
    struct SpaceEntry: Identifiable {
        let id = UUID()
        let space: SpaceModel
        let count: Int
    }

    static let spaces: [SpaceEntry] = {
        let work = SpaceModel(
            id: UUID(),
            name: "Work",
            colorHex: "#F97316",
            iconName: "briefcase.fill",
            sortOrder: 0
        )

        let family = SpaceModel(
            id: UUID(),
            name: "Family",
            colorHex: "#EC4899",
            iconName: "heart.circle.fill",
            sortOrder: 1
        )

        let adventures = SpaceModel(
            id: UUID(),
            name: "Adventures",
            colorHex: "#14B8A6",
            iconName: "airplane",
            sortOrder: 2
        )

        return [
            SpaceEntry(space: work, count: 24),
            SpaceEntry(space: family, count: 12),
            SpaceEntry(space: adventures, count: 6)
        ]
    }()

    static let memories: [MemoryModel] = {
        guard
            let workSpace = spaces.first(where: { $0.space.name == "Work" })?.space,
            let adventureSpace = spaces.first(where: { $0.space.name == "Adventures" })?.space
        else {
            return []
        }

        let now = Date()
        let calendar = Calendar.current

        let travelChecklist: [CheckItemModel] = [
            CheckItemModel(
                id: UUID(),
                title: "Confirm hotel pickup",
                detail: nil,
                isCompleted: true,
                sortOrder: 0,
                createdAt: now.addingTimeInterval(-86_400 * 6),
                updatedAt: now.addingTimeInterval(-86_400 * 5),
                completedAt: now.addingTimeInterval(-86_400 * 5)
            ),
            CheckItemModel(
                id: UUID(),
                title: "Pack camera gear",
                detail: nil,
                isCompleted: true,
                sortOrder: 1,
                createdAt: now.addingTimeInterval(-86_400 * 5),
                updatedAt: now.addingTimeInterval(-86_400 * 3),
                completedAt: now.addingTimeInterval(-86_400 * 3)
            ),
            CheckItemModel(
                id: UUID(),
                title: "Download offline maps",
                detail: nil,
                isCompleted: false,
                sortOrder: 2,
                createdAt: now.addingTimeInterval(-86_400 * 4),
                updatedAt: now.addingTimeInterval(-3_600),
                completedAt: nil
            )
        ]

        let travelTrigger = MemoryTriggerModel(
            id: UUID(),
            type: .location,
            fireDate: calendar.date(byAdding: .day, value: 3, to: now),
            startDate: now,
            recurrenceRule: nil,
            timeZoneIdentifier: TimeZone.current.identifier,
            weekdayMask: 0,
            isActive: true,
            location: MemoryTriggerModel.TriggerLocation(
                latitude: -22.9068,
                longitude: -43.1729,
                radius: 300,
                name: "GRU Airport",
                event: .onEntry
            ),
            person: nil,
            spacedStage: 0,
            lastReviewDate: nil,
            ignoreCount: 0
        )

        let investorTrigger = MemoryTriggerModel(
            id: UUID(),
            type: .time,
            fireDate: calendar.date(byAdding: .hour, value: 6, to: now),
            startDate: now,
            recurrenceRule: RecurrenceRule(frequency: .weekly, interval: 1),
            timeZoneIdentifier: TimeZone.current.identifier,
            weekdayMask: 0,
            isActive: true,
            location: nil,
            person: MemoryTriggerModel.TriggerPerson(
                name: "Maya Singh",
                contactIdentifier: nil
            ),
            spacedStage: 0,
            lastReviewDate: nil,
            ignoreCount: 0
        )

        let travelMemory = MemoryModel(
            id: UUID(),
            title: "Atacama Desert Trip",
            body: "Checklist done. Trigger fires as soon as you arrive at GRU.",
            createdAt: now.addingTimeInterval(-86_400 * 10),
            updatedAt: now,
            status: .active,
            isPinned: true,
            priority: .high,
            dueDate: calendar.date(byAdding: .day, value: 12, to: now),
            space: adventureSpace,
            triggers: [travelTrigger],
            checkItems: travelChecklist,
            snoozeCount: 1,
            lastCompletionDate: nil,
            metadata: MemoryModel.Metadata(origin: .reminder(UUID())),
            attachments: []
        )

        let investorMemory = MemoryModel(
            id: UUID(),
            title: "Investor update with Maya",
            body: "Share growth metrics and highlight the new trigger-first onboarding.",
            createdAt: now.addingTimeInterval(-86_400 * 2),
            updatedAt: now,
            status: .active,
            isPinned: false,
            priority: .medium,
            dueDate: calendar.date(byAdding: .day, value: 2, to: now),
            space: workSpace,
            triggers: [investorTrigger],
            checkItems: [],
            snoozeCount: 0,
            lastCompletionDate: nil,
            metadata: MemoryModel.Metadata(origin: .note(UUID())),
            attachments: []
        )

        return [travelMemory, investorMemory]
    }()
}

// MARK: - Building Blocks

private struct OnboardingSlide<Visual: View>: View {
    let title: String
    let message: String
    @ViewBuilder let visual: Visual

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            VStack(spacing: 14) {
                Text(title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: 420)
            }

            visual
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .ignoresSafeArea(edges: .top)
    }
}

private struct OnboardingHighlightRow: View {
    let icon: String
    let title: String
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(accent.opacity(0.18))
                )
                .foregroundStyle(accent)

            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.9))

            Spacer(minLength: 0)
        }
    }
}

private struct OnboardingMiniCard: View {
    let icon: String
    let title: String
    let description: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(accent)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(accent.opacity(0.22))
                )

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Text(description)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// MARK: - Utilities

private extension View {
    @ViewBuilder
    func zeroContentMarginsIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            contentMargins(.zero, for: .scrollContent)
        } else {
            self
        }
    }

    @ViewBuilder
    func applyPageTabStyle() -> some View {
        if #available(iOS 17.0, *) {
            self.tabViewStyle(.page(indexDisplayMode: .never))
        } else {
            self.tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return OnboardingFlowView(onFinish: {})
        .environmentObject(environment)
}
