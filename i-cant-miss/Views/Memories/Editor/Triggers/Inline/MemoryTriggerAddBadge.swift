import SwiftUI

struct MemoryTriggerAddBadge: View {
    enum DisplayStyle {
        case inline
        case toolbar
    }

    @Binding var isPresented: Bool
    var displayStyle: DisplayStyle = .inline

    var body: some View {
        switch displayStyle {
        case .inline:
            inlineButton
        case .toolbar:
            toolbarButton
        }
    }

    private var inlineButton: some View {
        Button {
            isPresented = true
        } label: {
            Label("Add Trigger", systemImage: "bolt.fill")
                .font(.caption.bold())
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .accessibilityLabel("Add trigger")
    }

    private var toolbarButton: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "bolt.fill")
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 48, height: 48)
                .tint(.white)
                .glassEffect(.regular.tint(.accent).interactive())
        }
        .accessibilityLabel("Add trigger")
    }
}
