//
//  MeView.swift
//  sparky
//
//  Created by Codex on 07/12/25.
//

import SwiftUI

struct MeView: View {
    @ObservedObject private var environment: AppEnvironment
    @ObservedObject private var settings: SettingsStore
    @Binding private var settingsNavigationPath: NavigationPath

    @StateObject private var viewModel: MeViewModel
    @State private var draftName = ""
    @State private var isEditing = false
    @FocusState private var isNameFieldFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Route: Hashable {
        case settings
    }

    init(environment: AppEnvironment, settingsNavigationPath: Binding<NavigationPath>) {
        self.environment = environment
        _settings = ObservedObject(wrappedValue: environment.settings)
        _settingsNavigationPath = settingsNavigationPath
        _viewModel = StateObject(wrappedValue: MeViewModel(memoryService: environment.memoryService))
    }

    private var displayName: String {
        let name = settings.userDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Friend" : name
    }

    var body: some View {
        NavigationStack(path: $settingsNavigationPath) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    greeting
                    lastSevenDaysCard
                    activityCard
                    completionRateCard
                    personalBestsCard
                    quoteCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        settingsNavigationPath.append(Route.settings)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Open settings")
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .settings:
                    SettingsView(
                        navigationPath: $settingsNavigationPath,
                        embedsInNavigationStack: false,
                        focusSettings: environment.focusSettings
                    )
                }
            }
            .onAppear {
                draftName = settings.userDisplayName
                viewModel.refreshQuote()
            }
            .onChange(of: settings.userDisplayName) { _, newValue in
                draftName = newValue
            }
            .onChange(of: isNameFieldFocused) { _, isFocused in
                if !isFocused {
                    saveName()
                    isEditing = false
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isNameFieldFocused = false
                    }
                }
            }
            .background(Color.Theme.secondaryBackground.ignoresSafeArea())
        }
    }
}

