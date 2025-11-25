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
            attachmentsGallery
        }
    }

    private var attachmentsGallery: some View {
        LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
            if isEditable {
                addButtonBox
            }
            ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                attachmentThumbnail(for: attachment)
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onTapGesture {
                        onAttachmentTap(index, attachment)
                    }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: attachments.count)
    }

    private let gridSpacing: CGFloat = 6

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 3)
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
            squareCell { _ in
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.clear)
                        .liquidGlass(
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                            borderColor: Color.primary.opacity(0.1),
                            borderLineWidth: 1
                        )
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
        }
        .accessibilityLabel("Add photos")
        .disabled(!isAddMenuEnabled || isLoading)
        .opacity((isAddMenuEnabled && !isLoading) ? 1 : 0.6)
    }

    private var loadingOverlay: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(.primary)
        .allowsHitTesting(false)
    }

    private func attachmentThumbnail(for attachment: MemoryModel.Attachment) -> some View {
        squareCell { size in
            ZStack {
                Group {
                    if let image = UIImage(data: attachment.data) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: size, height: size)
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
                            .frame(width: size, height: size)
                            .overlay(
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            )
                    }
                }

                if isLoading {
                    loadingOverlay
                        .opacity(isLoading ? 1 : 0)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
    }

    private func squareCell<Content: View>(@ViewBuilder content: @escaping (_ side: CGFloat) -> Content) -> some View {
        GeometryReader { proxy in
            content(proxy.size.width)
                .frame(width: proxy.size.width, height: proxy.size.width)
        }
        .aspectRatio(1, contentMode: .fit)
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
