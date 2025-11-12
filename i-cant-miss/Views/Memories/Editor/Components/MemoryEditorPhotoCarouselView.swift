import SwiftUI
import UIKit

struct MemoryEditorPhotoCarouselView: View {
    let attachments: [MemoryModel.Attachment]
    let onDismiss: () -> Void
    @State private var selectedIndex: Int

    init(
        attachments: [MemoryModel.Attachment],
        initialIndex: Int,
        onDismiss: @escaping () -> Void
    ) {
        self.attachments = attachments
        self.onDismiss = onDismiss
        _selectedIndex = State(initialValue: min(max(initialIndex, 0), max(attachments.count - 1, 0)))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if attachments.isEmpty {
                    emptyStateView
                } else {
                    carouselView
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        onDismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text("No photos available.")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding()
    }

    private var carouselView: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                ZStack {
                    Color.black.opacity(0.95)
                        .ignoresSafeArea()
                    if let image = UIImage(data: attachment.data) {
                        GeometryReader { geometry in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(
                                    width: geometry.size.width,
                                    height: geometry.size.height
                                )
                                .clipped()
                                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        }
                    } else {
                        placeholderView
                    }
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
    }

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
            Text("Unable to load this photo.")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding()
    }
}
