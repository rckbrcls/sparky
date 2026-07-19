import SwiftUI
import LinkPresentation
import QuickLookThumbnailing
import UniformTypeIdentifiers
import os
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

private let attachmentLogger = Logger(subsystem: "sparky", category: "AttachmentPreviews")

// MARK: - Link Preview

struct LinkPreviewCard: View {
    let url: URL
    @State private var previewImage: Image?
    @State private var title: String?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color("ElementBackground")

                if let previewImage {
                    previewImage
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
                    VStack(spacing: 4) {
                        Image(systemName: "safari.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)

                        Text(title ?? url.host ?? "Link")
                            .font(.caption2)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                    .padding(8)
                }

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

                if previewImage != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Text(title ?? url.host ?? "Link")
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                                .foregroundStyle(.white)
                            Spacer()
                        }
                    }
                    .padding(8)
                }
            }
        }
        .task { await fetchMetadata() }
    }

    private func fetchMetadata() async {
        let provider = LPMetadataProvider()
        do {
            let metadata = try await provider.startFetchingMetadata(for: url)
            title = metadata.title

            guard let imageProvider = metadata.imageProvider else { return }
            let loaded = try? await imageProvider.loadItem(forTypeIdentifier: UTType.image.identifier)

            if let data = loaded as? Data {
                previewImage = PlatformImageFactory.image(data: data)
                return
            }
            #if os(iOS)
            if let image = loaded as? UIImage {
                previewImage = Image(uiImage: image)
            }
            #elseif os(macOS)
            if let image = loaded as? NSImage {
                previewImage = Image(nsImage: image)
            }
            #endif
        } catch {
            attachmentLogger.error("Failed to fetch metadata for \(url.absoluteString): \(error.localizedDescription)")
        }
    }
}

// MARK: - File Preview

struct FilePreviewCard: View {
    let attachment: Memory.Attachment
    @State private var thumbnail: Image?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color("ElementBackground")

                if let thumbnail {
                    thumbnail
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        Text(attachment.filename ?? "File")
                            .font(.caption2)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                }

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
        .task { await generateThumbnail() }
    }

    private func generateThumbnail() async {
        if let image = PlatformImageFactory.image(data: attachment.data) {
            thumbnail = image
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(attachment.filename ?? "temp_file")
        do {
            try attachment.data.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let request = QLThumbnailGenerator.Request(
                fileAt: tempURL,
                size: CGSize(width: 300, height: 300),
                scale: 3.0,
                representationTypes: .thumbnail
            )
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            #if os(iOS)
            thumbnail = Image(uiImage: representation.uiImage)
            #elseif os(macOS)
            thumbnail = Image(nsImage: representation.nsImage)
            #endif
        } catch {
            attachmentLogger.error("Thumbnail generation failed: \(error.localizedDescription)")
        }
    }
}
