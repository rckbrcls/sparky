import SwiftUI
import LinkPresentation
import QuickLookThumbnailing
import PDFKit
import UniformTypeIdentifiers

// MARK: - Link Preview

struct LinkPreviewCard: View {
    let url: URL
    @State private var metadata: LPLinkMetadata?
    @State private var previewImage: UIImage?
    @State private var title: String?
    @State private var isLoading = true

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Background
                Color(uiColor: .secondarySystemBackground)

                if let image = previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .overlay {
                            LinearGradient(
                                colors: [.black.opacity(0.4), .clear],
                                startPoint: .bottom,
                                endPoint: .center
                            )
                        }
                } else {
                    // Fallback for no image
                    VStack(spacing: 4) {
                        Image(systemName: "safari.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.blue)

                         if let title = title {
                            Text(title)
                                .font(.caption2)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                        } else {
                            Text(url.host ?? "Link")
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                }

                // Link Icon Overlay (Top Left) to indicate source
                VStack {
                    HStack {
                        Image(systemName: "link")
                            .font(.caption2)
                            .padding(4)
                            .background(.ultraThinMaterial, in: Circle())
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(6)

                // Title Overlay (Bottom) if we have an image
                if previewImage != nil {
                   VStack {
                        Spacer()
                        HStack {
                            Text(title ?? url.host ?? "Link")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .foregroundStyle(.white)
                            Spacer()
                        }
                    }
                    .padding(8)
                }
            }
        }
        .task {
            await fetchMetadata()
        }
    }

    private func fetchMetadata() async {
        let provider = LPMetadataProvider()
        do {
            let metadata = try await provider.startFetchingMetadata(for: url)
            await MainActor.run {
                self.metadata = metadata
                self.title = metadata.title
            }

            if let imageProvider = metadata.imageProvider {
                if let image = try? await imageProvider.loadItem(forTypeIdentifier: UTType.image.identifier) as? UIImage {
                    await MainActor.run {
                        self.previewImage = image
                    }
                } else if let data = try? await imageProvider.loadItem(forTypeIdentifier: UTType.image.identifier) as? Data,
                          let image = UIImage(data: data) {
                     await MainActor.run {
                        self.previewImage = image
                    }
                }
            }
            isLoading = false
        } catch {
            print("Failed to fetch metadata for \(url): \(error)")
            isLoading = false
        }
    }
}

// MARK: - File Preview

struct FilePreviewCard: View {
    let attachment: MemoryModel.Attachment
    @State private var thumbnail: UIImage?
    @State private var isLoading = true

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(uiColor: .secondarySystemBackground)

                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    // Fallback
                    VStack(spacing: 4) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.orange)
                        Text(attachment.filename ?? "File")
                            .font(.caption2)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                }

                // Extension badge
                if thumbnail != nil {
                     VStack {
                        Spacer()
                        HStack {
                            Text((attachment.filename as NSString?)?.pathExtension.uppercased() ?? "FILE")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                    .padding(6)
                }
            }
        }
        .task {
            await generateThumbnail()
        }
    }

    private func generateThumbnail() async {
        // If we have data, we might need to write it to a temp file to generate a thumbnail properly
        // or check if it's an image data directly.

        // 1. Check if it's an image we can just show
        if let image = UIImage(data: attachment.data) {
            await MainActor.run {
                self.thumbnail = image
                self.isLoading = false
            }
            return
        }

        // 2. Write to temp file to use QLThumbnailGenerator
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(attachment.filename ?? "temp_file")
        do {
            try attachment.data.write(to: tempURL)

            let request = QLThumbnailGenerator.Request(
                fileAt: tempURL,
                size: CGSize(width: 300, height: 300),
                scale: 3.0,
                representationTypes: .thumbnail
            )

            let generator = QLThumbnailGenerator.shared
            // Generate the thumbnail directly
            let thumbnail = try await generator.generateBestRepresentation(for: request)

            await MainActor.run {
                self.thumbnail = thumbnail.uiImage
                self.isLoading = false
            }

            // Cleanup
            try? FileManager.default.removeItem(at: tempURL)

        } catch {
            print("Thumbnail generation failed: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
