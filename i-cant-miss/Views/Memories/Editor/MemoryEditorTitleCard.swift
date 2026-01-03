//
//  MemoryEditorTitleCard.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct MemoryEditorTitleCard: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @ObservedObject var spaceService: SpaceService
    let environment: AppEnvironment
    var isTitleFocused: FocusState<Bool>.Binding

    @State private var showSpaceComposer = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Menu {
                Picker("Space", selection: $viewModel.selectedSpaceID) {
                    Label("No Space", systemImage: "square.grid.2x2")
                        .tag(nil as UUID?)

                    ForEach(spaceService.spaces) { space in
                        Label(space.name, systemImage: space.iconName ?? "square.grid.2x2")
                            .tag(Optional(space.id))
                    }
                }

                Divider()

                Button {
                    showSpaceComposer = true
                } label: {
                    Label("Create New Space", systemImage: "plus.circle")
                }
            } label: {
                Image(systemName: viewModel.selectedSpace?.iconName ?? "square.grid.2x2")
                    .foregroundStyle(selectedSpaceColor)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.tint(selectedSpaceColor.opacity(0.15)))
            }
            .sheet(isPresented: $showSpaceComposer) {
                SpaceComposerView(environment: environment)
            }

            TextField("Memory", text: $viewModel.title, axis: .vertical)
                .font(.custom("Vollkorn-Regular", size: 20))
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
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var selectedSpaceColor: Color {
        if let hex = viewModel.selectedSpace?.colorHex,
           let color = Color(hex: hex) {
            return color
        }
        return .gray
    }
}
