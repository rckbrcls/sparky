//
//  MemoryEditorView+Sheets.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI
import PhotosUI

extension MemoryEditorView {

    @ViewBuilder
    func dateAndTimeSheet() -> some View {
        NavigationStack {
            ScheduledTriggerEditorScreen(viewModel: viewModel)
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    func locationSheet() -> some View {
        NavigationStack {
            LocationTriggerEditorScreen(viewModel: viewModel)
        }
    }

    @ViewBuilder
    func linkSheet() -> some View {
        MemoryEditorAddLinkSheet { url in
            handleLinkAdded(url)
        }
        .presentationDetents([.height(200)])
    }

    @ViewBuilder
    func personSheet() -> some View {
        NavigationStack {
            PersonTriggerEditorScreen(viewModel: viewModel)
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    func sequentialSheet() -> some View {
        NavigationStack {
            SequentialTriggerEditorScreen(
                viewModel: viewModel
            )
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    func photoOptionsSheet() -> some View {
        NavigationStack {
            HStack(spacing: 16) {
                Button {
                    showPhotoOptionsSheet = false
                    handleLibraryToolbarTap()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 24, weight: .semibold))
                        Text("Library")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 24.0))
                }
                .disabled(!isPhotoActionsEnabled)

                Button {
                    showPhotoOptionsSheet = false
                    handleCameraToolbarTap()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.system(size: 24, weight: .semibold))
                        Text("Camera")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 24.0))
                }
                .disabled(!isPhotoActionsEnabled)
            }
            .padding()
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showPhotoOptionsSheet = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}
