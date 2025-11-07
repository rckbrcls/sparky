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

                        triggersStep
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .tag(1)

                        spacesStep
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .tag(2)

                        memoriesStep
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .zeroContentMarginsIfAvailable()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            }
            .ignoresSafeArea()
            .safeAreaInset(edge: .bottom) {
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
            message: "iCantMiss turns your moments and ideas into living memories. Capture what matters and receive reminders at the perfect time."
        ) {
            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.4), radius: 12, y: 4)

                VStack(spacing: 12) {
                    OnboardingHighlightRow(
                        icon: "pencil",
                        title: "Capture feelings, commitments, and ideas",
                        accent: Color.white.opacity(0.85)
                    )
                    OnboardingHighlightRow(
                        icon: "bell.badge.fill",
                        title: "Get personalized alerts so you never forget",
                        accent: Color.white.opacity(0.75)
                    )
                    OnboardingHighlightRow(
                        icon: "photo.on.rectangle.angled",
                        title: "Add visual attachments to enrich every memory",
                        accent: Color.white.opacity(0.65)
                    )
                }
                .padding(20)
                .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }

    var triggersStep: some View {
        OnboardingSlide(
            title: "Wake memories with smart triggers",
            message: "Combine time, location, and people to be reminded in the perfect moment."
        ) {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    OnboardingMiniCard(
                        icon: "clock.badge.checkmark",
                        title: "Smart schedules",
                        description: "Pick specific dates or repeating patterns. Never miss due dates or appointments again.",
                        accent: Color.blue
                    )

                    OnboardingMiniCard(
                        icon: "mappin.and.ellipse",
                        title: "Places that matter",
                        description: "Enter or leave key areas and get reminded automatically.",
                        accent: Color.green
                    )
                }

                OnboardingMiniCard(
                    icon: "person.2.wave.2.fill",
                    title: "Important people",
                    description: "Trigger memories when you are with someone special. Technology handles the rest.",
                    accent: Color.pink
                )
            }
        }
    }

    var spacesStep: some View {
        OnboardingSlide(
            title: "Organize everything with Spaces",
            message: "Group memories by themes, life areas, or projects. Spaces keep everything right where it belongs."
        ) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Space examples")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))

                VStack(spacing: 14) {
                    OnboardingSpaceRow(
                        icon: "briefcase.fill",
                        title: "Work",
                        description: "Projects, meeting ideas, and critical deliverables always within reach.",
                        color: Color.orange
                    )

                    OnboardingSpaceRow(
                        icon: "heart.circle.fill",
                        title: "Family",
                        description: "Celebrations, daily care, and moments worth sharing together.",
                        color: Color.red
                    )

                    OnboardingSpaceRow(
                        icon: "leaf.fill",
                        title: "Wellness",
                        description: "Self-care routines, habits, and rituals you will want to repeat.",
                        color: Color.green
                    )
                }
            }
        }
    }

    var memoriesStep: some View {
        OnboardingSlide(
            title: "Memories that tell stories",
            message: "Every memory is alive: combine rich text, checklists, attachments, and watch your timeline evolve."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                OnboardingMemoryPreview(
                    title: "Trip to the Atacama Desert",
                    subtitle: "Prep checklist complete • Location trigger at the airport",
                    highlights: [
                        ("checklist", "8/8 items completed"),
                        ("location.fill", "Fires when arriving at GRU"),
                        ("photo", "4 highlight photos")
                    ]
                )

                OnboardingMemoryPreview(
                    title: "Investor meeting",
                    subtitle: "Quick notes + reminder 30 min before",
                    highlights: [
                        ("doc.richtext.fill", "Key points summary"),
                        ("timer", "Recurring trigger, every Monday"),
                        ("sparkles.rectangle.stack", "Slide deck attachments")
                    ]
                )
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
        ScrollView {
            VStack(spacing: 32) {
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
                .padding(.top, 100)

                visual
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .top)
    }
}

private struct OnboardingHighlightRow: View {
    let icon: String
    let title: String
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(accent.opacity(0.2))
                )
                .foregroundStyle(accent)

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.9))

            Spacer()
        }
    }
}

private struct OnboardingMiniCard: View {
    let icon: String
    let title: String
    let description: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title.weight(.semibold))
                .foregroundStyle(accent)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(accent.opacity(0.2))
                )

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct OnboardingSpaceRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color.opacity(0.2))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()
        }
        .padding(18)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct OnboardingMemoryPreview: View {
    let title: String
    let subtitle: String
    let highlights: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Divider()
                .overlay(Color.white.opacity(0.35))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], alignment: .leading, spacing: 10) {
                ForEach(highlights.indices, id: \.self) { index in
                    let highlight = highlights[index]
                    Label(highlight.1, systemImage: highlight.0)
                        .font(.footnote.weight(.medium))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .padding(22)
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
