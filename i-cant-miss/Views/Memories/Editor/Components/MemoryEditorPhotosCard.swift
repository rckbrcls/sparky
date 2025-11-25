import SwiftUI
import UIKit

struct MemoryEditorPhotosCard: View {
    @Binding var attachments: [MemoryModel.Attachment]
    var isLoading: Bool
    var isEditable: Bool = true
    var onRemoveAttachment: (UUID) -> Void
    var onAttachmentTap: (Int, MemoryModel.Attachment) -> Void = { _, _ in }
    var onAddFromLibrary: () -> Void = {}
    var onAddFromCamera: () -> Void = {}
    var isAddMenuEnabled: Bool = true

    var body: some View {
        MemoryEditorContentCard {
            VStack(alignment: .leading, spacing: 16) {
                attachmentsGallery
            }
        }
    }

    private var attachmentsGallery: some View {
        Group {
            if attachments.isEmpty && !isLoading {
                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(isEditable ? "Add photos to enrich this memory." : "No photos attached to this memory.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        if isEditable {
                            addButtonBox
                        }
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .frame(width: 120, height: 120)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                            attachmentThumbnail(for: attachment)
                                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .onTapGesture {
                                    onAttachmentTap(index, attachment)
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var addButtonBox: some View {
        Menu {
            Button(action: onAddFromLibrary) {
                Label("Library", systemImage: "photo.on.rectangle")
            }
            Button(action: onAddFromCamera) {
                Label("Camera", systemImage: "camera.fill")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .semibold))
                .frame(width: 120, height: 120)
                .glassEffect(in: .rect(cornerRadius: 18.0))
        }
        .accessibilityLabel("Add photos")
        .disabled(!isAddMenuEnabled || isLoading)
        .opacity((isAddMenuEnabled && !isLoading) ? 1 : 0.6)
    }

    private func attachmentThumbnail(for attachment: MemoryModel.Attachment) -> some View {
        Group {
            if let image = UIImage(data: attachment.data) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )

                    if isEditable {
                        Button {
                            onRemoveAttachment(attachment.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color.white, Color.black.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .accessibilityLabel("Remove photo")
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.secondary)
                    )
            }
        }
    }

}

#Preview {
    func createSampleImageData(color: UIColor = .systemBlue) -> Data {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData() ?? Data()
    }

    return VStack(spacing: 24) {
        // Estado vazio
        MemoryEditorPhotosCard(
            attachments: .constant([]),
            isLoading: false,
            isEditable: true,
            onRemoveAttachment: { _ in },
            onAttachmentTap: { _, _ in },
            onAddFromLibrary: {},
            onAddFromCamera: {}
        )
        .padding()

        // Estado com imagens
        MemoryEditorPhotosCard(
            attachments: .constant([
                MemoryModel.Attachment(
                    id: UUID(),
                    kind: .photo,
                    data: createSampleImageData(color: .systemBlue),
                    createdAt: Date()
                ),
                MemoryModel.Attachment(
                    id: UUID(),
                    kind: .photo,
                    data: createSampleImageData(color: .systemGreen),
                    createdAt: Date()
                ),
                MemoryModel.Attachment(
                    id: UUID(),
                    kind: .photo,
                    data: createSampleImageData(color: .systemOrange),
                    createdAt: Date()
                )
            ]),
            isLoading: false,
            isEditable: true,
            onRemoveAttachment: { _ in },
            onAttachmentTap: { _, _ in },
            onAddFromLibrary: {},
            onAddFromCamera: {}
        )
        .padding()

        // Estado carregando
        MemoryEditorPhotosCard(
            attachments: .constant([]),
            isLoading: true,
            isEditable: true,
            onRemoveAttachment: { _ in },
            onAttachmentTap: { _, _ in },
            onAddFromLibrary: {},
            onAddFromCamera: {}
        )
        .padding()

        // Estado não editável
        MemoryEditorPhotosCard(
            attachments: .constant([
                MemoryModel.Attachment(
                    id: UUID(),
                    kind: .photo,
                    data: createSampleImageData(color: .systemPurple),
                    createdAt: Date()
                )
            ]),
            isLoading: false,
            isEditable: false,
            onRemoveAttachment: { _ in },
            onAttachmentTap: { _, _ in }
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
