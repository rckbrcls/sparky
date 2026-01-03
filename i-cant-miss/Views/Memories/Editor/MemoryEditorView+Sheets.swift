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
    func linkSheet() -> some View {
        MemoryEditorAddLinkSheet { url in
            handleLinkAdded(url)
        }
        .presentationDetents([.height(200)])
    }

}
