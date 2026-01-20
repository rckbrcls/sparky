//
//  OnboardingFlowView.swift
//  i-cant-miss
//
//  Created by GPT-5 Codex on 07/11/25.
//

import SwiftUI

private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome, organization, triggers, features

    var id: Int { rawValue }
    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var isLast: Bool { next == nil }
}

struct OnboardingFlowView: View {
    let onFinish: () -> Void

    @State private var currentStep: OnboardingStep = .welcome

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                TabView(selection: $currentStep) {
                    ForEach(OnboardingStep.allCases) { step in
                        slide(for: step)
                            .tag(step)
                    }
                }
                .applyPageTabStyle()
                .animation(.easeInOut(duration: 0.3), value: currentStep)

                footer
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
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
            step.visual
        }
    }

    private var background: some View {
        RadialGradient(
            colors: [
                Color.accentColor.opacity(0.20),
                Color.accentColor.opacity(0.08),
                Color(.systemBackground)
            ],
            center: .center,
            startRadius: 80,
            endRadius: 400
        )
    }

    private var header: some View {
        HStack {
            Label("Sparky", systemImage: "sparkles")
                .font(.footnote.weight(.semibold))
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    Capsule()
                        .fill(Color.accentColor.opacity(0.15))
                )
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            if !currentStep.isLast {
                Button("Skip") {
                    onFinish()
                }
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases) { step in
                    Capsule()
                        .fill(step == currentStep ? Color.accentColor : Color.accentColor.opacity(0.3))
                        .frame(width: step == currentStep ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: currentStep)
                }
            }

            Button(action: continueAction) {
                Text(isLastStep ? "Get Started" : "Continue")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.glassProminent)
        }
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

// MARK: - Step Content

private extension OnboardingStep {
    var title: String {
        switch self {
        case .welcome:
            return "Never miss what matters"
        case .organization:
            return "Organize by context"
        case .triggers:
            return "Smart reminders"
        case .features:
            return "Rich content"
        }
    }

    var message: String {
        switch self {
        case .welcome:
            return "Manage tasks and reminders with intelligence"
        case .organization:
            return "Minds → Lobes → Memories"
        case .triggers:
            return "Time, location, person, or sequence"
        case .features:
            return "Text, checklists, photos, links, and more"
        }
    }

    @ViewBuilder
    var visual: some View {
        switch self {
        case .welcome:
            WelcomeVisual()
        case .organization:
            OrganizationVisual()
        case .triggers:
            TriggersVisual()
        case .features:
            FeaturesVisual()
        }
    }
}

// MARK: - Visual Components

private struct WelcomeVisual: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 12) {
                SimpleFeature(icon: "square.and.pencil", text: "Capture")
                SimpleFeature(icon: "bell.badge", text: "Remind")
                SimpleFeature(icon: "arrow.triangle.2.circlepath", text: "Automate")
            }
        }
    }
}

private struct OrganizationVisual: View {
    var body: some View {
        VStack(spacing: 12) {
            HierarchyItem(icon: "brain.head.profile", text: "Mind", color: .blue)
            Image(systemName: "arrow.down")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                HierarchyItem(icon: "folder.fill", text: "Lobe", color: .orange)
                HierarchyItem(icon: "folder.fill", text: "Lobe", color: .pink)
            }
            Image(systemName: "arrow.down")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                HierarchyItem(icon: "doc.text", text: "Memory", color: .green, compact: true)
                HierarchyItem(icon: "doc.text", text: "Memory", color: .green, compact: true)
                HierarchyItem(icon: "doc.text", text: "Memory", color: .green, compact: true)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct TriggersVisual: View {
    var body: some View {
        VStack(spacing: 12) {
            SimpleTrigger(icon: "clock.fill", text: "Scheduled", color: .blue)
            SimpleTrigger(icon: "mappin.circle.fill", text: "Location", color: .green)
            SimpleTrigger(icon: "person.circle.fill", text: "Person", color: .pink)
            SimpleTrigger(icon: "arrow.triangle.branch", text: "Sequential", color: .purple)
        }
    }
}

private struct FeaturesVisual: View {
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ContentIcon(icon: "doc.text", color: .blue)
            ContentIcon(icon: "checklist", color: .green)
            ContentIcon(icon: "photo", color: .orange)
            ContentIcon(icon: "link", color: .cyan)
            ContentIcon(icon: "waveform", color: .purple)
            ContentIcon(icon: "doc", color: .gray)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Supporting Views

private struct SimpleFeature: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
            Text(text)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}

private struct HierarchyItem: View {
    let icon: String
    let text: String
    let color: Color
    var compact: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(compact ? .body : .title3)
                .foregroundStyle(color)
                .frame(width: compact ? 28 : 40, height: compact ? 28 : 40)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )
            if !compact {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SimpleTrigger: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.15))
                )
            Text(text)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}

private struct ContentIcon: View {
    let icon: String
    let color: Color

    var body: some View {
        Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(color)
            .frame(width: 50, height: 50)
            .background(
                Circle()
                    .fill(color.opacity(0.15))
            )
    }
}

// MARK: - Slide Container

private struct OnboardingSlide<Visual: View>: View {
    let title: String
    let message: String
    @ViewBuilder let visual: Visual

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }

            visual
                .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Utilities

private extension View {
    func applyPageTabStyle() -> some View {
        self.tabViewStyle(.page(indexDisplayMode: .never))
    }
}

#Preview {
    OnboardingFlowView(onFinish: {})
}
