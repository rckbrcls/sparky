
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
            .neutralButtonStyle()
        }
        .buttonStyle(.plain)

    }
}

#Preview {
    AddSynapseButton(action: {})
        .padding()
        .background(Color.black)
}
