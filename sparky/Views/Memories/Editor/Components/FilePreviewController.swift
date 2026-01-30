import Foundation
import QuickLook
import SwiftUI

final class FilePreviewItem: NSObject, QLPreviewItem {
    let url: URL

    init(url: URL) {
        self.url = url
        super.init()
    }

    var previewItemURL: URL? { url }
}

struct FilePreviewController: UIViewControllerRepresentable {
    let item: FilePreviewItem

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(item: item)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let item: FilePreviewItem

        init(item: FilePreviewItem) {
            self.item = item
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            item
        }
    }
}
