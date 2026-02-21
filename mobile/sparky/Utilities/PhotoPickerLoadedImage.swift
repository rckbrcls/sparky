//
//  PhotoPickerLoadedImage.swift
//  sparky
//
//  Created by Codex on 13/11/25.
//

import Foundation
import PhotosUI
import SwiftUI

struct PhotoPickerLoadedImage: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            PhotoPickerLoadedImage(data: data)
        }
    }
}
