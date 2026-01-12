
import SwiftUI

struct AddSynapseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.caption.bold())
                Text("Add Synapse")
                    .font(.caption.bold())
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.4))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

    }
}

#Preview {
    AddSynapseButton(action: {})
        .padding()
        .background(Color.black)
}
