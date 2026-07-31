//
//  MindEmptyStateView.swift
//  sparky
//

import SwiftUI

struct MindEmptyStateView: View {
    let accessibilityLabel: String
    let onCreateMemory: () -> Void

    #if os(macOS)
    private let imageSize: CGFloat = 200
    #else
    private let imageSize: CGFloat = 180
    #endif

    var body: some View {
        VStack(spacing: 16) {
            Image(decorative: "mind-empty-character")
                .resizable()
                .scaledToFit()
                .frame(width: imageSize, height: imageSize)

            Text("Nothing here yet.")
                .font(.body)
                .foregroundStyle(Color.Theme.textSecondary)

            Button(action: onCreateMemory) {
                Label("Add Memory", systemImage: "plus")
                    #if os(iOS)
                    .frame(minHeight: 44)
                    #endif
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(accessibilityLabel)
        }
        .padding()
    }
}

#Preview {
    MindEmptyStateView(
        accessibilityLabel: "Add Memory",
        onCreateMemory: {}
    )
}
