
import SwiftUI
import UIKit

struct AddSynapseButton: View {
    let action: () -> Void
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        Button(action: {
            feedbackGenerator.impactOccurred()
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
