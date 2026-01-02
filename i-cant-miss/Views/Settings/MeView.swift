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

    @State private var isShowingSettings = false
    @State private var draftName: String = ""
    @State private var didSaveName = false
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
    }

    private var displayName: String {
        let name = settings.userDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Friend" : name
    }

    var body: some View {
        NavigationStack(path: $settingsNavigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Greeting title with editable name
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text("Hello, ")
                                .appLargeTitleStyle()

                            ZStack(alignment: .leading) {
                                // Always rendered TextField for focus to work
                                TextField("Name", text: $draftName)
                                    .textInputAutocapitalization(.words)
                                    .disableAutocorrection(true)
                                    .appLargeTitleStyle()
                                    .underline()
                                    .focused($isNameFieldFocused)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .opacity(isNameFieldFocused ? 1 : 0)
                                    .onSubmit {
                                        saveName()
                                    }

                                // Display text shown when not editing
                                if !isNameFieldFocused {
                                    Text(displayName)
                                        .appLargeTitleStyle()
                                        .underline()
                                        .onTapGesture {
                                            isNameFieldFocused = true
                                        }
                                }
                            }

                            Text("!")
                                .appLargeTitleStyle()
                        }
                    }

                    statsCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
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
            .onTapGesture {
                isNameFieldFocused = false
            }
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
    }



    private var meStats: [Stat] {
        let memories = memoryService.memories
        let completedMemories = memories.filter { $0.status == .completed }
        let spacesCount = spaceService.spaces.count
        let activeTriggers = memories.reduce(into: 0) { result, memory in
            result += memory.triggers.filter { $0.isActive }.count
        }

        return [
            Stat(title: "Memories", value: "\(memories.count)"),
            Stat(title: "Completed", value: "\(completedMemories.count)"),
            Stat(title: "Spaces", value: "\(spacesCount)"),
            Stat(title: "Triggers", value: "\(activeTriggers)"),
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
