//
//  MemoryEditorView+PhotoViewer.swift
//  sparky
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

extension MemoryEditorView {

    @ViewBuilder
    var photoViewerContent: some View {
        let attachments = getPhotoAttachmentsForViewer()
        Group {
            if !attachments.isEmpty {
                let safeIndex = min(max(selectedAttachmentIndex, 0), attachments.count - 1)
                MemoryEditorPhotoCarouselView(
                    attachments: attachments,
                    initialIndex: safeIndex
                ) {
                    isPhotoViewerPresented = false
                    selectedPhotoContentID = nil
                    selectedAttachmentIndex = 0
                }
            } else {
                photoViewerErrorView
            }
        }
        .onAppear {
            let attachments = getPhotoAttachmentsForViewer()
            if attachments.isEmpty {
                isPhotoViewerPresented = false
                selectedPhotoContentID = nil
                selectedAttachmentIndex = 0
            } else {
                let safeIndex = min(max(selectedAttachmentIndex, 0), attachments.count - 1)
                if safeIndex != selectedAttachmentIndex {
                    selectedAttachmentIndex = safeIndex
                }
            }
        }
    }

    var photoViewerErrorView: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Unable to load photos")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                    Text("The photos are no longer available.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        isPhotoViewerPresented = false
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                }
            }
        }
    }

    // Simplified for fixed model - using viewModel.photoAttachments directly
    func getPhotoAttachmentsForViewer() -> [Memory.Attachment] {
        let rawAttachments = viewModel.photoAttachments
        guard !rawAttachments.isEmpty else { return [] }
        return flattenAttachments(rawAttachments)
    }

    private func flattenAttachments(_ attachments: [Memory.Attachment]) -> [Memory.Attachment] {
        attachments.filter { $0.kind == .photo && !$0.data.isEmpty }
    }
}
