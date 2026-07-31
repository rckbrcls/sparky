//
//  MemoryEditorTitleCard.swift
//  sparky
//
//  Created by Codex on 09/03/24.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct MemoryEditorTitleCard: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    let environment: AppEnvironment
    var isTitleFocused: FocusState<Bool>.Binding
    let isEditingEnabled: Bool

    @State private var showMindComposer = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                if isEditingEnabled {
                    Menu {
                        Picker("Mind", selection: $viewModel.selectedMindID) {
                            mindPickerLabel(
                                title: "No Mind",
                                systemImage: "brain.head.profile",
                                color: Color.Theme.textSecondary
                            )
                                .tag(nil as UUID?)

                            ForEach(viewModel.availableMinds) { mind in
                                mindPickerLabel(
                                    title: mind.name,
                                    systemImage: mind.iconName ?? "brain.head.profile",
                                    color: mindColor(for: mind)
                                )
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
                        selectedMindIcon(isInteractive: true)
                            .mindSelectorHitTarget()
                    }
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .accessibilityLabel("Mind")
                    .accessibilityValue(viewModel.selectedMind?.name ?? "No Mind")
                    .platformCover(isPresented: $showMindComposer) {
                        MindComposerView(
                            environment: environment,
                            presentationStyle: .platformPopover
                        )
                        .macPopoverFrame(width: 440, height: 560)
                    }
                } else {
                    selectedMindIcon(isInteractive: false)
                }

                if isEditingEnabled {
                    TextField("Memory", text: $viewModel.title, axis: .vertical)
                        .textFieldStyle(.plain)
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
                                PlatformOpen.resignFirstResponder()
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
            }

        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .cardStyle(cornerRadius: 24)
    }

    private var selectedMindColor: Color {
        mindColor(for: viewModel.selectedMind)
    }

    private func mindColor(for mind: Mind?) -> Color {
        if let hex = mind?.colorHex,
           let color = Color(hex: hex) {
            return color
        }
        return Color.Theme.textSecondary
    }

    private func mindPickerLabel(
        title: String,
        systemImage: String,
        color: Color
    ) -> some View {
        #if os(iOS)
        Label {
            Text(title)
        } icon: {
            if let image = UIImage(systemName: systemImage)?.withTintColor(
                UIColor(color),
                renderingMode: .alwaysOriginal
            ) {
                Image(uiImage: image)
            } else {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
            }
        }
        #else
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(color)
        }
        #endif
    }

    @ViewBuilder
    private func selectedMindIcon(isInteractive: Bool) -> some View {
        let icon = Image(systemName: viewModel.selectedMind?.iconName ?? "brain.head.profile")
            .foregroundStyle(selectedMindColor)
            .frame(width: 36, height: 36)

        if isInteractive {
            icon
                .glassEffect(
                    .regular.interactive().tint(selectedMindColor.opacity(0.15)),
                    in: .circle
                )
        } else {
            icon
                .glassEffect(
                    .regular.tint(selectedMindColor.opacity(0.15)),
                    in: .circle
                )
        }
    }
}

private extension View {
    @ViewBuilder
    func mindSelectorHitTarget() -> some View {
        #if os(iOS)
        frame(minWidth: 44, minHeight: 44)
            .contentShape(Circle())
        #else
        contentShape(Circle())
        #endif
    }
}
