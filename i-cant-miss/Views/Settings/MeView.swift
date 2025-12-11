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
        let detail: String
        let systemImage: String
    }

    init(environment: AppEnvironment, settingsNavigationPath: Binding<NavigationPath>) {
        self.environment = environment
        _settings = ObservedObject(wrappedValue: environment.settings)
        _memoryService = ObservedObject(wrappedValue: environment.memoryService)
        _spaceService = ObservedObject(wrappedValue: environment.spaceService)
        _settingsNavigationPath = settingsNavigationPath
    }

    var body: some View {
        NavigationStack(path: $settingsNavigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Me")
                        .appLargeTitleStyle()
                    profileCard
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

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(.secondarySystemFill))
                        .frame(width: 64, height: 64)

                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 28, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your name")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Enter how you want to be called", text: $draftName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .font(.headline)
                        .focused($isNameFieldFocused)

                    if isNameFieldFocused && !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 8) {
                            Button("Save name") {
                                saveName()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            if didSaveName {
                                Label("Saved", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.footnote)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local stats")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(meStats) { stat in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(stat.title, systemImage: stat.systemImage)
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(stat.value)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Text(stat.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .liquidGlass(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }



    private var meStats: [Stat] {
        let memories = memoryService.memories
        let activeMemories = memories.filter { $0.status == .active }
        let completedMemories = memories.filter { $0.status == .completed }
        let spacesCount = spaceService.spaces.count
        let activeTriggers = memories.reduce(into: 0) { result, memory in
            result += memory.triggers.filter { $0.isActive }.count
        }

        return [
            Stat(title: "Memories", value: "\(memories.count)", detail: "Active: \(activeMemories.count)", systemImage: "square.and.pencil"),
            Stat(title: "Completed", value: "\(completedMemories.count)", detail: "Done", systemImage: "checkmark.circle"),
            Stat(title: "Spaces", value: "\(spacesCount)", detail: "Organization", systemImage: "square.grid.2x2"),
            Stat(title: "Triggers", value: "\(activeTriggers)", detail: "Active", systemImage: "bolt.circle"),
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
