import SwiftUI

struct MemoryEditorAddContentMenu: View {
    struct Option: Identifiable {
        let id: MemoryEditorContentType
        let iconName: String
        let title: String
        let subtitle: String
        let isActive: Bool
    }

    let options: [Option]
    var onSelect: (MemoryEditorContentType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(options) { option in
                Button {
                    guard !option.isActive else { return }
                    onSelect(option.id)
                } label: {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: option.iconName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.accent)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(option.subtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if option.isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .accessibilityLabel("Already added")
                        } else {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                }
                .buttonStyle(.plain)
                .disabled(option.isActive)
                .opacity(option.isActive ? 0.6 : 1)
                .liquidGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }
}
