import Combine
import SwiftUI
import LinkPresentation
import UIKit

struct LinkPreviewView: View {
    let url: URL
    @StateObject private var loader: LinkPreviewLoader

    init(url: URL) {
        self.url = url
        _loader = StateObject(wrappedValue: LinkPreviewLoader(url: url))
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))

            content
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .frame(minHeight: 110)
        .animation(.easeInOut(duration: 0.2), value: loader.isLoading)
    }

    @ViewBuilder
    private var content: some View {
        if let metadata = loader.metadata {
            LinkPreviewRepresentable(metadata: metadata)
                .accessibilityLabel(metadata.title ?? url.absoluteString)
        } else if loader.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Loading preview…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if loader.failed {
            fallbackView(icon: "link.badge.plus", message: loader.errorMessage)
        } else {
            fallbackView(icon: "link", message: urlDisplayText)
        }
    }

    private func fallbackView(icon: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var urlDisplayText: String {
        if let host = url.host, !host.isEmpty {
            return host
        }
        return url.absoluteString
    }
}

private struct LinkPreviewRepresentable: UIViewRepresentable {
    let metadata: LPLinkMetadata

    func makeUIView(context: Context) -> LPLinkView {
        LPLinkView(metadata: metadata)
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {
        uiView.metadata = metadata
    }
}

@MainActor
final class LinkPreviewLoader: ObservableObject {
    @Published private(set) var metadata: LPLinkMetadata?
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    let url: URL
    private let provider = LPMetadataProvider()

    var failed: Bool {
        error != nil
    }

    var errorMessage: String {
        if let error {
            return (error as NSError).localizedDescription
        }
        return "Unable to load preview."
    }

    init(url: URL) {
        self.url = url
        loadMetadataIfNeeded()
    }

    func loadMetadataIfNeeded() {
        guard metadata == nil, !isLoading else { return }
        isLoading = true
        provider.startFetchingMetadata(for: url) { [weak self] metadata, error in
            Task { @MainActor in
                guard let self else { return }
                self.metadata = metadata
                self.error = error
                self.isLoading = false
            }
        }
    }
}
