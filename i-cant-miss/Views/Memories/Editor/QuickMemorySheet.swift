//
//  QuickMemorySheet.swift
//  i-cant-miss
//
//  Created by Codex on 10/12/24.
//

import SwiftUI

struct QuickMemorySheet: View {
    @Environment(\.dismiss) private var dismiss

    let environment: AppEnvironment
    let space: SpaceModel?
    let onExpandToEditor: (SpaceModel?, String) -> Void

    @State private var title: String = ""
    @State private var selectedSpaceID: UUID?
    @FocusState private var isTitleFocused: Bool

    private var availableSpaces: [SpaceModel] {
        environment.spaceService.spaces
    }

    private var selectedSpace: SpaceModel? {
        guard let id = selectedSpaceID else { return nil }
        return availableSpaces.first { $0.id == id }
    }

    private var spaceColor: Color {
        if let hex = selectedSpace?.colorHex,
           let color = Color(hex: hex) {
            return color
        }
        return .gray
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                spaceIconMenu

                TextField("Memory", text: $title, axis: .vertical)
                    .font(.custom("Vollkorn-Regular", size: 20))
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                    .submitLabel(.done)
                    .focused($isTitleFocused)
                    .onSubmit {
                        isTitleFocused = false
                    }
                    .onChange(of: title) { _, newValue in
                        guard newValue.contains(where: { $0.isNewline }) else { return }
                        let sanitized = newValue
                            .split(whereSeparator: \.isNewline)
                            .joined(separator: " ")
                        if sanitized != newValue {
                            title = sanitized
                        }
                        isTitleFocused = false
                    }

                Button {
                    dismiss()
                    onExpandToEditor(selectedSpace, title)
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular)
                }
                .accessibilityLabel("More options")
            }
            .padding(20)

            Spacer()
        }
        .presentationDetents([.height(100)])
        .presentationBackground(.regularMaterial)
        .onAppear {
            selectedSpaceID = space?.id
            isTitleFocused = true
        }
    }

    private var spaceIconMenu: some View {
        Menu {
            Button {
                selectedSpaceID = nil
            } label: {
                if selectedSpaceID == nil {
                    Label("No Space", systemImage: "checkmark")
                } else {
                    Text("No Space")
                }
            }

            ForEach(availableSpaces) { space in
                Button {
                    selectedSpaceID = space.id
                } label: {
                    if selectedSpaceID == space.id {
                        Label(space.name, systemImage: "checkmark")
                    } else {
                        Text(space.name)
                    }
                }
            }
        } label: {
            Image(systemName: selectedSpace?.iconName ?? "square.grid.2x2")
                .foregroundStyle(spaceColor)
                .frame(width: 36, height: 36)
                .glassEffect(.regular.tint(spaceColor.opacity(0.15)))
        }
    }
}

#Preview {
    QuickMemorySheet(
        environment: {
            let env = AppEnvironment(persistence: PersistenceController.preview)
            env.bootstrap()
            return env
        }(),
        space: nil,
        onExpandToEditor: { _, _ in }
    )
}
