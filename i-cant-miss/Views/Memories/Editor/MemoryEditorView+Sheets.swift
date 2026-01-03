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


}
