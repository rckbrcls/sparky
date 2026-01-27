//
//  MemoryEditorTitleCard.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct MemoryEditorTitleCard: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @ObservedObject var lobeService: LobeService
    let environment: AppEnvironment
    var isTitleFocused: FocusState<Bool>.Binding
    let isEditingEnabled: Bool

    @State private var showSpaceComposer = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if isEditingEnabled {
                Menu {
                    Picker("Lobe", selection: $viewModel.selectedLobeID) {
                        Label("No Lobe", systemImage: "brain.fill")
                            .tag(nil as UUID?)

                        ForEach(lobeService.lobes) { lobe in
                            Label(lobe.name, systemImage: lobe.iconName ?? "brain.fill")
                                .tag(Optional(lobe.id))
                        }
                    }

                    Divider()

                    Button {
                        showSpaceComposer = true
                    } label: {
                        Label("Create New Lobe", systemImage: "plus.circle")
                    }
                } label: {
                    Image(systemName: viewModel.selectedLobe?.iconName ?? "brain.fill")
                        .foregroundStyle(selectedLobeColor)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular.tint(selectedLobeColor.opacity(0.15)))
                }
                .sheet(isPresented: $showSpaceComposer) {
                    LobeComposerView(environment: environment)
                }
            } else {
                Image(systemName: viewModel.selectedLobe?.iconName ?? "brain.fill")
                    .foregroundStyle(selectedLobeColor)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.tint(selectedLobeColor.opacity(0.15)))
            }

            if isEditingEnabled {
                TextField("Memory", text: $viewModel.title, axis: .vertical)
                    .font(.custom("PlayfairDisplay-Regular", size: 20))
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
                    .font(.custom("PlayfairDisplay-Regular", size: 20))
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .cardStyle(cornerRadius: 24)
    }

    private var selectedLobeColor: Color {
        if let hex = viewModel.selectedLobe?.colorHex,
           let color = Color(hex: hex) {
            return color
        }
        return .gray
    }
}
