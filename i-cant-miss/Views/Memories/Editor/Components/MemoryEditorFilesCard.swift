import SwiftUI
import UIKit

struct MemoryEditorFilesCard: View {
    @Binding var files: [MemoryModel.Attachment]
    var isEditable: Bool = true
    var isImporting: Bool = false
    var onImport: () -> Void
    var onRemove: (UUID) -> Void
    var onPreview: (MemoryModel.Attachment) -> Void

    private let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()

    var body: some View {
        MemoryEditorContentCard {
            VStack(alignment: .leading, spacing: 12) {
                header
                if files.isEmpty && !isImporting {
                    placeholder
                } else {
                    fileList
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if isEditable {
                Button(action: onImport) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Add files")
                .disabled(isImporting)
                .opacity(isImporting ? 0.6 : 1)
                .padding(8)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Files")
                .font(.headline)
                .foregroundStyle(.primary)
            Text(isImporting ? "Importing files…" : "Attach documents you need.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: "doc")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.secondary)
            Text(isEditable ? "Import files from the Files app." : "No files attached to this memory.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var fileList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isImporting {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            LazyVStack(spacing: 10) {
                ForEach(files) { file in
                    fileRow(for: file)
                }
            }
        }
    }

    private func fileRow(for file: MemoryModel.Attachment) -> some View {
        HStack(spacing: 12) {
            filePreview(for: file)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.filename ?? "File")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Label(byteCountFormatter.string(fromByteCount: Int64(file.data.count)),
                      systemImage: "tray.and.arrow.down.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isEditable {
                Button {
                    onRemove(file.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete file")
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            onPreview(file)
        }
    }

    @ViewBuilder
    private func filePreview(for file: MemoryModel.Attachment) -> some View {
        if let image = UIImage(data: file.data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 54, height: 54)
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.accent)
            }
        }
    }
}