private extension MeView {
    @ViewBuilder
    var greeting: some View {
        if isEditing {
            ViewThatFits(in: .horizontal) {
                greetingEditorHorizontal
                greetingEditorVertical
            }
        } else {
            Button {
                draftName = settings.userDisplayName
                isEditing = true
                isNameFieldFocused = true
            } label: {
                Text("Hello, \(Text(displayName).underline())!")
                    .appLargeTitleStyle()
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .accessibilityLabel("Hello, \(displayName). Edit display name")
        }
    }

    var greetingEditorHorizontal: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("Hello, ")
                .appLargeTitleStyle()
            nameField
            Text("!")
                .appLargeTitleStyle()
        }
    }

    var greetingEditorVertical: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Hello,")
                .appLargeTitleStyle()
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                nameField
                Text("!")
                    .appLargeTitleStyle()
            }
        }
    }

    var nameField: some View {
        TextField("Name", text: $draftName)
            .disableAutocorrection(true)
            .appLargeTitleStyle()
            .underline()
            .focused($isNameFieldFocused)
            .submitLabel(.done)
            .onSubmit {
                isNameFieldFocused = false
            }
            .accessibilityLabel("Display name")
    }

    var activityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity")
                .font(.title3.weight(.semibold))

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(viewModel.activityDays) { day in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(activityColor(for: day.completionCount))
                        .frame(maxWidth: .infinity)
                        .frame(height: activityBarHeight(for: day.completionCount))
                }
            }
            .frame(height: 24, alignment: .bottom)
            .accessibilityHidden(true)

            HStack {
                Text("30 days ago")
                Spacer()
                Text("Today")
            }
            .font(.caption)
            .foregroundStyle(Color.Theme.textSecondary)
        }
        .padding(16)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Activity")
        .accessibilityValue(activityAccessibilityValue)
    }

    var lastSevenDaysCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Week")
                .font(.title3.weight(.semibold))

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 14) {
                    weeklyMetricRow(title: "Done", value: "\(viewModel.completionCountLast7Days)")
                    Divider()
                    weeklyMetricRow(title: "Active", value: "\(viewModel.activeDaysLast7Days)")
                    Divider()
                    weeklyMetricRow(title: "Streak", value: compactStreakText(viewModel.streakDays))
                }
            } else {
                HStack(spacing: 12) {
                    weeklyMetric(title: "Done", value: "\(viewModel.completionCountLast7Days)")
                    Divider()
                    weeklyMetric(title: "Active", value: "\(viewModel.activeDaysLast7Days)")
                    Divider()
                    weeklyMetric(title: "Streak", value: compactStreakText(viewModel.streakDays))
                }
                .frame(minHeight: 54)
            }
        }
        .padding(16)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Week")
        .accessibilityValue(lastSevenDaysAccessibilityValue)
    }

    var completionRateCard: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 16) {
                    completionRateCopy
                    completionRateRing
                }
            } else {
                HStack(spacing: 20) {
                    completionRateCopy
                    Spacer(minLength: 8)
                    completionRateRing
                }
            }
        }
        .padding(16)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Completion rate")
        .accessibilityValue(completionRateAccessibilityValue)
    }

    var completionRateCopy: some View {
        Text("Completion Rate")
            .font(.custom("Baskerville", size: 20, relativeTo: .title3))
            .fontWeight(.semibold)
    }

    var completionRateRing: some View {
        ZStack {
            Circle()
                .stroke(Color.Theme.border, lineWidth: 8)

            Circle()
                .trim(from: 0, to: viewModel.completionRate.value)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .spring, value: viewModel.completionRate.value)

            Text(completionRateText)
                .font(.custom("Baskerville", size: 17, relativeTo: .subheadline))
                .fontWeight(.bold)
        }
        .frame(width: 68, height: 68)
        .accessibilityHidden(true)
    }

    var personalBestsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            personalBestRow(
                icon: "flame.fill",
                title: "Streak",
                value: viewModel.totalCompletionCount > 0
                    ? compactStreakText(viewModel.longestStreakDays)
                    : "—"
            )
            Divider()
            personalBestRow(
                icon: "checkmark.circle.fill",
                title: "Completed",
                value: viewModel.totalCompletionCount > 0
                    ? "\(viewModel.totalCompletionCount)"
                    : "—"
            )
            Divider()
            personalBestRow(
                icon: "brain.head.profile",
                title: "Top Mind",
                value: viewModel.topMindName ?? "—"
            )
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bests")
        .accessibilityValue(personalBestsAccessibilityValue)
    }

    var quoteCard: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "quote.opening")
                .font(.title2)
                .foregroundStyle(Color.Theme.textSecondary)
                .accessibilityHidden(true)

            Text(viewModel.quoteOfTheDay.text)
                .font(.body)
                .italic()
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("- " + viewModel.quoteOfTheDay.author)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(Color.Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Quote of the day")
        .accessibilityValue("\(viewModel.quoteOfTheDay.text), by \(viewModel.quoteOfTheDay.author)")
    }

    func weeklyMetric(title: String, value: String) -> some View {
        VStack(alignment: .center, spacing: 5) {
            Text(value)
                .font(.custom("Baskerville", size: 28, relativeTo: .title2))
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.Theme.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    func weeklyMetricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.custom("Baskerville", size: 17, relativeTo: .headline))
                .fontWeight(.semibold)
        }
    }

    @ViewBuilder
    func personalBestRow(icon: String, title: String, value: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                personalBestLabel(icon: icon, title: title)
                Text(value)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                personalBestLabel(icon: icon, title: title)
                Spacer(minLength: 16)
                Text(value)
                    .font(.headline)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    func personalBestLabel(icon: String, title: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(title)
        }
        .foregroundStyle(Color.Theme.textSecondary)
    }

    func activityColor(for count: Int) -> Color {
        switch count {
        case 0:
            return Color.Theme.border.opacity(0.7)
        case 1:
            return Color.accentColor.opacity(0.35)
        case 2:
            return Color.accentColor.opacity(0.65)
        default:
            return Color.accentColor
        }
    }

    func activityBarHeight(for count: Int) -> CGFloat {
        switch count {
        case 0: return 10
        case 1: return 15
        case 2: return 20
        default: return 24
        }
    }

    var activityAccessibilityValue: String {
        let completionCount = viewModel.completionCountLast30Days
        let activeDays = viewModel.activeDaysLast30Days
        let completionLabel = completionCount == 1 ? "completion" : "completions"
        let dayLabel = activeDays == 1 ? "day" : "days"
        return "\(completionCount) \(completionLabel) across \(activeDays) active \(dayLabel) in the last 30 days"
    }

    func streakText(_ days: Int) -> String {
        "\(days) \(days == 1 ? "day" : "days")"
    }

    func compactStreakText(_ days: Int) -> String {
        "\(days)d"
    }

    var lastSevenDaysAccessibilityValue: String {
        "\(viewModel.completionCountLast7Days) completed, \(viewModel.activeDaysLast7Days) active days, current streak \(streakText(viewModel.streakDays))"
    }

    var personalBestsAccessibilityValue: String {
        let longest = viewModel.totalCompletionCount > 0
            ? streakText(viewModel.longestStreakDays)
            : "not available"
        let total = viewModel.totalCompletionCount > 0
            ? "\(viewModel.totalCompletionCount)"
            : "not available"
        let topMind = viewModel.topMindName ?? "not available"
        return "Longest streak \(longest), total completions \(total), top Mind \(topMind)"
    }

    var completionRateText: String {
        "\(Int((viewModel.completionRate.value * 100).rounded()))%"
    }

    var completionRateAccessibilityValue: String {
        completionRateText
    }

    func saveName() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            draftName = settings.userDisplayName
            return
        }
        settings.userDisplayName = trimmed
        draftName = trimmed
    }
}

#Preview {
    let environment = AppEnvironment(dataController: DataController.preview)
    environment.bootstrap()
    return MeView(environment: environment, settingsNavigationPath: .constant(NavigationPath()))
        .environmentObject(environment)
}
