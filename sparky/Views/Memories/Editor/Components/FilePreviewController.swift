import Foundation
import QuickLook
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
final class FilePreviewItem: NSObject, QLPreviewItem {
    let url: URL

    init(url: URL) {
        self.url = url
        super.init()
    }

    var previewItemURL: URL? { url }
}

#else
final class FilePreviewItem: NSObject {
    let url: URL

    init(url: URL) {
        self.url = url
        super.init()
    }
}
#endif

#if os(iOS)
struct FilePreviewController: UIViewControllerRepresentable {
    let item: FilePreviewItem
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator

        let nav = UINavigationController(rootViewController: controller)
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: context.coordinator,
            action: #selector(Coordinator.doneTapped)
        )
        return nav
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(item: item, dismiss: dismiss)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let item: FilePreviewItem
        private let dismiss: DismissAction

        init(item: FilePreviewItem, dismiss: DismissAction) {
            self.item = item
            self.dismiss = dismiss
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            item
        }

        @objc func doneTapped() {
            dismiss()
        }
    }
}
#else
struct FilePreviewController: View {
    let item: FilePreviewItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text(item.url.lastPathComponent)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Button("Open with Default App") {
                    PlatformOpen.open(item.url)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Preview")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
#endif
