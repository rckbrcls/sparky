//
//  MemoryEditorTitleCard.swift
//  sparky
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct MemoryEditorTitleCard: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    let environment: AppEnvironment
    var isTitleFocused: FocusState<Bool>.Binding
    let isEditingEnabled: Bool

    @State private var showMindComposer = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if isEditingEnabled {
                Menu {
                    Picker("Mind", selection: $viewModel.selectedMindID) {
                        Label("No Mind", systemImage: "brain.head.profile")
                            .tag(nil as UUID?)

                        ForEach(viewModel.availableMinds) { mind in
                            Label(mind.name, systemImage: mind.iconName ?? "brain.head.profile")
                                .tag(Optional(mind.id))
                        }
                    }

                    Divider()

                    Button {
                        showMindComposer = true
                    } label: {
                        Label("Create New Mind", systemImage: "plus.circle")
                    }
                } label: {
                    Image(systemName: viewModel.selectedMind?.iconName ?? "brain.head.profile")
                        .foregroundStyle(selectedMindColor)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular.tint(selectedMindColor.opacity(0.15)))
                }
                .sheet(isPresented: $showMindComposer) {
                    MindComposerView(environment: environment)
                }
            } else {
                Image(systemName: viewModel.selectedMind?.iconName ?? "brain.head.profile")
                    .foregroundStyle(selectedMindColor)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.tint(selectedMindColor.opacity(0.15)))
            }

            if isEditingEnabled {
                TextField("Memory", text: $viewModel.title, axis: .vertical)
                    .font(.custom("Baskerville", size: 20))
                    .multilineTextAlignment(.leading)
                    .submitLabel(.done)
                    .focused(isTitleFocused)
                    .onSubmit {
                        isTitleFocused.wrappedValue = false
                    }
                    .onChange(of: viewModel.title) { _, newValue in
                        guard newValue.contains(where: { $0.isNewline }) else { return }
                        let sanitized = newValue
                            .split(whereSeparator: \.isNewline)
                            .joined(separator: " ")
                        if sanitized != newValue {
                            viewModel.title = sanitized
                        }
                        DispatchQueue.main.async {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            isTitleFocused.wrappedValue = false
                        }
                    }
            } else {
                Text(viewModel.title.isEmpty ? "Memory" : viewModel.title)
                    .font(.custom("Baskerville", size: 20))
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if isEditingEnabled || !viewModel.note.isEmpty {
                MemoryEditorNotesCard(
                    viewModel: viewModel,
                    isEditingEnabled: isEditingEnabled
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .cardStyle(cornerRadius: 24)
    }

    private var selectedMindColor: Color {
        if let hex = viewModel.selectedMind?.colorHex,
           let color = Color(hex: hex) {
            return color
        }
        return .gray
    }
}
