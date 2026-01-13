//
//  MeView.swift
//  i-cant-miss
//
//  Created by Codex on 07/12/25.
//

import SwiftUI

struct MeView: View {
    @ObservedObject private var environment: AppEnvironment
    @ObservedObject private var settings: SettingsStore
    @ObservedObject private var memoryService: MemoryService
    @ObservedObject private var spaceService: SpaceService
    @Binding private var settingsNavigationPath: NavigationPath

    @StateObject private var viewModel: MeViewModel
    @State private var draftName: String = ""
    @State private var didSaveName = false
    @State private var isEditing = false
    @FocusState private var isNameFieldFocused: Bool

    private enum Route: Hashable {
        case settings
    }

    private struct Stat: Identifiable {
        let id = UUID()
        let title: String
        let value: String
    }

    init(environment: AppEnvironment, settingsNavigationPath: Binding<NavigationPath>) {
        self.environment = environment
        _settings = ObservedObject(wrappedValue: environment.settings)
        _memoryService = ObservedObject(wrappedValue: environment.memoryService)
        _spaceService = ObservedObject(wrappedValue: environment.spaceService)
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
                VStack(alignment: .leading, spacing: 10) {
                    // Greeting title with editable name
                    VStack(alignment: .leading, spacing: 8) {
                        if isEditing {
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                Text("Hello, ")
                                    .appLargeTitleStyle()

                                ZStack {
                                    Text(draftName.isEmpty ? "Name" : draftName)
                                        .appLargeTitleStyle()
                                        .opacity(0)

                                    TextField("Name", text: $draftName)
                                        .textInputAutocapitalization(.words)
                                        .disableAutocorrection(true)
                                        .appLargeTitleStyle()
                                        .underline()
                                        .focused($isNameFieldFocused)
                                        .onSubmit {
                                            saveName()
                                            isEditing = false
                                        }
                                        .onAppear {
                                            isNameFieldFocused = true
                                        }
                                }

                                Text("!")
                                    .appLargeTitleStyle()
                            }
                        } else {
                            Text("Hello, \(Text(displayName).underline())!")
                                .appLargeTitleStyle()
                                .onTapGesture {
                                    isEditing = true
                                }
                        }

                        Text("Member since \(viewModel.memberSince)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    statsCard

                    heatmapSection

                    completionRateSection

                    quoteCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
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
                        environment: environment,
                        navigationPath: $settingsNavigationPath,
                        embedsInNavigationStack: false
                    )
                }
            }
            .onAppear {
                draftName = settings.userDisplayName
            }
            .onChange(of: settings.userDisplayName) { _, newValue in
                draftName = newValue
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isNameFieldFocused = false
                    }
                }
            }
            .onChange(of: isNameFieldFocused) { _, newValue in
                if !newValue {
                    isEditing = false
                }
            }
            .onTapGesture {
                isEditing = false
            }
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(meStats) { stat in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(stat.value)
                                .appLargeTitleStyle()
                        }

                        Text(stat.title.uppercased())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                }
            }
        }
    }

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)

            // Simple Heatmap Grid (Last 12 weeks equivalent approx 84 days, or just fill width)
            // Let's do past 30 days for simplicity and good mobile fit
            HStack(spacing: 4) {
                ForEach(0..<30) { dayOffset in
                    // 0 is today, 29 is 29 days ago.
                    // We want to render left to right: oldest to newest?
                    // Usually heatmaps are left-to-right.
                    // So left is -29 days, right is 0 days.
                    let date = Calendar.current.date(byAdding: .day, value: -(29 - dayOffset), to: Date())!
                    let normalized = Calendar.current.startOfDay(for: date)
                    let intensity = viewModel.heatmapData[normalized] ?? 0

                    RoundedRectangle(cornerRadius: 2)
                        .fill(intensity > 0 ? Color.accentColor : Color.gray.opacity(0.2))
                        .frame(height: 20) // Aspect ratio roughly square?
                        // Let screen width determine width
                }
            }
            // Add labels
            HStack {
                Text("30 Days ago")
                Spacer()
                Text("Today")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .cardStyle()
    }

    private var completionRateSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Completion Rate")
                    .font(.headline)
                Text("Based on total memories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color(.secondarySystemFill), lineWidth: 8)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: viewModel.completionRate)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring, value: viewModel.completionRate)

                Text("\(Int(viewModel.completionRate * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var quoteCard: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "quote.opening")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(viewModel.quoteOfTheDay.text)
                .font(.body)
                .italic()
                .multilineTextAlignment(.center)

            Text("- " + viewModel.quoteOfTheDay.author)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cardStyle()
    }

    private var meStats: [Stat] {
        let memories = memoryService.memories
        let completedMemories = memories.filter { $0.status == .completed }
        let spaceCount = spaceService.spaces.count

        return [
            Stat(title: "Streak", value: "\(viewModel.streakDays)"),
            Stat(title: "Completed", value: "\(completedMemories.count)"),
            Stat(title: "Memories", value: "\(memories.count)"),
            Stat(title: "Spaces", value: "\(spaceCount)"),
        ]
    }

    private func saveName() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settings.userDisplayName = trimmed
        didSaveName = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            didSaveName = false
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MeView(environment: environment, settingsNavigationPath: .constant(NavigationPath()))
        .environmentObject(environment)
}
