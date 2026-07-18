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
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
            .textInputAutocapitalization(.words)
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
            Text("Last 7 Days")
                .font(.title3.weight(.semibold))

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 14) {
                    weeklyMetricRow(title: "Completed", value: "\(viewModel.completionCountLast7Days)")
                    Divider()
                    weeklyMetricRow(title: "Active Days", value: "\(viewModel.activeDaysLast7Days)")
                    Divider()
                    weeklyMetricRow(title: "Current Streak", value: streakText(viewModel.streakDays))
                }
            } else {
                HStack(spacing: 12) {
                    weeklyMetric(title: "Completed", value: "\(viewModel.completionCountLast7Days)")
                    Divider()
                    weeklyMetric(title: "Active Days", value: "\(viewModel.activeDaysLast7Days)")
                    Divider()
                    weeklyMetric(title: "Current Streak", value: streakText(viewModel.streakDays))
                }
                .frame(minHeight: 54)
            }
        }
        .padding(16)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Last 7 days")
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
        VStack(alignment: .leading, spacing: 5) {
            Text("Completion Rate")
                .font(.title3.weight(.semibold))
            Text(completionRateSubtitle)
                .font(.subheadline)
                .foregroundStyle(Color.Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var completionRateRing: some View {
        ZStack {
            Circle()
                .stroke(Color.Theme.border, lineWidth: 8)

            if let rate = viewModel.completionRate.value {
                Circle()
                    .trim(from: 0, to: rate)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .spring, value: rate)
            }

            Text(completionRateText)
                .font(.subheadline.weight(.bold))
        }
        .frame(width: 68, height: 68)
        .accessibilityHidden(true)
    }

    var personalBestsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Personal Bests")
                .font(.title3.weight(.semibold))

            personalBestRow(
                title: "Longest Streak",
                value: viewModel.totalCompletionCount > 0
                    ? streakText(viewModel.longestStreakDays)
                    : "—"
            )
            Divider()
            personalBestRow(
                title: "Total Completions",
                value: viewModel.totalCompletionCount > 0
                    ? "\(viewModel.totalCompletionCount)"
                    : "—"
            )
            Divider()
            personalBestRow(title: "Top Mind", value: viewModel.topMindName ?? "—")

            Divider()

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.Theme.textSecondary)
                    .accessibilityHidden(true)

                Text(viewModel.insight)
                    .font(.subheadline)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Personal bests")
        .accessibilityValue(personalBestsAccessibilityValue)
    }

    func weeklyMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.title2.weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.Theme.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func weeklyMetricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }

    func personalBestRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .foregroundStyle(Color.Theme.textSecondary)
            Spacer(minLength: 16)
            Text(value)
                .font(.headline)
                .multilineTextAlignment(.trailing)
        }
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
        return "Longest streak \(longest), total completions \(total), top Mind \(topMind). \(viewModel.insight)"
    }

    var completionRateText: String {
        guard let rate = viewModel.completionRate.value else { return "—" }
        return "\(Int((rate * 100).rounded()))%"
    }

    var completionRateSubtitle: String {
        let scheduled = viewModel.completionRate.scheduledOccurrences
        guard scheduled > 0 else {
            return "No scheduled memories in the last 7 days."
        }
        let occurrenceLabel = scheduled == 1 ? "occurrence" : "occurrences"
        return "Based on \(scheduled) scheduled \(occurrenceLabel) in the last 7 days."
    }

    var completionRateAccessibilityValue: String {
        guard viewModel.completionRate.scheduledOccurrences > 0 else {
            return "No scheduled memories in the last 7 days"
        }
        return "\(completionRateText), \(viewModel.completionRate.completedOccurrences) of \(viewModel.completionRate.scheduledOccurrences) scheduled occurrences completed in the last 7 days"
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
