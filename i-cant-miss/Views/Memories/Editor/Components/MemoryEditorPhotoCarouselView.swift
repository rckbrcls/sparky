import SwiftUI
import UIKit

struct MemoryEditorPhotoCarouselView: View {
    let attachments: [MemoryModel.Attachment]
    let onDismiss: () -> Void
    @State private var selectedIndex: Int
    @State private var scrollPosition: Int?

    init(
        attachments: [MemoryModel.Attachment],
        initialIndex: Int,
        onDismiss: @escaping () -> Void
    ) {
        self.attachments = attachments
        self.onDismiss = onDismiss
        let clampedIndex = min(max(initialIndex, 0), max(attachments.count - 1, 0))
        _selectedIndex = State(initialValue: clampedIndex)
        _scrollPosition = State(initialValue: attachments.isEmpty ? nil : clampedIndex)
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
                        .transition(.opacity)
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
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                        carouselItem(for: attachment)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .containerRelativeFrame(.horizontal)
                            .id(index)
                            .scrollTransition(.animated, axis: .horizontal) { content, phase in
                                content
                                    .opacity(phase.isIdentity ? 1.0 : 0.75)
                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.95)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollPosition)
            .scrollDisabled(attachments.count <= 1)
            .onAppear {
                scrollPosition = attachments.isEmpty ? nil : selectedIndex
            }
            .onChange(of: attachments) { _, newAttachments in
                let clampedIndex = min(max(selectedIndex, 0), max(newAttachments.count - 1, 0))
                selectedIndex = clampedIndex
                scrollPosition = newAttachments.isEmpty ? nil : clampedIndex
            }
            .onChange(of: selectedIndex) { _, newValue in
                guard attachments.indices.contains(newValue) else { return }
                if scrollPosition != newValue {
                    scrollPosition = newValue
                }
            }
            .onChange(of: scrollPosition) { _, newValue in
                guard let newValue, attachments.indices.contains(newValue) else { return }
                if selectedIndex != newValue {
                    selectedIndex = newValue
                }
            }
            .overlay(alignment: .bottom) {
                pageIndicator
                    .padding(.bottom, 32)
            }
        }
    }

    private func carouselItem(for attachment: MemoryModel.Attachment) -> some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            if let image = UIImage(data: attachment.data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                placeholderView
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(Array(attachments.enumerated()), id: \.offset) { index, _ in
                Circle()
                    .fill(index == selectedIndex ? Color.white : Color.white.opacity(0.35))
                    .frame(width: index == selectedIndex ? 10 : 8, height: index == selectedIndex ? 10 : 8)
                    .animation(.easeInOut(duration: 0.2), value: selectedIndex)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.clear)
                .liquidGlass(in: Capsule(), addSubtleBorder: false)
        )
        .opacity(attachments.count > 1 ? 1 : 0)
        .animation(.easeInOut(duration: 0.25), value: attachments.count)
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
