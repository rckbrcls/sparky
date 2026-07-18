
import SwiftUI

struct AddSynapseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            PlatformHaptics.impactMedium()
            action()
        }) {
            Image(systemName: "plus")
                .font(.caption.bold())
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
