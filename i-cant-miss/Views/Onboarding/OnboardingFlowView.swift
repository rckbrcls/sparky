//
//  OnboardingFlowView.swift
//  i-cant-miss
//
//  Created by GPT-5 Codex on 07/11/25.
//

import SwiftUI

struct OnboardingFlowView: View {
    let onFinish: () -> Void

    @State private var selection = 0

    private let totalSteps = 4

    var body: some View {
        NavigationStack {
            ZStack {
                background
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    TabView(selection: $selection) {
                        welcomeStep
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .tag(0)
                            .tabBarSpacer()

                        triggersStep
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .tag(1)
                            .tabBarSpacer()

                        spacesStep
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .tag(2)
                            .tabBarSpacer()

                        memoriesStep
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .tag(3)
                            .tabBarSpacer()
                    }
                    .toolbar(.hidden, for: .tabBar)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .zeroContentMarginsIfAvailable()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            }
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                footer
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leadingBadge
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if selection < totalSteps - 1 {
                        Button("Skip") {
                            onFinish()
                        }
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
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
        Label("iCantMiss", systemImage: "sparkles")
            .font(.footnote.weight(.semibold))
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.12))
            )
            .foregroundStyle(.white.opacity(0.9))
    }

    private var footer: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index == selection ? Color.white : Color.white.opacity(0.35))
                        .frame(width: index == selection ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selection)
                }
            }

            Button(action: continueAction) {
                Text(selection == totalSteps - 1 ? "Start capturing memories" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.95))
            )
            .foregroundStyle(Color.accentColor)
            .shadow(color: Color.accentColor.opacity(0.2), radius: 16, y: 8)
        }
    }

    private func continueAction() {
        if selection >= totalSteps - 1 {
            onFinish()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                selection += 1
            }
        }
    }
}

// MARK: - Steps

private extension OnboardingFlowView {
    var welcomeStep: some View {
        OnboardingSlide(
            title: "Create unforgettable memories",
            message: "Turn ideas into living memories. Capture what matters and get reminders right on time."
        ) {
            VStack(spacing: 18) {
                Image(systemName: "sparkles")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.35), radius: 12, y: 4)

                VStack(spacing: 10) {
                    OnboardingHighlightRow(
                        icon: "pencil",
                        title: "Capture feelings, commitments, and ideas",
                        accent: Color.white.opacity(0.85)
                    )
                    OnboardingHighlightRow(
                        icon: "bell.badge.fill",
                        title: "Stay on track with personalized alerts",
                        accent: Color.white.opacity(0.75)
                    )
                }
                .padding(16)
                .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }

    var triggersStep: some View {
        OnboardingSlide(
            title: "Wake memories with smart triggers",
            message: "Combine time and place to be reminded exactly when it matters."
        ) {
            VStack(spacing: 18) {
                OnboardingMiniCard(
                    icon: "clock.badge.checkmark",
                    title: "Smart schedules",
                    description: "Pick specific dates or repeating patterns so nothing slips.",
                    accent: Color.blue
                )

                OnboardingMiniCard(
                    icon: "mappin.and.ellipse",
                    title: "Places that matter",
                    description: "Arrive or leave a location and receive timely reminders.",
                    accent: Color.green
                )

                OnboardingHighlightRow(
                    icon: "person.2.wave.2.fill",
                    title: "Loop in the right people with shared triggers",
                    accent: Color.pink.opacity(0.85)
                )
                .padding(16)
                .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }

    var spacesStep: some View {
        OnboardingSlide(
            title: "Organize everything with Spaces",
            message: "Group memories by themes or projects so every idea has a home."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Space examples")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))

                VStack(spacing: 12) {
                    OnboardingSpaceRow(
                        icon: "briefcase.fill",
                        title: "Work",
                        description: "Projects and decisions ready for the next meeting.",
                        color: Color.orange
                    )

                    OnboardingSpaceRow(
                        icon: "heart.circle.fill",
                        title: "Family",
                        description: "Celebrations and small wins to share together.",
                        color: Color.red
                    )

                    OnboardingSpaceRow(
                        icon: "leaf.fill",
                        title: "Wellness",
                        description: "Self-care rituals that keep you balanced.",
                        color: Color.green
                    )
                }
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
                        .allowsHitTesting(false)
                        .blendMode(.softLight)
                }
            }
        }
    }

    var memoriesStep: some View {
        OnboardingSlide(
            title: "Memories that tell stories",
            message: "Combine rich text, checklists, and media to watch your timeline evolve."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                OnboardingMemoryPreview(
                    title: "Trip to the Atacama Desert",
                    subtitle: "Prep checklist complete • Location trigger at the airport",
                    highlights: [
                        ("checklist", "8/8 items completed"),
                        ("location.fill", "Reminder at GRU arrival")
                    ]
                )

                OnboardingMemoryPreview(
                    title: "Investor meeting",
                    subtitle: "Quick notes + reminder 30 min before",
                    highlights: [
                        ("doc.richtext.fill", "Key points summary"),
                        ("timer", "Recurring trigger every Monday")
                    ]
                )
            }
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
                    .allowsHitTesting(false)
                    .blendMode(.softLight)
            }
        }
    }
}

// MARK: - Building Blocks

private struct OnboardingSlide<Visual: View>: View {
    let title: String
    let message: String
    @ViewBuilder let visual: Visual

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            VStack(spacing: 16) {
                Text(title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: 420)
            }

            visual
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
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
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(accent)
                .padding(10)
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
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private struct OnboardingSpaceRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color.opacity(0.22))
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct OnboardingMemoryPreview: View {
    let title: String
    let subtitle: String
    let highlights: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Divider()
                .overlay(Color.white.opacity(0.3))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(highlights.indices, id: \.self) { index in
                    let highlight = highlights[index]
                    Label(highlight.1, systemImage: highlight.0)
                        .font(.footnote.weight(.medium))
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .padding(18)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
}

#Preview {
    OnboardingFlowView(onFinish: {})
}
