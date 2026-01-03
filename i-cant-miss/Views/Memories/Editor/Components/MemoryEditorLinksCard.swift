import SwiftUI

struct MemoryEditorLinksCard: View {
    @Binding var links: [MemoryModel.Attachment]
    var isEditable: Bool = true
    var onAddLink: () -> Void
    var onRemoveLink: (UUID) -> Void

    var body: some View {
        MemoryEditorContentCard {
            VStack(alignment: .leading, spacing: 12) {
                header
                if links.isEmpty {
                    placeholder
                } else {
                    linksList
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Links")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Reference helpful resources.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isEditable {
                Button(action: onAddLink) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26, weight: .semibold)) // Matches AudioCard button size roughly
                        .foregroundStyle(Color.accentColor)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(Color.clear)
                                .liquidGlass(in: Circle(), addSubtleBorder: false)
                        )
                }
                .accessibilityLabel("Add link")
            }
        }
    }

    private var placeholder: some View {
        Button(action: { if isEditable { onAddLink() } }) {
            VStack(alignment: .center, spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(isEditable ? "Add links to reference helpful resources." : "No links attached to this memory.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEditable)
    }

    private var linksList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(links) { attachment in
                linkRow(for: attachment)
            }
        }
    }

    @ViewBuilder
    private func linkRow(for attachment: MemoryModel.Attachment) -> some View {
        if let url = attachment.url {
            ZStack(alignment: .topTrailing) {
                Link(destination: url) {
                    LinkPreviewView(url: url)
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)

                if isEditable {
                    Button {
                        onRemoveLink(attachment.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Color.white, Color.black.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .accessibilityLabel("Remove link")
                }
            }
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
                .frame(maxWidth: .infinity, minHeight: 90)
                .overlay(
                    VStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("This link is unavailable.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                )
        }
    }
}
