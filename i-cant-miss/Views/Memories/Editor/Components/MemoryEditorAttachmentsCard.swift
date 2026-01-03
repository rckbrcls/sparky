import SwiftUI
import PhotosUI

struct MemoryEditorAttachmentsCard: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    var isEditable: Bool = true

    // Callbacks for adding attachments
    var onAddPhoto: () -> Void
    var onAddCamera: () -> Void
    var onAddLink: () -> Void
    var onAddAudio: () -> Void
    var onAddFile: () -> Void

    // Callbacks for interactions
    var onAttachmentTap: (MemoryModel.Attachment) -> Void

    private var allAttachments: [MemoryModel.Attachment] {
        viewModel.photoAttachments + viewModel.linkAttachments + viewModel.audioAttachments + viewModel.fileAttachments
    }

    // Grid Setup
    private let gridSpacing: CGFloat = 8
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 3)
    }

    var body: some View {
        MemoryEditorContentCard {
            VStack(alignment: .leading, spacing: 12) {
                header

                LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                    if isEditable {
                        addAttachmentButton
                    }

                    ForEach(allAttachments) { attachment in
                        attachmentCell(for: attachment)
                            .onTapGesture {
                                onAttachmentTap(attachment)
                            }
                            .contextMenu {
                                if isEditable {
                                    Button(role: .destructive) {
                                        removeAttachment(attachment)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Attachments")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Photos, links, audio, and files.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var addAttachmentButton: some View {
        Menu {
            Button(action: onAddPhoto) {
                Label("Photo Library", systemImage: "photo")
            }
             Button(action: onAddCamera) {
                Label("Camera", systemImage: "camera")
            }
            Button(action: onAddLink) {
                Label("Link", systemImage: "link")
            }
            Button(action: onAddAudio) {
                Label("Audio", systemImage: "mic")
            }
            Button(action: onAddFile) {
                Label("File", systemImage: "doc")
            }
        } label: {
            squareCell { _ in
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.secondary.opacity(0.1), lineWidth: 1)
                        )

                    VStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                        Text("Add")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    @ViewBuilder
    private func attachmentCell(for attachment: MemoryModel.Attachment) -> some View {
        squareCell { size in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))

                // Content
                switch attachment.kind {
                case .photo:
                    if let image = UIImage(data: attachment.data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }

                case .link:
                    VStack(spacing: 4) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.blue)
                        Text("Link")
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }

                case .audio:
                    VStack(spacing: 4) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.purple)
                        Text("Audio")
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }

                case .file:
                    VStack(spacing: 4) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.orange)
                        Text(attachment.filename ?? "File")
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                default:
                     EmptyView()
                }

                // Border
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.1), lineWidth: 1)

                // Remove button overlay (top-right)
                if isEditable {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                removeAttachment(attachment)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(Color.white, Color.black.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                            .offset(x: 4, y: -4)
                        }
                        Spacer()
                    }
                    .padding(4)
                }
            }
        }
    }

    private func squareCell<Content: View>(@ViewBuilder content: @escaping (_ side: CGFloat) -> Content) -> some View {
        GeometryReader { proxy in
            content(proxy.size.width)
                .frame(width: proxy.size.width, height: proxy.size.width)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func removeAttachment(_ attachment: MemoryModel.Attachment) {
        switch attachment.kind {
        case .photo:
            viewModel.removePhotoAttachment(id: attachment.id)
        case .link:
            viewModel.removeLinkAttachment(id: attachment.id)
        case .audio:
            viewModel.removeAudioAttachment(id: attachment.id)
        case .file:
            viewModel.removeFileAttachment(id: attachment.id)
        default: break
        }
    }
}
