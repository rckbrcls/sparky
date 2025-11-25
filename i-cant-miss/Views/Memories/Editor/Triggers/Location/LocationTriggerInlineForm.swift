import SwiftUI

struct LocationTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showLocationPicker: Bool

    private var trigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .location })
    }

    var body: some View {
        if let trigger, let location = trigger.location {
            Button {
                showLocationPicker = true
            } label: {
                HStack {
                    Label(location.name ?? "Location", systemImage: "mappin.circle.fill")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
            .swipeActions {
                Button(role: .destructive) {
                    viewModel.removeTrigger(id: trigger.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            Button {
                showLocationPicker = true
            } label: {
                Label("Location", systemImage: "mappin.circle.fill")
                    .foregroundStyle(.accent)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
        }
    }
}
