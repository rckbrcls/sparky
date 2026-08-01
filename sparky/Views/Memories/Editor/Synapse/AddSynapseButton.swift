
import SwiftUI

struct AddSynapseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            PlatformHaptics.impactMedium()
            action()
        }) {
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

#Preview {
    AddSynapseButton(action: {})
        .padding()
        .background(Color.black)
}
