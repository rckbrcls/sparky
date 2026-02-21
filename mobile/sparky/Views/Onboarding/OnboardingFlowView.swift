//
//  OnboardingFlowView.swift
//  sparky
//
//  Created by GPT-5 Codex on 07/11/25.
//

import SwiftUI
import Combine
import CoreLocation

// MARK: - Step Definition

private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case notifications, location

    var id: Int { rawValue }
    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var isLast: Bool { next == nil }

    var icon: String {
        switch self {
        case .notifications: return "bell.badge.fill"
        case .location: return "location.fill"
        }
    }

    var accentColor: Color {
        .accentColor
    }

    var title: String {
        switch self {
        case .notifications: return "Stay in the Loop"
        case .location: return "Places That Matter"
        }
    }

    var message: String {
        switch self {
        case .notifications:
            return "Get gentle reminders for your memories exactly when they matter most."
        case .location:
            return "Trigger memories automatically when you arrive at or leave a meaningful place."
        }
    }
}

// MARK: - Page Indicator

private struct StepPageIndicator: View {
    let steps: [OnboardingStep]
    let current: OnboardingStep

    var body: some View {
        HStack(spacing: 8) {
            ForEach(steps) { step in
                Capsule()
                    .fill(step == current ? Color.Theme.textPrimary : Color.Theme.textTertiary.opacity(0.4))
                    .frame(width: step == current ? 28 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: current)
    }
}

// MARK: - Hero Icon

private struct StepHeroView: View {
    let step: OnboardingStep

    var body: some View {
        Image(systemName: step.icon)
            .font(.system(size: 48, weight: .medium))
            .foregroundStyle(Color.accentColor)
            .frame(width: 120, height: 120)
            .glassEffect(.regular.tint(Color.accentColor.opacity(0.15)), in: .circle)
    }
}

// MARK: - Text Content

private struct StepContentView: View {
    let step: OnboardingStep

    var body: some View {
        VStack(spacing: 12) {
            Text(step.title)
                .appLargeTitleStyle()

            Text(step.message)
                .font(.body)
                .foregroundStyle(Color.Theme.textSecondary)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

// MARK: - Actions

private struct StepActionsView: View {
    let step: OnboardingStep
    let onAllow: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Button(action: onAllow) {
                Text("Allow")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.Theme.accentForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityHint(step == .notifications
                ? "Grants notification permission for reminders"
                : "Grants location permission for place-based reminders")

            Button("Not Now", action: onSkip)
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.Theme.textTertiary)
                .accessibilityHint("Skip this permission, you can enable it later in Settings")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}

// MARK: - Main View

struct OnboardingFlowView: View {
    let environment: AppEnvironment
    let onFinish: () -> Void

    @State private var currentStep: OnboardingStep = .notifications

    var body: some View {
        Color.Theme.background
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 24) {
                    StepPageIndicator(
                        steps: OnboardingStep.allCases,
                        current: currentStep
                    )
                    .padding(.top, 24)

                    Spacer()

                    StepHeroView(step: currentStep)
                        .id(currentStep)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))

                    StepContentView(step: currentStep)
                        .id(currentStep)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )

                    Spacer()

                    StepActionsView(
                        step: currentStep,
                        onAllow: allowAction,
                        onSkip: skipAction
                    )
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
    }

    private func allowAction() {
        switch currentStep {
        case .notifications:
            Task {
                await environment.triggerExecutorCoordinator.scheduled.requestAuthorizationIfNeeded()
                advance()
            }
        case .location:
            let location = environment.triggerExecutorCoordinator.location
            let currentStatus = location.authorizationStatus
            location.requestAuthorization(always: true)

            if currentStatus == .notDetermined {
                var cancellable: AnyCancellable?
                cancellable = location.$authorizationStatus
                    .dropFirst()
                    .filter { $0 != .notDetermined }
                    .first()
                    .receive(on: DispatchQueue.main)
                    .sink { [self] _ in
                        advance()
                        _ = cancellable
                    }
            } else {
                advance()
            }
        }
    }

    private func skipAction() {
        advance()
    }

    private func advance() {
        guard let next = currentStep.next else {
            onFinish()
            return
        }
        currentStep = next
    }
}

#Preview {
    OnboardingFlowView(
        environment: AppEnvironment(dataController: .preview),
        onFinish: {}
    )
}
